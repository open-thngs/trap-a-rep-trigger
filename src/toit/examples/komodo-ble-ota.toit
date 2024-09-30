import ble show *
import log
import system.firmware as firmware
import system.firmware show FirmwareMapping
import http
import net
import certificate-roots

logger ::= log.Logger log.DEBUG_LEVEL log.DefaultTarget --name="ble"

service/LocalService? := ?
peripheral/Peripheral? := ?

TOIT-BLE-FIRMWARE-SERVICE-UUID ::= BleUuid "7017"
COMMAND-CHARAC-UUID     ::= BleUuid "7018" 
FIRMWARE-CHARAC-UUID    ::= BleUuid "7019"
CRC32-CHARAC-UUID       ::= BleUuid "701A" 
FILELENGTH-CHARAC-UUID  ::= BleUuid "701B"

MTU ::= 512
PAKET-SIZE := MTU - 3

main:
  adapter := Adapter
  adapter.set-preferred-mtu MTU
  central := adapter.central

  address := find-with-service central TOIT-BLE-FIRMWARE-SERVICE-UUID 3
  remote_device := central.connect address
  services := remote_device.discover_services [TOIT-BLE-FIRMWARE-SERVICE-UUID]
  master_ble/RemoteService := services.first

  file-length-charac/RemoteCharacteristic? := null
  crc32-charac/RemoteCharacteristic? := null
  firmware-charac/RemoteCharacteristic? := null
  command-charac/RemoteCharacteristic? := null

  characteristics := master_ble.discover_characteristics []
  characteristics.do: | characteristic/RemoteCharacteristic |
    if characteristic.uuid == FILELENGTH-CHARAC-UUID:
      file-length-charac = characteristic
    else if characteristic.uuid == CRC32-CHARAC-UUID:
      crc32-charac = characteristic
    else if characteristic.uuid == FIRMWARE-CHARAC-UUID:
      firmware-charac = characteristic
    else if characteristic.uuid == COMMAND-CHARAC-UUID:
      command-charac = characteristic

  URL := "github.com"
  PATH := "/open-thngs/trap-a-rep-trigger/releases/latest/download/heimdall-esp32s3.bin"
  certificate-roots.install-all-trusted-roots

  network := net.open
  client := http.Client.tls network

  request := client.get URL PATH
  file-reader := request.body
  
  while chunk := (file-reader.read --max-size=512) != null:
    logger.debug "Read chunk of size $chunk.size"

  firmware.map:  | firmware-mapping/FirmwareMapping |
    firmware-length := firmware-mapping.size
    packet-count := firmware-length / PAKET-SIZE
    logger.debug "write Firmwarelength: $firmware-length bytes ($packet-count packets)"
    file-length-charac.write "$firmware-length".to-byte-array
    sleep --ms=100
    logger.debug "Write crc32"
    crc32-charac.write "1".to-byte-array
    sleep --ms=100
    logger.debug "Write command"
    command-charac.write #[0x04]
    logger.debug "Write firmware"

    chunk := ByteArray PAKET-SIZE
    done := false
    send-packets := 0
    send-bytes := 0
    packet/int := 0
    last := null
    List.chunk-up 0 firmware-mapping.size PAKET-SIZE: | chunk-from/int chunk-to/int chunk-size/int |
      while true: //retry on error
        exception := catch:
          bytes := ByteArray chunk-size
          firmware-mapping.copy --into=bytes chunk-from chunk-to
          firmware-charac.write bytes
          send-bytes += chunk-size
          percent := (send-bytes * 100) / firmware-length
          if percent != last:
            logger.info "sending firmware with $firmware-length bytes ($percent%)"
            last = percent

          break
        if exception:
          if exception.contains "error code: 0x06":
            //ignore and retry
          if exception.contains "error code: 0x07":
            logger.error "ENOCON: connection lost"
          sleep --ms=100
      
    sleep --ms=2000 // wait for the last packets to be written
    logger.debug "Firmware written"

find-with-service central/Central service/BleUuid duration/int=3:
  central.scan --duration=(Duration --s=duration): | device/RemoteScannedDevice |
    if device.data.service_classes.contains service:
      logger.debug "Found device with service $service: $device"
      return device.address
  throw "no device found"