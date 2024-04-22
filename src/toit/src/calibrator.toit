import .rgb-led show RGBLED
import gpio
import i2c
import .vl53l4cd
import system.storage
import .sensor-manager show SensorManager

CALIBRATION-TARGET-DISTANCE ::= 100
CALIBRATION-SMPLES ::= 30

led := ?
sensor-manager := ?

main:
  led = RGBLED
  led.green

  sensor-manager = SensorManager
  calibrate-xtalk sensor-manager led

calibrate-xtalk sensor-manager led:
  debugging := false
  last_temperature := 0

  bucket := storage.Bucket.open --flash "sensor-cfg"

  print "Calibration started..."
  led.yellow
  print "Initialising sensors"
  sensor-manager.disable-all
  sensor-manager.sensor-array.do: |sensor|
    sensor.enable
    sensor.apply-i2c-address
    sensor.clear-interrupt
  sensor-manager.sensor-array.do: |sensor|
      print "Calibrating sensor: $sensor.name"
      offset := sensor.calibrate_offset CALIBRATION-TARGET-DISTANCE CALIBRATION-SMPLES
      xtalk := sensor.calibrate_xtalk CALIBRATION-TARGET-DISTANCE CALIBRATION-SMPLES
      bucket[sensor.name+"-offset"] = offset
      bucket[sensor.name+"-xtalk"] = xtalk

  print "Calibration finished"
  sensor-manager.sensor-array.do: |sensor|
      print "Sensor: $sensor.name"
      print "Offset: $bucket[sensor.name+"-offset"]"
      print "Xtalk: $bucket[sensor.name+"-xtalk"]"
