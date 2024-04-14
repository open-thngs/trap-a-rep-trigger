import gpio 
import log
import esp32
import i2c
// import artemis

import .rgb-led show RGBLED
import .vl53l4cd
import .sensor-manager show SensorManager
import .sensor-manager show PIN-MASK

VL53_INT_1      ::= 21
VL53_INT_2      ::= 18
VL53_INT_3      ::= 6
VL53_INT_4      ::= 7

logger ::= log.Logger log.DEBUG_LEVEL log.DefaultTarget --name="trigger"

pin-mask := ((1 << VL53-INT-1) | (1 << VL53-INT-2) | (1 << VL53-INT-3) | (1 << VL53-INT-4) | (1 << 9))

main:
  logger.debug "Wakeup cause: $esp32.wakeup-cause"
  logger.debug "Wakeup status $(esp32.ext1-wakeup-status pin-mask)"
  logger.debug "extracted Pins: $(extract-pins (esp32.ext1-wakeup-status pin-mask))"
  //TODO do not run if the main app is running
  // trigger := artemis.Container.current.trigger
  // if trigger and trigger is artemis.TriggerPin:
  //   logger.debug "Trigger: $trigger on pin $((trigger as artemis.TriggerPin).pin)"
  //   if trigger.kind == artemis.Trigger.KIND_PIN:
  //     logger.debug "Pin: $((trigger as artemis.TriggerPin).pin)"

  // if esp32.wakeup-cause == 0:
  //   sleep --ms=5000
  //   return

  exception := catch --trace: 
    cam-trigger := CameraTrigger
    cam-trigger.run
    sensor-manager := SensorManager
    sensor-manager.init-all
    sensor-manager.clear-interrupts
    
  if exception:
    logger.debug "Error: Ignored trigger"
  
  deep-sleep

deep-sleep:
  esp32.enable-external-wakeup PIN-MASK false
  esp32.deep-sleep (Duration --m=1)

extract_pins mask/int -> List:
  pins := []
  21.repeat:
    if mask & (1 << it) != 0:
      pins.add it
  return pins

class CameraTrigger:

  run:
    exception := catch:
      shutter := gpio.Pin 11 --output=true
      focus := gpio.Pin 10 --output=true
      led := RGBLED 14 13 12

      led.green  
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
      led.off  
    if exception:
      logger.debug "Ignored trigger"
