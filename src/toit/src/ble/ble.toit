import ble show BleUuid LocalCharacteristic Adapter AdvertisementData 
import ble show BLE_CONNECT_MODE_UNDIRECTIONAL
import uuid show Uuid
import .command
import log
import .api_service_provider show ApiServiceProvider
import monitor

DEVICE_SERVICE_UUID ::= BleUuid "C532" //Custom UUID
COMMAND_CHARACTERISTIC_UUID ::= BleUuid "C540" //Custom UUID

command_characteristic/LocalCharacteristic := ?

command-channel := monitor.Channel 2
provider/ApiServiceProvider := ?
device-name := "RepTrap"

logger ::= log.Logger log.DEBUG_LEVEL log.DefaultTarget --name="ble"

main:
  logger.debug "BLE Service starting..."
  provider = ApiServiceProvider
  provider.install
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

  receiver-task := task:: command-receiver-task

  logger.debug "Advertising: $DEVICE_SERVICE_UUID with name $device_name"

  while true:
    command := command-channel.receive --blocking=true
    if command == Command.STOP:
      receiver-task.cancel
      break

command-receiver-task:
  while true:
    payload := #[]
    exception := catch --trace:
      payload = command-characteristic.read //blocking read
      handle-command payload.to-string

handle-command command:
  if command == Command.TRIGGER:
    logger.debug "Trigger command received"
    provider.trigger 
  else if command == Command.CALIBRATE:
    logger.debug "Calibrate command received"
    provider.calibrate 
  else if command == Command.STOP:
    logger.debug "Stop command received"
    

  else:
    logger.debug "Unknown command received: $command"
