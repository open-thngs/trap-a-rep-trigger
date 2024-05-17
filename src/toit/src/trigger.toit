import gpio 
import log
import esp32
import i2c
// import artemis

import .rgb-led show RGBLED
import .vl53l4cd
import .sensor-manager show SensorManager
import .sensor-manager show PIN-MASK
import .utils show deep-sleep
import .indicator.color show Color

logger ::= log.Logger log.DEBUG_LEVEL log.DefaultTarget --name="trigger"

main rgb-led/RGBLED:
  logger.debug "Trigger Camera.."

  exception := catch --trace: 
    rgb-led.set-color Color.pink
    cam-trigger := CameraTrigger
    cam-trigger.run
    sensor-manager := SensorManager
    sensor-manager.init-all
    sensor-manager.clear-interrupts
    rgb-led.set-color Color.off
  if exception:
    logger.debug "Error: Ignored trigger"
  
  deep-sleep

class CameraTrigger:
  
  run:
    exception := catch:
      shutter := gpio.Pin 11 --output=true
      focus := gpio.Pin 10 --output=true

      focus.set 1
      sleep --ms=10
      shutter.set 1
      logger.debug "time needed: $Time.monotonic-us"
      sleep --ms=500
      logger.debug "Camera has been triggered"
      shutter.set 0
      focus.set 0
      shutter.close
      focus.close
    if exception:
      logger.debug "Ignored trigger"
