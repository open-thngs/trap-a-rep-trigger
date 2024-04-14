import ble show BleUuid LocalCharacteristic Adapter AdvertisementData 
import ble show BLE_CONNECT_MODE_UNDIRECTIONAL
import uuid show Uuid
import log
import monitor
import esp32
import gpio

DEVICE_SERVICE_UUID ::= BleUuid "C532" //Custom UUID
COMMAND_CHARACTERISTIC_UUID ::= BleUuid "C540" //Custom UUID

command_characteristic/LocalCharacteristic := ?

command-channel := monitor.Channel 2
device-name := "RepTrap"

logger ::= log.Logger log.DEBUG_LEVEL log.DefaultTarget --name="ble"

main:
  logger.debug "BLE Service starting..."
  run_ble_service

run_ble_service:
  adapter := Adapter 
  // adapter.set_preferred_mtu 512
  peripheral := adapter.peripheral

  service := peripheral.add_service DEVICE_SERVICE_UUID
  command_characteristic = service.add_write_only_characteristic COMMAND_CHARACTERISTIC_UUID

  service.deploy

  peripheral.start_advertise --connection_mode=BLE_CONNECT_MODE_UNDIRECTIONAL
    AdvertisementData
      --name=device-name
      --check_size=false 
      --connectable=true
      --service_classes=[DEVICE_SERVICE_UUID]

  task:: command-receiver-task

  logger.debug "Advertising: $DEVICE_SERVICE_UUID with name $device_name"

command-receiver-task:
  while true:
    payload := #[]
    exception := catch --trace:
      payload = command-characteristic.read //blocking read
      logger.debug "Received payload: $payload.to-string"