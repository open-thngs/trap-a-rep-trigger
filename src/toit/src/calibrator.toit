import gpio
import i2c
import system.storage

import .sensor-manager show SensorManager
import .indicator.color show Color
import .indicator.indicator-service-client show IndicatorClient
import .vl53l4cd

CALIBRATION-TARGET-DISTANCE ::= 100
CALIBRATION-SMPLES ::= 50

led/IndicatorClient := ?
sensor-manager := ?

main:
  led = IndicatorClient
  led.set-color Color.green

  bucket := storage.Bucket.open --flash "sensor-cfg"

  sensor-manager = SensorManager bucket
  calibrate-xtalk sensor-manager led

calibrate-xtalk sensor-manager led/IndicatorClient:
  debugging := false
  last_temperature := 0
  exception := catch --trace --unwind=true:
    print "Calibration started..."
    led.set-color Color.yellow
    print "Initialising sensors"
    sensor-manager.disable-all
    sensor-manager.sensor-array.values.do: |sensor|
      sensor.enable
      sensor.apply-i2c-address
      sensor.clear-interrupt
    sensor-manager.sensor-array.values.do: |sensor|
        print "Calibrating sensor: $sensor.name"
        offset := sensor.calibrate_offset CALIBRATION-TARGET-DISTANCE CALIBRATION-SMPLES
        xtalk := sensor.calibrate_xtalk CALIBRATION-TARGET-DISTANCE CALIBRATION-SMPLES
        sensor-manager.bucket[sensor.name+"-offset"] = offset
        sensor-manager.bucket[sensor.name+"-xtalk"] = xtalk

    print "Calibration finished"
    sensor-manager.sensor-array.values.do: |sensor|
        print "Sensor: $sensor.name"
        print "Offset: $sensor-manager.bucket[sensor.name+"-offset"]"
        print "Xtalk: $sensor-manager.bucket[sensor.name+"-xtalk"]"
    
  if exception:
    print "Calibration failed: $exception"
    led.set-color Color.red
  else: 
    led.set-color Color.green
    print "Calibration successful"