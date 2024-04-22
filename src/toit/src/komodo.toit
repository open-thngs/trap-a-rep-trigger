import gpio
import esp32
import log
import reader
import uuid
import monitor

import encoding.tison

import system
import system.assets
import system.containers
import system.firmware

import .trigger as trigger
import .ble.bluetooth as bluetooth
import .app as app
import .rgb-led show RGBLED

USB-DETECT-PIN ::= 9

interface Endpoint:
  run device/Device -> none
  name -> string

logger ::= log.Logger log.INFO-LEVEL log.DefaultTarget --name="rep-trap"
flash-mutex ::= monitor.Mutex

firmware-is-validation-pending / bool := firmware.is-validation-pending
firmware-is-upgrade-pending / bool := false

reg-led := ?

main arguments:
  logger.info "Starting RepTrap..."
  device := Device.parse arguments
  if esp32.wakeup-cause == esp32.WAKEUP-EXT1:
    spawn:: trigger.main
  else:
    usb-detect-pin := gpio.Pin.in USB-DETECT-PIN
    if usb-detect-pin.get == 1:
      spawn:: bluetooth.main
    usb-detect-pin.close

    spawn:: app.main

class Device:
  id/uuid.Uuid
  name/string
  chip/string
  config/Map

  constructor --.id --.name --.chip --.config:

  static parse arguments -> Device:
    config := {:}
    if system.platform == system.PLATFORM-FREERTOS:
      assets.decode.get "config" --if-present=: | encoded |
        catch: config = tison.decode encoded

    id/uuid.Uuid? := null
    if arguments.size >= 2:
      id = uuid.parse arguments[1]
    else:
      id = config.get "id" --if-present=: uuid.parse it

    name/string? := null
    if arguments.size >= 3:
      name = arguments[2]
    else:
      name = config.get "name"

    chip/string? := config.get "chip"

    return Device
        --id=id or uuid.NIL
        --name=name or "unknown"
        --chip=chip or "unknown"
        --config=config
    
install-firmware firmware-size/int reader/reader.Reader -> none:
  with-timeout --ms=500_000: flash-mutex.do:
    logger.info "installing firmware with $firmware-size bytes"
    written-size := 0
    writer := firmware.FirmwareWriter 0 firmware-size
    try:
      last := null
      while data := reader.read:
        written-size += data.size
        writer.write data
        percent := (written-size * 100) / firmware-size
        if percent != last:
          logger.info "installing firmware with $firmware-size bytes ($percent%)"
          last = percent
      writer.commit
      logger.info "installed firmware; ready to update on chip reset"
    finally:
      writer.close

validation-mutex ::= monitor.Mutex
validate-firmware --reason/string -> none:
  validation-mutex.do:
    if firmware-is-validation-pending:
      if firmware.validate:
        logger.info "firmware update validated" --tags={"reason": reason}
        firmware-is-validation-pending = false
      else:
        logger.error "firmware update failed to validate"