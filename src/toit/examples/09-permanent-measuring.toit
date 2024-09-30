import gpio

import ..src.sensor-manager show SensorManager
import ..src.vl53l4cd show VL53L4CD MODE-DEFAULT MODE-LOW-POWER

VL53_INT_1    ::= 21
VL53_INT_2    ::= 18
VL53_INT_3    ::= 6
VL53_INT_4    ::= 7

VL53_XSHUNT_1 ::= 47
VL53_XSHUNT_2 ::= 17
VL53_XSHUNT_3 ::= 5
VL53_XSHUNT_4 ::= 8

irq-pin-1 := gpio.Pin.in VL53_INT_1
irq-pin-2 := gpio.Pin.in VL53_INT_2
irq-pin-3 := gpio.Pin.in VL53_INT_3
irq-pin-4 := gpio.Pin.in VL53_INT_4

sensor-manager := ?
is-initial-irq := true

main:
  sensor-manager = SensorManager
  sensor-manager.disable-all
  sensor-manager.sensor-array.values.do: |sensor|
    sensor.enable
    sensor.apply-i2c-address

  print "$sensor-manager.bus.scan"
  
  sensor-manager.sensor-array.values.do: |sensor|
    print "---------- $sensor.name ------------"
    sensor.start-temperature-update
    // apply_sensor_cfg sensor bucket
    threashold-mm := sensor.get-height-trigger-threshold 5 10
    // sensor.set-mode MODE-LOW-POWER
    // sensor.set-signal-threshold 5000
    // sensor.set-sigma-threshold 10
    // sensor.set-measure-timings 80 100 // + (random 6) //add a random to the frequency to avoid synchronisation of the sensors
    sensor.set-interrupt 200 true
    sensor.clear-interrupt
    sensor.start-ranging

  task:: watch-int-1
  task:: watch-int-2
  task:: watch-int-3
  task:: watch-int-4

  sleep --ms=100
  is-initial-irq = false

watch-int-1:
  check irq-pin-1 "VL53_1"

watch-int-2:
  check irq-pin-2 "VL53_2"

watch-int-3:
  check irq-pin-3 "VL53_3"

watch-int-4:
  check irq-pin-4 "VL53_4"

check pin/gpio.Pin sensor-name:
  while true:
    pin.wait-for 0
    sensor/VL53L4CD := sensor-manager.get-sensor sensor-name
    print "Pin $pin.num triggered"
    print "Sensor $sensor.name clear interrupt"
    sensor.clear-interrupt
    pin.wait-for 1
    print "Pin $pin.num cleared"