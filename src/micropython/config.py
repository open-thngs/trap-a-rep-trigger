VL53L4CD_ULTRA_LOW_POWER_CONFIG = (
    b"\x00"
    b"\x00"
    b"\x00"
    b"\x11"
    b"\x02"
    b"\x00"
    b"\x02"
    b"\x08"
    b"\x00"
    b"\x08"
    b"\x10"
    b"\x01"
    b"\x01"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\xff"
    b"\x00"
    b"\x0F"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\x20"
    b"\x0b"
    b"\x00"
    b"\x00"
    b"\x02"
    b"\x14"
    b"\x21"
    b"\x00"
    b"\x00"
    b"\x05"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\xc8"
    b"\x00"
    b"\x00"
    b"\x38"
    b"\xff"
    b"\x01"
    b"\x00"
    b"\x08"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\x01"
    b"\x07"
    b"\x00"
    b"\x02"
    b"\x05"
    b"\x00"
    b"\xb4"
    b"\x00"
    b"\xbb"
    b"\x08"
    b"\x38"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\x0f"
    b"\x89"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\x01"
    b"\x07"
    b"\x05"
    b"\x06"
    b"\x06"
    b"\x00"
    b"\x00"
    b"\x02"
    b"\xc7"
    b"\xff"
    b"\x9B"
    b"\x00"
    b"\x00"
    b"\x00"
    b"\x01"
    b"\x00"
    b"\x00"
)

VL53L4CD_ULTRA_LITE_DRIVER_CONFIG = (
            # value    addr : description
            b"\x12"  # 0x2d : set bit 2 and 5 to 1 for fast plus mode (1MHz I2C), else don't touch
            b"\x00"  # 0x2e : bit 0 if I2C pulled up at 1.8V, else set bit 0 to 1 (pull up at AVDD)
            b"\x00"  # 0x2f : bit 0 if GPIO pulled up at 1.8V, else set bit 0 to 1 (pull up at AVDD)
            b"\x11"  # 0x30 : set bit 4 to 0 for active high interrupt and 1 for active low (bits 3:0 must be 0x1)
            b"\x02"  # 0x31 : bit 1 = interrupt depending on the polarity
            b"\x00"  # 0x32 : not user-modifiable
            b"\x02"  # 0x33 : not user-modifiable
            b"\x08"  # 0x34 : not user-modifiable
            b"\x00"  # 0x35 : not user-modifiable
            b"\x08"  # 0x36 : not user-modifiable
            b"\x10"  # 0x37 : not user-modifiable
            b"\x01"  # 0x38 : not user-modifiable
            b"\x01"  # 0x39 : not user-modifiable
            b"\x00"  # 0x3a : not user-modifiable
            b"\x00"  # 0x3b : not user-modifiable
            b"\x00"  # 0x3c : not user-modifiable
            b"\x00"  # 0x3d : not user-modifiable
            b"\xFF"  # 0x3e : not user-modifiable
            b"\x00"  # 0x3f : not user-modifiable
            b"\x0F"  # 0x40 : not user-modifiable
            b"\x00"  # 0x41 : not user-modifiable
            b"\x00"  # 0x42 : not user-modifiable
            b"\x00"  # 0x43 : not user-modifiable
            b"\x00"  # 0x44 : not user-modifiable
            b"\x00"  # 0x45 : not user-modifiable
            b"\x20"  # 0x46 : interrupt configuration 0->level low detection, 1-> level high, 2-> Out of window, 3->In window, 0x20-> New sample ready , TBC
            b"\x0B"  # 0x47 : not user-modifiable
            b"\x00"  # 0x48 : not user-modifiable
            b"\x00"  # 0x49 : not user-modifiable
            b"\x02"  # 0x4a : not user-modifiable
            b"\x14"  # 0x4b : not user-modifiable
            b"\x21"  # 0x4c : not user-modifiable
            b"\x00"  # 0x4d : not user-modifiable
            b"\x00"  # 0x4e : not user-modifiable
            b"\x05"  # 0x4f : not user-modifiable
            b"\x00"  # 0x50 : not user-modifiable
            b"\x00"  # 0x51 : not user-modifiable
            b"\x00"  # 0x52 : not user-modifiable
            b"\x00"  # 0x53 : not user-modifiable
            b"\xC8"  # 0x54 : not user-modifiable
            b"\x00"  # 0x55 : not user-modifiable
            b"\x00"  # 0x56 : not user-modifiable
            b"\x38"  # 0x57 : not user-modifiable
            b"\xFF"  # 0x58 : not user-modifiable
            b"\x01"  # 0x59 : not user-modifiable
            b"\x00"  # 0x5a : not user-modifiable
            b"\x08"  # 0x5b : not user-modifiable
            b"\x00"  # 0x5c : not user-modifiable
            b"\x00"  # 0x5d : not user-modifiable
            b"\x01"  # 0x5e : not user-modifiable
            b"\xCC"  # 0x5f : not user-modifiable
            b"\x07"  # 0x60 : not user-modifiable
            b"\x01"  # 0x61 : not user-modifiable
            b"\xF1"  # 0x62 : not user-modifiable
            b"\x05"  # 0x63 : not user-modifiable
            b"\x00"  # 0x64 : Sigma threshold MSB (mm in 14.2 format for MSB+LSB), default value 90 mm
            b"\xA0"  # 0x65 : Sigma threshold LSB
            b"\x00"  # 0x66 : Min count Rate MSB (MCPS in 9.7 format for MSB+LSB)
            b"\x80"  # 0x67 : Min count Rate LSB
            b"\x08"  # 0x68 : not user-modifiable
            b"\x38"  # 0x69 : not user-modifiable
            b"\x00"  # 0x6a : not user-modifiable
            b"\x00"  # 0x6b : not user-modifiable
            b"\x00"  # 0x6c : Intermeasurement period MSB, 32 bits register
            b"\x00"  # 0x6d : Intermeasurement period
            b"\x0F"  # 0x6e : Intermeasurement period
            b"\x89"  # 0x6f : Intermeasurement period LSB
            b"\x00"  # 0x70 : not user-modifiable
            b"\x00"  # 0x71 : not user-modifiable
            b"\x00"  # 0x72 : distance threshold high MSB (in mm, MSB+LSB)
            b"\x00"  # 0x73 : distance threshold high LSB
            b"\x00"  # 0x74 : distance threshold low MSB ( in mm, MSB+LSB)
            b"\x00"  # 0x75 : distance threshold low LSB
            b"\x00"  # 0x76 : not user-modifiable
            b"\x01"  # 0x77 : not user-modifiable
            b"\x07"  # 0x78 : not user-modifiable
            b"\x05"  # 0x79 : not user-modifiable
            b"\x06"  # 0x7a : not user-modifiable
            b"\x06"  # 0x7b : not user-modifiable
            b"\x00"  # 0x7c : not user-modifiable
            b"\x00"  # 0x7d : not user-modifiable
            b"\x02"  # 0x7e : not user-modifiable
            b"\xC7"  # 0x7f : not user-modifiable
            b"\xFF"  # 0x80 : not user-modifiable
            b"\x9B"  # 0x81 : not user-modifiable
            b"\x00"  # 0x82 : not user-modifiable
            b"\x00"  # 0x83 : not user-modifiable
            b"\x00"  # 0x84 : not user-modifiable
            b"\x01"  # 0x85 : not user-modifiable
            b"\x00"  # 0x86 : clear interrupt, 0x01=clear
            b"\x00"  # 0x87 : ranging, 0x00=stop, 0x40=start
        )