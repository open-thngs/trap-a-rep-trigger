import gpio
import i2c

import ..src.sensor-manager show SensorManager
import ..src.vl53l4cd show VL53L4CD MODE-DEFAULT MODE-LOW-POWER
import ..src.constants


main:
  addr1 := 0x42
  addr2 := 0x43
  addr3 := 0x44
  addr4 := 0x45
  
  print "0x$(%02x addr1) 0x$(%02x addr2) 0x$(%02x addr3) 0x$(%02x addr4)"
  print "0x$(%02x addr1 << 1) 0x$(%02x addr2 << 1) 0x$(%02x addr3 << 1) 0x$(%02x addr4 << 1)"
  print "0x$(%02x (addr1 << 1) | 1) 0x$(%02x (addr2 << 1) | 1) 0x$(%02x (addr3 << 1) | 1) 0x$(%02x (addr4 << 1) | 1)"