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
import .sensor-manager show VL53_INT_1 VL53_INT_2 VL53_INT_3 VL53_INT_4
import .ble.bluetooth as ble-app
import .utils show deep-sleep
import .ble.bluetooth show State
import .indicator.color show Color
import .indicator.indicator-service-client show IndicatorClient

logger ::= log.Logger log.DEBUG_LEVEL log.DefaultTarget --name="app"
command-channel := monitor.Channel 1
sensor-manager/SensorManager := ?
api/ApiClient:=?
sensor-array := []
led/IndicatorClient := ?
is-ble-available := false
camera-trigger := CameraTrigger

main:
  logger.debug "Starting VL53L4CD Sensor Array"
  
  try: catch --trace --unwind=true:
    led = IndicatorClient
    led.open
    led.set-color Color.green

    is-ble-available = init-ble-api

    sensor-manager = SensorManager
    led.set-color Color.yellow
    sensor-manager.calibrate-and-start

    if is-ble-available: //handle interrupts manually when ble is active
      Task.group --required=1 [
        :: handle-interrupt-vl53-1,
        :: handle-interrupt-vl53-2,
        :: handle-interrupt-vl53-3,
        :: handle-interrupt-vl53-4
      ]

    set-status State.READY
    blink

    while is-ble-available:
      handle-command

  finally:
    sensor-manager.close

  deep-sleep

blink:
  5.repeat:
    led.set-color Color.green
    sleep --ms=150
    led.set-color Color.off
    sleep --ms=150

handle-command:
  command := command-channel.receive --blocking=true
  if command == Command.TRIGGER:
    camera-trigger.run
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
  led.set-color Color.yellow
  set-status State.CALIBRATING
  sensor-manager.calibrate-and-start
  set-status State.READY
  blink

set-status status:
  if is-ble-available:
    api.set-device-status status

handle-interrupt-vl53-1:
  handle-interrupt (sensor-manager.get-sensor "VL53_1") VL53_INT_1

handle-interrupt-vl53-2:
  handle-interrupt (sensor-manager.get-sensor "VL53_2") VL53_INT_2

handle-interrupt-vl53-3:
  handle-interrupt (sensor-manager.get-sensor "VL53_3") VL53_INT_3

handle-interrupt-vl53-4:
  handle-interrupt (sensor-manager.get-sensor "VL53_4") VL53_INT_4

handle-interrupt sensor irq-pin-nr:
  exc := catch:
    irq-pin := gpio.Pin.in irq-pin-nr
    while true:
      irq-pin.wait-for 0
      print "Interrupt $sensor.name"
      sensor.clear-interrupt
      command-channel.send Command.TRIGGER
      irq-pin.wait-for 1