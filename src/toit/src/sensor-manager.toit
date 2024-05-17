import i2c
import gpio
import system.storage

import .vl53l4cd

TIME-TO-MEASURE   ::= 50
MEASURE-FREQUENCY ::= 120

VL53_ADDR_1   ::= 20
VL53_XSHUNT_1 ::= 47
// VL53_XSHUNT_1 ::= 20 //breadboard xshunt
VL53_INT_1    ::= 21

VL53_ADDR_2   ::= 30
VL53_XSHUNT_2 ::= 17
VL53_INT_2    ::= 18

VL53_ADDR_3   ::= 40
VL53_XSHUNT_3 ::= 5
VL53_INT_3    ::= 6

VL53_ADDR_4   ::= 50
VL53_XSHUNT_4 ::= 8
VL53_INT_4    ::= 7

PIN-MASK ::= ((1 << VL53-INT-1) | (1 << VL53-INT-2) | (1 << VL53-INT-3) | (1 << VL53-INT-4)) //

class SensorManager:

  sensor-array/Map := {:}
  sda := ?
  scl := ?
  bus := ?
  bucket := ?

  constructor:  
    bucket = storage.Bucket.open --flash "sensor-cfg"

    sda = gpio.Pin 38
    scl = gpio.Pin 48
    bus = i2c.Bus
      --sda=sda
      --scl=scl
      --frequency=300_000
    
    debugging := false
    vl53-1 := VL53L4CD bus "VL53_1" VL53_XSHUNT_1 VL53-INT-1 VL53_ADDR_1 --debug=debugging
    vl53-2 := VL53L4CD bus "VL53_2" VL53_XSHUNT_2 VL53-INT-2 VL53_ADDR_2 --debug=debugging
    vl53-3 := VL53L4CD bus "VL53_3" VL53_XSHUNT_3 VL53-INT-3 VL53_ADDR_3 --debug=debugging
    vl53-4 := VL53L4CD bus "VL53_4" VL53_XSHUNT_4 VL53-INT-4 VL53_ADDR_4 --debug=debugging
    sensor-array[vl53-1.name] = vl53_1
    sensor-array[vl53-2.name] = vl53_2
    sensor-array[vl53-3.name] = vl53_3
    sensor-array[vl53-4.name] = vl53_4
    
    // print "I2C Bus Devices: $bus.scan"

    // vl53-1.xshut-pin_.configure --output=true
    // vl53-1.xshut-pin_.set 0
    // vl53-2.xshut-pin_.configure --output=true
    // vl53-2.xshut-pin_.set 0
    // vl53-3.xshut-pin_.configure --output=true
    // vl53-3.xshut-pin_.set 0
    // vl53-4.xshut-pin_.configure --output=true
    // vl53-4.xshut-pin_.set 0
  
  get-sensor name/string:
    return sensor-array[name]

  init-all:
    sensor-array.values.do: |sensor|
      sensor.init

  scan:
    devices := bus.scan
    print "Devices: $devices" 

  close:
    bus.close
    bus = null
    sda.close
    scl.close

  disable-all:
    sensor-array.values.do: | sensor |
      sensor.disable

  enable-all:
    sensor-array.values.do: | sensor |
      sensor.enable

  calibrate-and-start:
    disable-all
    sensor-array.values.do: |sensor/VL53L4CD|
      print "---------- $sensor.name ------------"
      sensor.enable
      sensor.apply-i2c-address
      sensor.set-mode MODE-DEFAULT
      sensor.start-temperature-update
      apply_sensor_cfg sensor bucket
      threashold-mm := sensor.get-height-trigger-threshold 25 10
      sensor.set-mode MODE-LOW-POWER
      sensor.set-signal-threshold 8000 
      sensor.set-sigma-threshold 20
      sensor.set-measure-timings (TIME-TO-MEASURE + (random 6)) (MEASURE-FREQUENCY + (random 6)) //add a random to the frequency to avoid synchronisation of the sensors
      
      sensor.set-interrupt threashold-mm true
      sensor.clear-interrupt
      sensor.start-ranging

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
    sensor-array.values.do: |sensor|
      print "Clearing interrupt for $sensor.name"
      sensor.clear-interrupt