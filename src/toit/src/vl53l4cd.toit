import gpio
import i2c
import .vl53l4cd-driver show VL53L4CD-DRIVER
import .config
import ringbuffer

MODE-DEFAULT := "default"
MODE-LOW-POWER := "low-power"

THRESHOLD-MAX-VALUE ::= 1300.0

class VL53L4CD:
  bus_ := ?
  name := ?
  driver_/VL53L4CD-DRIVER? := ?
  xshut-pin_/gpio.Pin? := ?
  i2caddr := ?
  is-first-interrupt := true

  constructor .bus_ .name/string xshut_pin/int .i2caddr=41 --debug=false:
    driver_ = VL53L4CD-DRIVER bus_ i2caddr debug
    xshut-pin_ = gpio.Pin xshut_pin

  init:
    driver_.init

  close:
    driver_.device_.close

  enable:
    xshut-pin_.configure --output=true
    xshut-pin_.set 1
    sleep --ms=10

  disable:
    if driver_.device_:
      driver_.device_.close
    xshut-pin_.set 0
    sleep --ms=10

  reset:
    disable
    enable

  apply-i2c-address:
    driver_.init-default
    driver_.set-i2c-address i2caddr
    print "Sensor $name [0x$(%.2x i2caddr)]"

  get-id -> ByteArray:
    return driver_.get-model-id

  get-module-type -> ByteArray:
    return driver_.get-module-type

  get-system-status -> int:
    return driver_.get-system-status

  start-ranging:
    driver_.start-ranging

  stop-ranging:
    driver_.stop-ranging

  set-mode mode:
    wait-for-boot
    if mode == MODE-DEFAULT:
      configure-sensor-default-mode_
    else:
      configure-sensor-low-power-mode_

  configure-sensor-low-power-mode_:
    wait-for-boot
    driver_.write-config VL53L4CD-ULTRA-LOW-POWER-CONFIG
    start-vhv
    driver_.clear-interrupt
    driver_.stop-ranging
    driver_.set-macrop-loop-bound 0x09
    driver_.device_.registers.write-u8 0x0B 0x00
    driver_.write_ #[0x00, 0x24] #[0x05, 0x00]

    driver_.device_.registers.write-u8 0x81 0x8a
    driver_.write_ #[0x00,0x4B] #[0x03]

  configure-sensor-default-mode_:
    wait-for-boot
    driver_.write-config VL53L4CD_ULTRA_LITE_DRIVER_CONFIG
    start-vhv
    driver_.clear-interrupt
    driver_.stop-ranging
    driver_.set-macrop-loop-bound 0x09
    driver_.device_.registers.write-u8 0x0B 0x00
    driver_.write_ #[0x00, 0x24] #[0x05, 0x00]

    set-measure-timings 50 0

  set-inter-measurement-ms inter-measurement-ms:
    driver_.set-inter-measurement inter-measurement-ms
    
  set-measure-timings timing-budget inter-measurement:
    if inter-measurement != 0 and inter-measurement < timing-budget:
      throw "Inter-measurement period can not be less than timing budget ($timing-budget)"

    if inter-measurement != 0 and timing-budget > inter-measurement:
      throw "Timing budget can not be greater than inter-measurement period ($inter-measurement)"

    driver_.set_inter_measurement inter_measurement
    driver_.set_timing_budget timing_budget

  set-interrupt threashold-mm trigger-only-below-threshold:
    driver_.set-interrupt-config threashold-mm trigger-only-below-threshold
    sleep --ms=5

  wait-for-boot:
    with-timeout (Duration --ms=1000):
      while driver_.get-system-status != 0x03:
        sleep --ms=1

  clear-interrupt:
    driver_.clear-interrupt

  get-interrupt-polarity:
    return driver_.get-interrupt-polarity

  set-interrupt-polarity polarity:
    driver_.set-interrupt-polarity polarity

  get-signal-threshold -> int:
    return driver_.get-signal-threshold

  set-signal-threshold threshold:
    driver_.set-signal-threshold threshold

  get-sigma-threshold -> int:
    return driver_.get-sigma-threshold

  set-sigma-threshold threshold:
    driver_.set-sigma-threshold threshold

  get-distance -> int:
    return driver_.get-distance

  start-vhv:
    driver_.start-vhv
    with-timeout (Duration --ms=1000):
      while not driver_.is-data-ready:
        sleep --ms=1

  start-temperature-update:
    driver_.set-macrop-loop-bound 0x81
    driver_.write_ #[0x0B] #[0x92]
    driver_.set-inter-measurement 0
    driver_.start-ranging

    with-timeout (Duration --ms=1000):
      while not driver_.is-data-ready:
        sleep --ms=1

    driver_.clear-interrupt
    driver_.stop-ranging
    driver_.set-macrop-loop-bound 0x09
    driver_.write_ #[0x0B] #[0x00]

  device-heat-loop:
    driver_.start-ranging
    10.repeat:
      while not driver_.is-data-ready:
        sleep --ms=1
      
      result := get-result
      driver_.clear-interrupt
    driver_.stop-ranging

  get-height-trigger-threshold intensity=25 percentage=10.0 -> int:

    heights := ringbuffer.RingBuffer intensity
    device-heat-loop
    
    start-ranging
    distance := 0.0
    intensity.repeat:
      while not driver_.is-data-ready:
        sleep --ms=2
      
      result := get-result
      distance = result.distance-mm.to-float
      if distance == 0:
        result.dump
      print "Distance: $(%4d distance) mm [$result.get-status-string]" 
      heights.append distance
      clear-interrupt

    stop-ranging
    mean-distance := heights.average

    threshold := mean-distance - (percentage / 100.0) * mean-distance
    if threshold > THRESHOLD-MAX-VALUE or threshold <= 0:
      threshold = THRESHOLD-MAX-VALUE

    print "Average: $mean-distance.to-int"
    print "Threshold percentage: $percentage"
    print "Threshold: $threshold.to-int"

    return threshold.to-int

  calibrate-offset target-distance-mm nb-samples:
    print "Calibrating offset"
    if (nb-samples < 5 or nb-samples > 255) or (target-distance-mm < 10 or target-distance-mm > 1000):
      throw "Invalid offset calibration parameters"

    driver_.set-offset 0x00 0x00 0x00
    device-heat-loop
    start-ranging

    distances := ringbuffer.RingBuffer nb-samples
    distance := 0.0
    nb-samples.repeat:
      while not driver_.is-data-ready:
        sleep --ms=1
      
      result := get-result
      distances.append result.distance-mm.to-float
      driver_.clear-interrupt
    
    stop-ranging

    mean-distance := distances.average.to-int
    pre-offset := target-distance-mm - mean-distance
    tmp-offset := pre-offset * 4
    driver_.set-offset tmp-offset 0x00 0x00
    print "Calibrating offset done"
    return tmp-offset

  set-offset offset:
    driver_.set-offset offset 0x00 0x00

  calibrate-xtalk target-distance-mm nb-samples:
    print "Calibrating xtalk"
    if (nb-samples < 5 or nb-samples > 255) or (target-distance-mm < 10 or target-distance-mm > 5000):
      throw "Invalid offset calibration parameters"

    driver_.set_cross_talk 0 //disable xtalk
    device_heat_loop

    result/Result := Result
    average-distance := 0
    average-spad-nb := 0
    average-signal := 0
    counter-nb-samples := 0
    start_ranging
    nb-samples.repeat:
      while not driver_.is-data-ready:
        sleep --ms=1
        
      result = get-result
      // result.print-status
      driver_.clear-interrupt

      if(result.range_status == 0 and it > 0):
          //* Discard invalid measurements and first frame */
          average-distance += result.distance-mm
          average-spad-nb += result.number-of-spad
          average-signal += result.signal-rate-kcps
          counter-nb-samples++
        
    stop_ranging
    if(counter_nb_samples == 0):
      throw "No valid data samples"

    average-distance /= counter-nb-samples
    average-spad-nb /= counter-nb-samples
    average-signal /= counter-nb-samples

    xtalk-kcps := 1.0 - (average-distance / target-distance_mm)
    xtalk-kcps *= average-signal / average-spad-nb
    print "xtalk: $xtalk_kcps"

    //* 127kcps is the max Xtalk value (65536/512) */
    if(xtalk_kcps > 127.0):
      xtalk_kcps = 127.0
      print "ERROR: Xtalk compensation value is higher then 127 failed"
    
    driver_.set-cross-talk xtalk-kcps.to-int
    print "Calibrating xtalk done"
    return xtalk_kcps.to-int

  set-xtalk xtalk:
    driver_.set-cross-talk xtalk

  get-result -> Result:
    result/Result := Result
    result.range-status = driver_.get-result-range-status
    result.number-of-spad = driver_.get-result-spad-nb
    result.signal-rate-kcps = driver_.get-result-signal-rate
    result.ambient-rate-kcps = driver_.get-result-ambient-rate
    result.sigma-mm = driver_.get-result-sigma
    result.distance-mm = driver_.get-result-distance
    if result.number-of-spad != 0: result.signal-per-spad-kcps = result.signal-rate-kcps / result.number-of-spad
    else: print "Warning: SPAD count is 0"
    if result.number-of-spad != 0: result.ambient-per-spad-kcps = result.ambient-rate-kcps / result.number-of-spad
    else: print "Warning: SPAD count is 0"

    return result

class Result:
  range-status := 0
  number-of-spad := 0
  signal-rate-kcps := 0
  ambient-rate-kcps := 0
  sigma-mm := 0
  distance-mm := 0
  signal-per-spad-kcps := 0
  ambient-per-spad-kcps := 0

  dump:
    print "Result: SPAD=$number-of-spad,   Signal=$signal-rate-kcps,   Ambient=$ambient-rate-kcps,   Sigma=$sigma-mm,  Distance=$distance-mm,  Signal/SPAD=$signal-per-spad-kcps,  Ambient/SPAD=$ambient-per-spad-kcps | $get-status-string"

  get-status-string -> string:
    if range-status == 0:
      return "✓ Valid measurement"
    else if range-status == 1:
      return "/ Warning! Sigma is above the defined threshold"
    else if range-status == 2:
      return "/ Warning! Signal is below the defined threshold"
    else if range-status == 3:
      return "✗ Error: Measured distance is below detection threshold"
    else if range-status == 4:
      return "✗ Error: Phase out of valid limit"
    else if range-status == 5:
      return "✗ Error: Hardware Fail"
    else if range-status == 6:
      return "/ Warning: Phase valid but no wrap around check performed"
    else if range-status == 7:
      return "✗ Error: Wrapped target, phase does not match"
    else if range-status == 8:
      return "✗ Error: Processing fail"
    else if range-status == 9:
      return "✗ Error: Crosstalk signal fail"
    else if range-status == 10:
      return "✗ Error: Interrupt error"
    else if range-status == 11:
      return "✗ Error: Merged target"
    else if range-status == 12:
      return "✗ Error: Signal is too low"
    else:
      return "✗ Unknown Error"
