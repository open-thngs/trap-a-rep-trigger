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

VL53_INT_1      ::= 21
VL53_INT_2      ::= 18
VL53_INT_3      ::= 6
VL53_INT_4      ::= 7

logger ::= log.Logger log.DEBUG_LEVEL log.DefaultTarget --name="trigger"

main:
  logger.debug "Trigger Camera.."
  //TODO do not run if the main app is running

  exception := catch --trace: 
    cam-trigger := CameraTrigger
    cam-trigger.run
    sensor-manager := SensorManager
    sensor-manager.init-all
    sensor-manager.clear-interrupts
    
  if exception:
    logger.debug "Error: Ignored trigger"
  
  deep-sleep

class CameraTrigger:

  run:
    exception := catch:
      shutter := gpio.Pin 11 --output=true
      focus := gpio.Pin 10 --output=true

      focus.set 1
      sleep --ms=2
      shutter.set 1
      logger.debug "time needed: $Time.monotonic-us"
      sleep --ms=250
      logger.debug "Camera has been triggered"
      shutter.set 0
      focus.set 0
      shutter.close
      focus.close
    if exception:
      logger.debug "Ignored trigger"
