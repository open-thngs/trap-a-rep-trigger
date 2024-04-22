import gpio
import i2c
import system.storage
import esp32
import log
import monitor

import .vl53l4cd
import .rgb-led show RGBLED
import .trigger show CameraTrigger
import .ble.api_service_client show ApiClient
import .ble.bluetooth show Command
import .calibrator as calibrator
import .sensor-manager show SensorManager
import .ble.bluetooth as ble-app
import .utils show deep-sleep
import .ble.bluetooth show State

logger ::= log.Logger log.DEBUG_LEVEL log.DefaultTarget --name="app"
command-channel := monitor.Channel 1
sensor-manager/SensorManager := ?
api/ApiClient:=?
sensor-array := []
led := ?
is-ble-available := false

main:
  logger.debug "Starting VL53L4CD Sensor Array $esp32.reset-reason"
  
  try:
    led = RGBLED
    led.yellow

    is-ble-available = init-ble-api

    sensor-manager = SensorManager
    sensor-manager.calibrate-and-start
    set-status State.READY

    while is-ble-available:
      handle-command

  finally:
    led.close
    sensor-manager.close

  deep-sleep

blink:
  3.repeat:
    led.red
    sleep --ms=250
    led.off
    sleep --ms=250

handle-command:
  command := command-channel.receive --blocking=true
  if command == Command.TRIGGER:
    led.green
    (CameraTrigger).run
    led.off
  else if command == Command.CALIBRATE:
    calibrate
  else if command == Command.XTALK:
    calibrator.calibrate-xtalk sensor-manager led
  else if command == Command.STOP:
    is-ble-available = false
  else:
    print "Unknown Command"

init-ble-api -> bool:
  logger.debug "Initializing BLE API"
  api = ApiClient
  is-ble-service-available := api.open --timeout=(Duration --s=1) --if_absent=: null
  if not is-ble-service-available:
    logger.error "BLE API Service unavailable"
    return false
  else:
    on-trigger/Lambda := ::
      command-channel.send Command.TRIGGER

    on-calibrate/Lambda := ::
      command-channel.send Command.CALIBRATE

    on-calibrate-xtalk/Lambda := ::
      command-channel.send Command.XTALK

    on-stop/Lambda := ::
      command-channel.send Command.STOP

    api.set-on-trigger-callback on-trigger
    api.set-on-calibrate-callback on-calibrate
    api.set-on-calibrate-xtalk-callback on-calibrate-xtalk
    api.set-on-stop-callback on-stop
    return true

calibrate:
  led.yellow
  set-status State.CALIBRATING
  sensor-manager.disable-all
  sensor-manager.calibrate-and-start
  set-status State.READY
  blink

set-status status:
  if is-ble-available:
    api.set-device-status status