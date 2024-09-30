import gpio
import i2c

import ..src.sensor-manager show SensorManager
import ..src.vl53l4cd show VL53L4CD MODE-DEFAULT MODE-LOW-POWER
import ..src.constants

VL53_XSHUNT_2 ::= 17
VL53_IRQ_2 ::= 18

VL53_XSHUNT_1 ::= 47
VL53_XSHUNT_3 ::= 5
VL53_XSHUNT_4 ::= 8

main:
  sda := gpio.Pin 38
  scl := gpio.Pin 48
  bus := i2c.Bus
    --sda=sda
    --scl=scl
    --frequency=400_000

  xs-pin-1 := gpio.Pin.out VL53_XSHUNT_1
  xs-pin-2 := gpio.Pin.out VL53_XSHUNT_2
  xs-pin-3 := gpio.Pin.out VL53_XSHUNT_3
  xs-pin-4 := gpio.Pin.out VL53_XSHUNT_4
  xs-pin-1.set 0
  xs-pin-2.set 0
  xs-pin-3.set 0
  xs-pin-4.set 0
  sleep --ms=10
  xs-pin-2.set 1
  sleep --ms=10

  bus.scan.do: |address|
    print "Found device at address: 0x$(%2x address)"

  device := bus.device 41
  model-id := device.read-address MODEL-ID 1
  print "Model ID: $model-id"
  model-type := device.read-address MODULE-TYPE 1
  print "Model Type: $model-type"
  device.write-address I2C-SLAVE-DEVICE-ADDRESS #[0x20]
  sleep --ms=1
  device.close
  device = bus.device 0x20
  print "FirmwareStatus: $(device.read-address FIRMWARE-SYSTEM-STATUS 1)"
  with-timeout (Duration --ms=1000):
    while (device.read-address FIRMWARE-SYSTEM-STATUS 1)[0] == 0x03:
      sleep --ms=1

  model-id = device.read-address MODEL-ID 1
  print "Model ID: $model-id"
  model-type = device.read-address MODULE-TYPE 1
  print "Model Type: $model-type"
  