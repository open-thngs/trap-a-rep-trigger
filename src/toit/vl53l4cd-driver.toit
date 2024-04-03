import i2c
import .constants

class VL53L4CD-DRIVER:

  static I2C-ADDRESS ::= 41

  status_rtn := [ 255, 255, 255, 5, 2, 4, 1, 7, 3,
                0, 255, 255, 9, 13, 255, 255, 255, 255, 10, 6,
                255, 255, 11, 12 ]

  bus/i2c.Bus := ?
  debug := ?
  i2c-address_ := ?
  reg_ := ?
  device_ := ?

  constructor .bus .debug=false:
    i2c-address_ = I2C-ADDRESS
    device_ = bus.device I2C-ADDRESS
    reg_ = device_.registers

  get-system-status -> int:
    return (reg_.read FIRMWARE-SYSTEM-STATUS)[0]

  get-model-id -> ByteArray:
    value/ByteArray := read_ MODEL-ID
    return value

  get-module-type -> ByteArray:
    value/ByteArray := read_ MODULE-TYPE
    return value

  set-i2c-address i2c-address/int:
    write_ I2C-SLAVE-DEVICE-ADDRESS #[i2c-address]
    sleep --ms=10
    old := i2c-address_
    i2c-address_ = i2c-address
    device_ = bus.device i2c-address_
    reg_ = device_.registers
    print "I2C address changed from $old to $i2c-address" 

  read_ register/ByteArray length=1 -> ByteArray:
    return device_.read-address register length

  write_ register/ByteArray data/ByteArray:
    device_.write-address register data