import log
import ble show BleUuid LocalCharacteristic Adapter AdvertisementData LocalService Peripheral
import ble show BLE_CONNECT_MODE_UNDIRECTIONAL
import monitor show Channel
import reader
import gpio
import system
import esp32
import system.storage show Bucket

import .api_service_provider show ApiServiceProvider
import ..indicator.color show Color
import ..indicator.indicator-service-client show IndicatorClient
import ..komodo

PREFERED-MTU ::= 512
DEVICE-SERVICE-UUID       ::= BleUuid "7017" //Custom Base UUID Toit
COMMAND-CHARAC-UUID       ::= BleUuid "7018" 
FIRMWARE-CHARAC-UUID      ::= BleUuid "7019"
CRC32-CHARAC-UUID         ::= BleUuid "701A" 
FILELENGTH-CHARAC-UUID    ::= BleUuid "701B"
STATE-CHARAC-UUID         ::= BleUuid "701C"
CFG-CHARAC-UUID           ::= BleUuid "701D"

CFG-SIGNAL-THRESHOLD     ::= 0xA0
CFG-SIGMA-THRESHOLD      ::= 0xA1
CFG-TIME-TO-MEASURE      ::= 0xA2
CFG-MEASURE-INTERVAL     ::= 0xA3

logger/log.Logger ::= log.Logger log.DEBUG_LEVEL log.DefaultTarget --name="ble"

peripheral/Peripheral? := null
command-charac/LocalCharacteristic? := null
firmware-charac/LocalCharacteristic? := null
crc32-charac/LocalCharacteristic? := null
file-length-charac/LocalCharacteristic? := null
state-charac/LocalCharacteristic? := null
cfg-charac/LocalCharacteristic? := null

state-channel/Channel := ?
command-channel/Channel := ?

crc32 := null
file-length/int := 0

provider/ApiServiceProvider := ?
bucket/Bucket := ?

main :
  state-channel = Channel 1
  command-channel = Channel 1

  bucket = Bucket.open --flash "sensor-cfg"

  provider = ApiServiceProvider
  on-device-status-change := :: | payload/ByteArray |
    logger.debug "Device status changed: $payload.to-string"
    state-charac.write payload
  provider.set-on-device-status-handler on-device-status-change

  try:
    provider.install
    name := "RepTrap"

    led := IndicatorClient
    led.open

    run-ble-service name
    logger.info "running Komodo BLE device '$name'"
    validate-firmware --reason="bluetooth service started"

    logger.info "Waiting for Bluetooth inputs"

    Task.group --required=1 [
      :: crc32-task,
      :: file-length-task,
      :: command-receiver-task,
      :: state-task,
      :: usb-c-watcher-task,
      :: cfg-task,
    ]

    led.set-color Color.blue
    running := true
    while running:
      command := command-channel.receive --blocking=true
      if command == Command.STOP:
        peripheral.stop-advertise
        logger.debug "Advertising stopped"
        provider.uninstall
        running = false
    
    logger.debug "BLE Service stopped"
  finally:
    peripheral.stop-advertise

run-ble-service device-name:
  adapter := Adapter 
  adapter.set_preferred_mtu PREFERED-MTU
  peripheral = adapter.peripheral
  service := peripheral.add_service DEVICE-SERVICE-UUID
  firmware-charac = service.add-write-only-characteristic FIRMWARE-CHARAC-UUID
  command-charac = service.add-write-only-characteristic COMMAND-CHARAC-UUID
  crc32-charac = service.add-write-only-characteristic CRC32-CHARAC-UUID
  file-length-charac = service.add-write-only-characteristic FILELENGTH-CHARAC-UUID
  state-charac = service.add-notification-characteristic STATE-CHARAC-UUID
  cfg-charac = service.add-write-only-characteristic CFG-CHARAC-UUID

  service.deploy
  peripheral.start-advertise --connection_mode=BLE_CONNECT_MODE_UNDIRECTIONAL
    AdvertisementData
      --name=device-name
      --check_size=false 
      --connectable=true
      --service_classes=[DEVICE_SERVICE_UUID]

  logger.info "Jaguar BLE running as $device-name"
  set-state "Ready"

state-task:
  while true:
    state := state-channel.receive
    logger.info "State: $state.to-string"
    state-charac.write state

command-receiver-task:
  while true:
    payload := command-charac.read
    logger.debug "Received command: $payload"
    // process-channel.send payload
    if payload == Command.TRIGGER:
      logger.debug "Trigger command received"
      provider.trigger 
    else if payload == Command.CALIBRATE:
      logger.debug "Calibrate command received"
      provider.calibrate 
    else if payload == Command.STOP:
      logger.debug "Stop command received"
      command-channel.send payload
      provider.stop
    else if payload == Command.XTALK:
      logger.debug "Xtalk command received"
      provider.calibrate-xtalk
    else if payload == Command.RESET:
      logger.debug "Reset command received"
      esp32.deep-sleep (Duration 0)
    else if payload == Command.FIRMWARE-UPDATE:
      logger.debug "Firmware update command received"
      if not crc32:
        set-state "CRC32 missing"
        continue
      else if file-length == 0:
        set-state "File length missing"
        continue
      set-state "Downloading"
      install-firmware file-length (BleReader firmware-charac file-length) 
      firmware-is-upgrade-pending = true
      set-state "Done"
    else:
      logger.debug "Unknown command received: $payload"

file-length-task:
  while true:
    payload := Payload Payload.TYPE-FILE-LENGTH file-length-charac.read
    file-length = int.parse payload.data.to-string
    logger.info "Received File Length: $file-length"

crc32-task:
  while true:
    payload := Payload Payload.TYPE-CRC32 crc32-charac.read
    crc32 = payload.data
    logger.info "Received CRC32"

set-state state/string:
  state-channel.send state.to-byte-array

usb-c-watcher-task:
  ble-pin := gpio.Pin.in 9
  ble-pin.wait-for 0
  command-channel.send Command.STOP
  provider.stop
  esp32.deep-sleep (Duration 0)

cfg-task:
  while true:
    payload := cfg-charac.read
    if not payload.size == 3:
      logger.debug "Invalid config received: $payload"
      continue

    type := payload[0]
    value := (payload[1] << 8) | payload[2]
    logger.debug "Received config: $payload"
    if type == CFG-SIGNAL-THRESHOLD:
      if value < 1 and value > 16384:
        logger.debug "Invalid Signal Threshold Config received: $value"
        continue
      logger.debug "Signal Threshold Config received: $value"
      bucket["signal-threshold"] = value
    else if type == CFG-SIGMA-THRESHOLD:
      if value > 16383:
        logger.debug "Invalid Sigma Threshold Config received: $value"
        continue
      logger.debug "Sigma Threshold Config received: $value"
      bucket["sigma-threshold"] = value
    else if type == CFG-TIME-TO-MEASURE:
      logger.debug "Time-To-Measure Config received: $value"
      bucket["time-to-measure"] = value
    else if type == CFG-MEASURE-INTERVAL:
      if value > 200:
        logger.debug "Invalid Measure interval Config received: $value"
        continue
      logger.debug "Measure interval Config received: $value"
      bucket["measure-interval"] = value
    else:
      logger.debug "Unknown config received: $payload"

name -> string:
  return "BLE"

class BleReader implements reader.Reader:

  firmware-charac/LocalCharacteristic := ?
  file-length/int := ?
  received-data-length := 0
  packet := null
  packet-count/int := 0

  constructor .firmware-charac/LocalCharacteristic .file-length/int:

  read:
    if received-data-length >= file-length:
      return null

    packet = firmware-charac.read //blocking wait for byte paket
    received-data-length += packet.size
    logger.debug "Received $received-data-length/$file-length ($packet-count : $packet.size)"
    packet-count++
    return packet.copy

class Payload:
  static TYPE-COMMAND ::= 0
  static TYPE-CRC32 ::= 1
  static TYPE-FILE-LENGTH ::= 2

  string-mapping := ["COMMAND", "CRC32", "FILELENGTH"]

  type/int
  data/ByteArray

  constructor .type/int .data/any:

  to-string:
    return "Type: $string-mapping[type], Data: $data"

class Command:
  static TRIGGER          ::= #[0x00]
  static CALIBRATE        ::= #[0x01]
  static STOP             ::= #[0x02]
  static XTALK            ::= #[0x03]
  static FIRMWARE-UPDATE  ::= #[0x04]
  static RESET            ::= #[0x05]

class State:
  static READY        ::= #[0x00]
  static CALIBRATING  ::= #[0x01]
