import i2c
import .constants
import .struct
import .config

class VL53L4CD-DRIVER:

  static I2C-ADDRESS-DEFAULT ::= 41

  status_rtn := [ 255, 255, 255, 5, 2, 4, 1, 7, 3,
                0, 255, 255, 9, 13, 255, 255, 255, 255, 10, 6,
                255, 255, 11, 12 ]

  bus/i2c.Bus := ?
  debug := ?
  i2c-address_ := ?
  device_ := null

  constructor .bus .i2c-address_=I2C-ADDRESS-DEFAULT .debug=false:
    
  init:
    device_ = bus.device i2c-address_
    if not device_:
      throw "Failed to initialize VL53L4CD sensor"
  
  init-default:
    device_ = bus.device I2C-ADDRESS-DEFAULT

  disable:
    device_.close

  start-vhv:
    write_ SYSTEM_START #[0x40]

  get-system-status -> int:
    value := read_ FIRMWARE-SYSTEM-STATUS
    return value[0]

  get-model-id -> ByteArray:
    value/ByteArray := read_ MODEL-ID
    return value

  get-module-type -> ByteArray:
    value/ByteArray := read_ MODULE-TYPE
    return value

  set-i2c-address i2c-address/int:
    write_ I2C-SLAVE-DEVICE-ADDRESS #[i2c-address]
    sleep --ms=1
    old := i2c-address_
    i2c-address_ = i2c-address
    device_.close
    device_ = bus.device i2c-address_
    print "I2C address changed from $old to $i2c-address" 

  write-config config:
    write_ SENSOR-CONFIG config

  set-macrop-loop-bound value:
    write_ VHV-CONFIG-TIMEOUT-MACROP-LOOP-BOUND #[value]

  clear-interrupt:
    write_ SYSTEM-INTERRUPT-CLEAR #[0x01]

  start-ranging:
    inter-ms := get-inter-measurement
    if inter-ms != 0:
      print "Autonomous Mode"
      write_ SYSTEM-START #[0x40]
    else:
      print "Continuous Mode"
      write_ SYSTEM-START #[0x21]

  start-ranging-single-shot:
    write_ SYSTEM-START #[0x10]

  stop-ranging:
    write_ SYSTEM-START #[0x00]

  is-data-ready -> bool:
    interrupt-pol := get-interrupt-polarity
    tmp := (read_ GPIO-TIO-HV-STATUS)[0] & 0x01
    return tmp == interrupt-pol

  get-interrupt-polarity -> int:
    value := (read_ GPIO-HV-MUX-CTRL)[0] & 0x10
    return (~(value >> 4) & 0x01) & 0x01 //will be either 0 or 1

  set-interrupt-polarity polarity:
    value := (read_ GPIO-HV-MUX-CTRL)[0] & 0xEF
    value |= (polarity << 4)
    write_ GPIO-HV-MUX-CTRL #[value]

  get-timing-budget -> int:
    osc-freq := (unpack-16 (read_ #[0x00, 0x06] --length=2))
    macrop-period-us := 16 * ((2304 * (0x40000000 / osc-freq)).to-int >> 6)
    macrop-height := get-range-config-a

    ls-byte := (macrop-height & 0x00FF) << 4
    ms-byte := (macrop-height & 0xFF00) >> 8
    ms-byte = 0x04 - (ms-byte - 1) - 1

    timing-budget-ms := (((ls-byte + 1) * (macrop-period-us >> 6)) - ((macrop-period-us >> 6) >> 1)) >> 12
    if ms_byte < 12:
        timing_budget_ms >>= ms_byte
    if get-inter-measurement == 0:
        //mode continuous
        timing_budget_ms += 2500
    else:
        //mode autonomous
        timing_budget_ms *= 2
        timing_budget_ms += 4300

    return (timing_budget_ms / 1000).to-int

  set-timing-budget timing-budget-ms:
    if not 10 <= timing-budget-ms <= 200:
        throw "Timing budget range duration must be 10ms to 200ms."

    inter-measurment := get-inter-measurement
    if inter-measurment != 0 and timing-budget-ms > inter-measurment:
        throw "Timing budget can not be greater than inter-measurement period ($inter-measurment)"

    osc-freq := get-osc-frequency
    if osc_freq == 0:
      throw "Osc frequency is 0."

    timing-budget-us := timing-budget-ms * 1000
    macro-period-us := (2304 * (0x40000000 / osc-freq)).to-int >> 6

    if inter-measurment == 0:
        //continuous mode
        timing-budget-us -= 2500
    else:
        //autonomous mode
        timing-budget-us -= 4300
        timing-budget-us /= 2

    //VL53L4CD_RANGE_CONFIG_A register
    ms-byte := 0
    timing-budget-us <<= 12
    tmp := macro-period-us * 16
    ls-byte/int := (((timing-budget-us + ((tmp >> 6) >> 1)) / (tmp >> 6)) - 1).to-int
    while ls-byte & 0xFFFFFF00 > 0:
        ls-byte >>= 1
        ms-byte += 1
    ms-byte = (ms-byte << 8) + (ls-byte & 0xFF)
    write_ RANGE_CONFIG_A (pack-16 ms-byte)

    //VL53L4CD_RANGE_CONFIG_B register
    ms-byte = 0
    tmp = macro-period-us * 12
    ls-byte = (((timing-budget-us + ((tmp >> 6) >> 1)) / (tmp >> 6)) - 1).to-int
    while ls-byte & 0xFFFFFF00 > 0:
        ls-byte >>= 1
        ms-byte += 1
    ms-byte = (ms-byte << 8) + (ls-byte & 0xFF)
    write_ RANGE_CONFIG_B (pack-16 ms-byte)

  get-inter-measurement -> int:
    """
    Inter-measurement period in milliseconds. Valid range is timing_budget to
    5000ms, or 0 to disable.
    """
    inter-measurment-ms := get-inter-measurement-ms
    clock-pll := (get-clock-pll * CLOCK-PPL-FACTOR).to-int
    if clock-pll == 0: return 0
    return (inter-measurment-ms / clock_pll).to-int

  set-inter-measurement inter-measurement-ms:
    timing-bud := get-timing-budget
    if inter-measurement-ms != 0 and inter-measurement-ms < timing_bud:
      throw "Inter-measurement period can not be less than timing budget ($timing_bud)"

    clock-pll := get-clock-pll
    inter-measurment := INTER-MEASUREMENT-FACTOR * inter-measurement-ms * clock-pll
    write_ INTERMEASUREMENT-MS (pack-32 inter-measurment.to-int)

    //need to reset timing budget so that it will be based on new inter-measurement period
    //self.set_timing_budget(timing_bud)

  get-clock-pll:
    clock-pll-bytes := read_ RESULT_OSC_CALIBRATE_VAL --length=2
    clock-pll := (unpack-16 clock-pll-bytes) & 0x3FF
    return clock-pll

  get-inter-measurement-ms:
    return (unpack-32 (read_ INTERMEASUREMENT_MS --length=4))

  get-osc-frequency -> int:
    return (unpack-16 (read_ OSC-FREQUENCY --length=2))
  
  get-range-config-a:
    return unpack-16 (read_ RANGE_CONFIG_A --length=2)

  get-distance:
    distance := read_ RESULT_DISTANCE --length=2
    return unpack-16 distance

  set-interrupt-config threshold-mm trigger-only-below-threshold/bool:
    write_ SYSTEM-INTERRUPT (trigger-only-below-threshold ? #[0x00] : #[0x20])
    threshold-mm = pack-16 threshold-mm
    write_ THRESH-HIGH threshold-mm
    write_ THRESH-LOW threshold-mm

  set-offset range-offset-mm inner-offset-mm outer-offset-mm:
    write_ RANGE-OFFSET-MM (pack-16 range-offset-mm)
    write_ INNER-OFFSET-MM (pack-16 inner-offset-mm)
    write_ OUTER-OFFSET-MM (pack-16 outer-offset-mm)

  set-cross-talk xtalk-plane-offset-kcps:
    write_ XTALK-PLANE-OFFSET-KCPS (pack-16 (xtalk-plane-offset-kcps * 512))

  get-cross-talk -> int:
    value := unpack-16 (read_ XTALK-PLANE-OFFSET-KCPS --length=2)
    return (value / 512.0).to-int

  set-sigma-threshold sigma-threash-mm:
    if sigma-threash-mm > 16383:
      throw "Sigma threshold must be less than 16383"
    
    write_ RANGE-CONFIG-SIGMA-THRESH (pack-16 (sigma-threash-mm << 2))
  
  get-sigma-threshold -> int:
    value := unpack-16 (read_ RANGE-CONFIG-SIGMA-THRESH --length=2)
    return value >> 2

  get-signal-threshold -> int:
    value := unpack-16 (read_ MIN-COUNT-RATE-RTN-LIMIT-MCPS --length=2)
    return value << 3

  set-signal-threshold signal-kcps:
    if signal-kcps < 1 and signal-kcps > 16384:
      throw "Invalid Signal threshold"
    
    write_ MIN-COUNT-RATE-RTN-LIMIT-MCPS (pack-16 (signal-kcps >> 3))

  get-result-range-status -> int:
    value := (read_ RESULT-RANGE-STATUS)[0] & 0x1F
    if value < 24:
      return status_rtn[value]
    return value

  get-result-spad-nb -> int:
    return (unpack-16 (read_ RESULT_SPAD_NB --length=2)) / 256
  
  get-result-signal-rate:
      return (unpack-16 (read_ RESULT_SIGNAL_RATE --length=2)) * 8
  
  get-result-ambient-rate:
      return (unpack-16 (read_ RESULT_AMBIENT_RATE --length=2)) * 8
  
  get-result-sigma:
      return (unpack-16 (read_ RESULT_SIGMA --length=2)) / 4
  
  get-result-distance:
      return (unpack-16 (read_ RESULT_DISTANCE --length=2))

  read_ register/ByteArray --length=1 -> ByteArray:
    return device_.read-address register length

  write_ register/ByteArray data/ByteArray:
    device_.write-address register data

  dump:
    print "SensorConfig: $(read_ SENSOR_CONFIG --length=91)"