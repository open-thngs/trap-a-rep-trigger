from machine import I2C, Pin
from micropython import const
import vl53l4cd
from rgbled import RGBLED
from sensorcfg import SensorCfg

VL53_ADDR_1 = const(42)
VL53_XSHUNT_1 = const(47)     
VL53_INT_1 = const(21)

VL53_ADDR_2 = const(43)
VL53_XSHUNT_2 = const(17)     
VL53_INT_2 = const(18)

VL53_ADDR_3 = const(44)
VL53_XSHUNT_3 = const(5)     
VL53_INT_3 = const(6)

VL53_ADDR_4 = const(45)
VL53_XSHUNT_4 = const(8)    
VL53_INT_4 = const(7)

led = RGBLED()
led.green()
debugging = False

i2c = I2C(1, sda=Pin(38), scl=Pin(48))
vl53_1 = vl53l4cd.VL53L4CD(i2c, "VL53_1", VL53_XSHUNT_1, VL53_INT_1, VL53_ADDR_1, debug=debugging)
vl53_2 = vl53l4cd.VL53L4CD(i2c, "VL53_2", VL53_XSHUNT_2, VL53_INT_2, VL53_ADDR_2, debug=debugging)
vl53_3 = vl53l4cd.VL53L4CD(i2c, "VL53_3", VL53_XSHUNT_3, VL53_INT_3, VL53_ADDR_3, debug=debugging)
vl53_4 = vl53l4cd.VL53L4CD(i2c, "VL53_4", VL53_XSHUNT_4, VL53_INT_4, VL53_ADDR_4, debug=debugging)

def calibrate():
  print("Calibration started...")
  led.yellow()
  print("Initialising sensors")
  sensor_array = [vl53_1, vl53_2, vl53_3, vl53_4]
  print(i2c.scan())
  for sensor in sensor_array:
      sensor.begin()

  print("Clear config file")
  sensorcfg = SensorCfg()
  sensorcfg.load()
  sensorcfg.clear()
  
  for sensor in sensor_array:
      print("Calibrating sensor: {}".format(sensor.name))
      offset = sensor.calibrate_offset(100, 30)
      xtalk = sensor.calibrate_xtalk(100, 30)
      sensorcfg.set_sensor(sensor.name, offset, xtalk)

  sensorcfg.save()
