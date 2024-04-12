import .rgb-led show RGBLED
import gpio
import i2c
import .vl53l4cd
import system.storage
import esp32
import .trigger show CameraTrigger
import .ble.api_service_client show ApiClient
import .ble.command
import log
import monitor
import .sensor-manager show SensorManager
import .sensor-manager show PIN-MASK

logger ::= log.Logger log.DEBUG_LEVEL log.DefaultTarget --name="app"
command-channel := monitor.Channel 1
sensor-manager := ?
api/ApiClient:=?
sensor-array := []
bucket := ?
led := ?
is-ble-available := false

main:
  logger.debug "Starting VL53L4CD Sensor Array $esp32.reset-reason"
  logger.debug "Wakeup cause: $esp32.wakeup-cause"
  logger.debug "extracted Pins: $(extract-pins (esp32.ext1-wakeup-status PIN-MASK))"
  if esp32.wakeup-cause == esp32.WAKEUP-EXT1:
    return

  led = RGBLED 14 13 12
  led.yellow

  is-ble-available = init-ble-api

  sensor-manager = SensorManager
  sensor-manager.calibrate-and-start
  
  while is-ble-available:
    handle-command
  
  led.close
  sensor-manager.close

  // while true:
    // logger.debug "I don't want to sleep yyet"
    // sleep --ms=10000
  // deep-sleep

blink:
  3.repeat:
    led.red
    sleep --ms=250
    led.off
    sleep --ms=250

extract_pins mask/int -> List:
  pins := []
  21.repeat:
    if mask & (1 << it) != 0:
      pins.add it
  return pins

handle-command:
  command := command-channel.receive --blocking=true
  if command == Command.TRIGGER:
    (CameraTrigger).run
  else if command == Command.CALIBRATE:
    calibrate
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

    api.set-on-trigger-callback on-trigger
    api.set-on-calibrate-callback on-calibrate
    return true

calibrate:
  led.yellow
  sensor-manager.disable-all
  sensor-manager.calibrate-and-start
  blink

deep-sleep:
  esp32.enable-external-wakeup PIN-MASK false
  esp32.deep-sleep (Duration --m=1)
