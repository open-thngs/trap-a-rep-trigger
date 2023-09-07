from machine import I2C, Pin
from micropython import const
import vl53l4cd

VL53_ADDR_1 = const(42)
VL53_XSHUNT_1 = const(0)     
VL53_INT_1 = const(1)

VL53_ADDR_2 = const(43)
VL53_XSHUNT_2 = const(2)     
VL53_INT_2 = const(3)

VL53_ADDR_3 = const(44)
VL53_XSHUNT_3 = const(4)     
VL53_INT_3 = const(5)

VL53_ADDR_4 = const(45)
VL53_XSHUNT_4 = const(25)    
VL53_INT_4 = const(24)

i2c = I2C(1, sda=Pin(10), scl=Pin(11))
vl53_1 = vl53l4cd.VL53L4CD(i2c, VL53_XSHUNT_1, VL53_INT_1, VL53_ADDR_1)
vl53_2 = vl53l4cd.VL53L4CD(i2c, VL53_XSHUNT_2, VL53_INT_2, VL53_ADDR_2)
vl53_3 = vl53l4cd.VL53L4CD(i2c, VL53_XSHUNT_3, VL53_INT_3, VL53_ADDR_3)
vl53_4 = vl53l4cd.VL53L4CD(i2c, VL53_XSHUNT_4, VL53_INT_4, VL53_ADDR_4)