import .rgb-led show RGBLED
import gpio
import i2c
import .vl53l4cd
import system.storage

// TEMPERATURE_CONVERSION_FACTOR ::= 3.3 / (65535)
// TEMPERATURE_OFFSET ::= 0.706

TIME-TO-MEASURE   ::= 40
MEASURE-FREQUENCY ::= 50

VL53_ADDR_1     ::= 42
VL53_XSHUNT_1   ::= 47
VL53_INT_1      ::= 21

VL53_ADDR_2     ::= 43
VL53_XSHUNT_2   ::= 17
VL53_INT_2      ::= 18

VL53_ADDR_3     ::= 44
VL53_XSHUNT_3   ::= 5
VL53_INT_3      ::= 6

VL53_ADDR_4     ::= 45
VL53_XSHUNT_4   ::= 8
VL53_INT_4      ::= 7

vl53-1 := ?
vl53-2 := ?
vl53-3 := ?
vl53-4 := ?

main:
  debugging := false
  last_temperature := 0
  led := RGBLED 14 13 12
  led.green

  shutter := gpio.Pin 11 --output=true
  focus := gpio.Pin 10 --output=true

  bucket := storage.Bucket.open --flash "sensor-cfg"

  bus := i2c.Bus
    --sda=gpio.Pin 38
    --scl=gpio.Pin 48

  vl53-1 = VL53L4CD bus "VL53_1" VL53_XSHUNT_1 VL53_INT_1 VL53_ADDR_1 --debug=debugging --low-power=true
  vl53-2 = VL53L4CD bus "VL53_2" VL53_XSHUNT_2 VL53_INT_2 VL53_ADDR_2 --debug=debugging --low-power=true
  vl53-3 = VL53L4CD bus "VL53_3" VL53_XSHUNT_3 VL53_INT_3 VL53_ADDR_3 --debug=debugging --low-power=true
  vl53-4 = VL53L4CD bus "VL53_4" VL53_XSHUNT_4 VL53_INT_4 VL53_ADDR_4 --debug=debugging --low-power=true

  print "Calibration started..."
  led.yellow
  print "Initialising sensors"
  sensor_array := [vl53_1, vl53_2, vl53_3, vl53_4]
  print bus.scan
  sensor_array.do: |sensor|
      sensor.init

  sensor_array.do: |sensor|
      print "Calibrating sensor: $sensor.name"
      offset := sensor.calibrate_offset 100 30
      xtalk := sensor.calibrate_xtalk 100 30
      bucket[sensor.name+"-offset"] = offset
      bucket[sensor.name+"-xtalk"] = xtalk

  print "Calibration finished"
  sensor-array.do: |sensor|
      print "Sensor: $sensor.name"
      print "Offset: $bucket[sensor.name+"-offset"]"
      print "Xtalk: $bucket[sensor.name+"-xtalk"]"
