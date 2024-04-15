import ble show BleUuid LocalCharacteristic Adapter AdvertisementData 
import ble show BLE_CONNECT_MODE_UNDIRECTIONAL
import uuid show Uuid
import .command
import log
import .api_service_provider show ApiServiceProvider
import monitor
import esp32
import gpio

DEVICE_SERVICE_UUID ::= BleUuid "C532" //Custom UUID
COMMAND_CHARACTERISTIC_UUID ::= BleUuid "C540" //Custom UUID
STATUS_CHARACTERISTIC_UUID ::= BleUuid "C541" //Custom UUID

command-characteristic/LocalCharacteristic := ?
device-status-charackteristic/LocalCharacteristic := ?

command-channel := monitor.Channel 2
provider/ApiServiceProvider := ?
device-name := "RepTrap"

logger ::= log.Logger log.DEBUG_LEVEL log.DefaultTarget --name="ble"

main run:
  logger.debug "BLE Service starting..."
  if run:
    provider = ApiServiceProvider
    provider.set-on-device-status-handler on-device-status-change
    provider.install
    run_ble_service

run_ble_service:
  adapter := Adapter 
  // adapter.set_preferred_mtu 512
  peripheral := adapter.peripheral

  service := peripheral.add_service DEVICE_SERVICE_UUID
  command-characteristic = service.add_write_only_characteristic COMMAND_CHARACTERISTIC_UUID
  device-status-charackteristic = service.add_notification_characteristic STATUS_CHARACTERISTIC_UUID

  service.deploy

  peripheral.start_advertise --connection_mode=BLE_CONNECT_MODE_UNDIRECTIONAL
    AdvertisementData
      --name=device-name
      --check_size=false 
      --connectable=true
      --service_classes=[DEVICE_SERVICE_UUID]

  receiver-task := task:: command-receiver-task
  task:: usb-c-watcher-task

  logger.debug "Advertising: $DEVICE_SERVICE_UUID with name $device_name"

  running := true
  while running:
    command := command-channel.receive --blocking=true
    if command == Command.STOP:
      receiver-task.cancel
      logger.debug "receiver-task stopped"
      peripheral.stop-advertise
      logger.debug "Advertising stopped"
      provider.uninstall
      running = false
  
  logger.debug "BLE Service stopped"

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
    command-channel.send command
    provider.stop
  else if command == Command.XTALK:
    logger.debug "Xtalk command received"
    provider.calibrate-xtalk
  else:
    logger.debug "Unknown command received: $command"

usb-c-watcher-task:
  ble-pin := gpio.Pin.in 9
  ble-pin.wait-for 0
  command-channel.send Command.STOP
  provider.stop

on-device-status-change := :: | payload/ByteArray |
  logger.debug "Device status changed: $payload.to-string"
  device-status-charackteristic.write payload
