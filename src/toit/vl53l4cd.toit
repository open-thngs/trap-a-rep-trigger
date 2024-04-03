import gpio
import i2c
import .vl53l4cd-driver show VL53L4CD-DRIVER

class VL53L4CD:
  driver_/VL53L4CD-DRIVER? := null
  xshut_pin_ := null
  interrupt_pin_ := null
  i2caddr_ := null

  constructor bus name/string xshut_pin/int interrupt_pin/int i2caddr=41 --debug=false:
    driver_ = VL53L4CD-DRIVER bus
    xshut_pin_ = gpio.Pin.out xshut_pin
    xshut_pin_.set 0
    interrupt_pin_ = gpio.Pin.in interrupt_pin
    i2caddr_ = i2caddr

  begin:
    if i2caddr_ != VL53L4CD-DRIVER.I2C-ADDRESS:
      xshut_pin_.set 1
      sleep --ms=10
      driver_.set_i2c_address i2caddr_

  get-id -> ByteArray:
    return driver_.get-model-id

  get-module-type -> ByteArray:
    return driver_.get-module-type

  get-system-status -> int:
    return driver_.get-system-status

  