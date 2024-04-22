import ..sensor-manager show SensorManager

VL53_ADDR_1 ::= 42
VL53_XSHUNT_1 ::= 47
VL53_INT_1 ::= 21

main:
  sensor-manager := SensorManager
  sensor-manager.disable-all
  sensor-manager.sensor-array.do: |sensor|
    ex := catch --trace:
      sensor.enable
      sensor.apply-i2c-address
    if ex:
      print "Error enabling sensor: $sensor.name"
      sensor.disable
  
  sensor-manager.scan
  
  // print "Sensor ID: $sensor.get-id Module Type: $sensor.get-module-type"
  // print "System status $sensor.get-system-status"
