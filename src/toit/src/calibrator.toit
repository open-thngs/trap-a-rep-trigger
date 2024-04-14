import .rgb-led show RGBLED
import gpio
import i2c
import .vl53l4cd
import system.storage
import .sensor-manager show SensorManager

main:
  debugging := false
  last_temperature := 0
  led := RGBLED
  led.green

  shutter := gpio.Pin 11 --output=true
  focus := gpio.Pin 10 --output=true

  bucket := storage.Bucket.open --flash "sensor-cfg"

  sensor-manager := SensorManager
  print "Calibration started..."
  led.yellow
  print "Initialising sensors"
  sensor-manager.init-all
  sensor-manager.sensor-array.do: |sensor|
      print "Calibrating sensor: $sensor.name"
      offset := sensor.calibrate_offset 100 30
      xtalk := sensor.calibrate_xtalk 100 30
      bucket[sensor.name+"-offset"] = offset
      bucket[sensor.name+"-xtalk"] = xtalk

  print "Calibration finished"
  sensor-manager.sensor-array.do: |sensor|
      print "Sensor: $sensor.name"
      print "Offset: $bucket[sensor.name+"-offset"]"
      print "Xtalk: $bucket[sensor.name+"-xtalk"]"
