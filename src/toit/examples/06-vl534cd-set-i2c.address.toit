import i2c
import gpio
import ..vl53l4cd show VL53L4CD

VL53_ADDR_1 ::= 42
VL53_XSHUNT_1 ::= 47
VL53_INT_1 ::= 21

main:
  bus := i2c.Bus
      --sda=gpio.Pin 38
      --scl=gpio.Pin 48

  xshut2/gpio.Pin := gpio.Pin.out 17
  xshut2.set 0
  xshut3 := gpio.Pin.out 5
  xshut3.set 0
  xshut4 := gpio.Pin.out 8
  xshut4.set 0

  sensor := VL53L4CD bus "VL531" VL53_XSHUNT_1 VL53_INT_1 VL53-ADDR-1
  sensor.xshut-pin_.set 1
  print "Scan before: $bus.scan"
  print "Sensor ID: $sensor.get-id Module Type: $sensor.get-module-type"
  sensor.begin
  print "Scan after: $bus.scan"
  print "Sensor ID: $sensor.get-id Module Type: $sensor.get-module-type"

