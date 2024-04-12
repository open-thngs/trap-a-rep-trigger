import i2c
import gpio
import system.storage

import .vl53l4cd

TIME-TO-MEASURE   ::= 40
MEASURE-FREQUENCY ::= 70

VL53_ADDR_1   ::= 42
VL53_XSHUNT_1 ::= 47
VL53_INT_1    ::= 21

VL53_ADDR_2   ::= 43
VL53_XSHUNT_2 ::= 17
VL53_INT_2    ::= 18

VL53_ADDR_3   ::= 44
VL53_XSHUNT_3 ::= 5
VL53_INT_3    ::= 6

VL53_ADDR_4   ::= 45
VL53_XSHUNT_4 ::= 8
VL53_INT_4    ::= 7

PIN-MASK ::= ((1 << VL53-INT-1) | (1 << VL53-INT-2) | (1 << VL53-INT-3) | (1 << VL53-INT-4))

class SensorManager:

  sensor-array := ?
  bus := ?
  bucket := ?

  constructor:  
    bucket = storage.Bucket.open --flash "sensor-cfg"

    bus = i2c.Bus
      --sda=gpio.Pin 38
      --scl=gpio.Pin 48
    
    debugging := false
    vl53-1 := VL53L4CD bus "VL53_1" VL53_XSHUNT_1 VL53_ADDR_1 --debug=debugging --low-power=true
    vl53-2 := VL53L4CD bus "VL53_2" VL53_XSHUNT_2 VL53_ADDR_2 --debug=debugging --low-power=true
    vl53-3 := VL53L4CD bus "VL53_3" VL53_XSHUNT_3 VL53_ADDR_3 --debug=debugging --low-power=true
    vl53-4 := VL53L4CD bus "VL53_4" VL53_XSHUNT_4 VL53_ADDR_4 --debug=debugging --low-power=true
    sensor-array = [vl53_1, vl53_2, vl53_3, vl53_4]
  
  init-all:
    sensor-array.do: |sensor|
      sensor.init

  close:
    bus.close

  disable-all:
    sensor-array.do: |sensor|
      sensor.disable

  enable-all:
    sensor-array.do: |sensor|
      sensor.enable

  calibrate-and-start:
    disable-all
    sensor-array.do: |sensor|
      sensor.enable
      sensor.apply-i2c-address
      sensor.clear-interrupt

    sensor-array.do: |sensor|
      print "---------- $sensor.name ------------"
      sensor.start-temperature-update
      apply_sensor_cfg sensor bucket
      threashold-mm := sensor.get-height-trigger-threshold 30 10
      sensor.set-mode MODE-LOW-POWER
      sensor.set-signal-threshold 5000
      print "Signal Threashold: $sensor.get-signal-threshold"
      sensor.set-sigma-threshold 10
      print "Sigma mm: $sensor.get_sigma_threshold"
      sensor.set-measure-timings TIME-TO-MEASURE MEASURE-FREQUENCY
      sensor.set-interrupt threashold-mm true
      sensor.start-ranging
      print "System Status: $sensor.get-system-status"
      print "result-range-status: $sensor.driver_.get-result-range-status"
      sensor.clear-interrupt

  apply-sensor-cfg sensor bucket:
    e1 := catch:
      offset := bucket[sensor.name+"-offset"]
      print "Setting offset for $sensor.name to $offset"
      sensor.set-offset offset
    if e1: print "Error setting offset for $sensor.name"

    e2 := catch:
      xtalk := bucket[sensor.name+"-xtalk"]
      if xtalk > 0:
        print "Setting xtalk for $sensor.name to $xtalk"
        sensor.set-xtalk xtalk
    if e2: print "Error setting xtalk for $sensor.name"

  clear-interrupts:
    sensor-array.do: |sensor|
      sensor.clear-interrupt