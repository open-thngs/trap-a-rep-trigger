import gpio
import i2c
import .vl53l4cd-driver show VL53L4CD-DRIVER
import .config
import ringbuffer

MODE-DEFAULT := "default"
MODE-LOW-POWER := "low-power"

class VL53L4CD:
  bus_ := ?
  name := ?
  driver_/VL53L4CD-DRIVER? := ?
  xshut-pin_/gpio.Pin? := ?
  interrupt-pin_/gpio.Pin? := ?
  i2caddr_ := ?
  is-first-interrupt := true

  constructor .bus_ .name/string xshut_pin/int interrupt_pin/int .i2caddr_=41 --low-power/bool --debug=false:
    driver_ = VL53L4CD-DRIVER bus_ i2caddr_ debug
    xshut-pin_ = gpio.Pin.out xshut_pin
    xshut-pin_.set 0
    interrupt-pin_ = gpio.Pin.in interrupt_pin

  init:
    xshut-pin_.set 1
    driver_.init

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
    driver_.write_config VL53L4CD-ULTRA-LOW-POWER-CONFIG
    start_vhv
    driver_.clear_interrupt
    driver_.stop_ranging
    driver_.set_macrop_loop_bound 0x09
    driver_.device_.registers.write-u8 0x0B 0x00
    driver_.write_ #[0x00, 0x24] #[0x05, 0x00]
    driver_.device_.registers.write-u8 0x81 0x8a
    driver_.write_ #[0x00,0x4B] #[0x03]

  configure-sensor-default-mode_:
    driver_.write_config VL53L4CD-ULTRA-LITE-DRIVER-CONFIG
    start_vhv
    driver_.clear_interrupt
    driver_.stop_ranging
    driver_.set_macrop_loop_bound 0x09
    driver_.device_.registers.write-u8 0x0B 0x00
    driver_.write_ #[0x00, 0x24] #[0x05, 0x00]
    set_measure_timings 50 0

  set-inter-measurement-ms inter-measurement-ms:
    driver_.set-inter-measurement inter-measurement-ms
    
  set-measure-timings timing-budget inter-measurement:
    driver_.set_inter_measurement inter_measurement
    driver_.set_timing_budget timing_budget

  set-interrupt threashold-mm trigger-only-below-threshold:
    driver_.set-interrupt-config threashold-mm trigger-only-below-threshold
    sleep --ms=5

  wait-for-boot:
    with-timeout (Duration --ms=1000):
      while true:
        if driver_.get-system-status == 0x03:
          return
        sleep --ms=1

  clear-interrupt:
    driver_.clear-interrupt

  get-interrupt-polarity:
    return driver_.get-interrupt-polarity

  get-signal-threshold -> int:
    return driver_.get-signal-threshold

  set-signal-threshold threshold:
    driver_.set-signal-threshold threshold

  get-sigma-threshold -> int:
    return driver_.get-sigma-threshold

  set-sigma-threshold threshold:
    driver_.set-sigma-threshold threshold

  start-vhv:
    driver_.start-vhv
    with-timeout (Duration --ms=1000):
      while true:
        if driver_.is-data-ready:
          return
        sleep --ms=1

  start-temperature-update:
    driver_.set-macrop-loop-bound 0x81
    driver_.write_ #[0x0B] #[0x92]
    driver_.set-inter-measurement 0
    driver_.start-ranging

    with-timeout (Duration --ms=1000):
      while true:
        if driver_.is-data-ready:
          return
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
      
      driver_.get-distance
      driver_.clear-interrupt
    driver_.stop-ranging

  get-height-trigger-threshold intensity=25 factor=5.0 -> int:
    set-mode MODE-DEFAULT

    heights := ringbuffer.RingBuffer intensity
    device-heat-loop
    
    start-ranging
    intensity.repeat:
      while not driver_.is-data-ready:
        sleep --ms=1
      
      heights.append (driver_.get-distance).to-float
      print "Height added: $heights.get-last"
      driver_.clear-interrupt

    stop-ranging
    mean-distance := heights.average
    std-deviation := heights.std-deviation

    threshold := mean-distance - factor * std-deviation
    print "Measured Threshold: $threshold"
    if threshold > 1300 or threshold <= 0:
      threshold = 1300.0

    print "Average: $mean-distance"
    print "Std Deviation: $std-deviation"
    print "Threshold: $threshold"

    return threshold.to-int

  calibrate-offset target-distance-mm nb-samples:
    if (nb-samples < 5 or nb-samples > 255) or (target-distance-mm < 10 or target-distance-mm > 1000):
      throw "Invalid offset calibration parameters"

    driver_.set-offset 0x00 0x00 0x00
    device-heat-loop
    start-ranging

    distances := ringbuffer.RingBuffer nb-samples
    nb-samples.repeat:
      while not driver_.is-data-ready:
        sleep --ms=1

      distances.append (driver_.get-distance).to-float
      driver_.clear-interrupt
    
    stop-ranging

    mean-distance := distances.average
    pre-offset := target-distance-mm - mean-distance
    tmp-offset := pre-offset * 4
    driver_.set-offset tmp-offset 0x00 0x00
    return tmp-offset

  calibrate-xtalk target-distance-mm nb-samples:
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
      driver_.clear-interrupt

      if(result.range_status == 0 and it > 0):
          //* Discard invalid measurements and first frame */
          average-distance += result.distance-mm
          average-spad-nb += result.number-of-spad
          average-signal += result.signal-rate-kcps
          counter-nb-samples += 1
        
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
        throw "Xtalk compensation failed"
    
    driver_.set-cross-talk xtalk-kcps.to-int
    return xtalk_kcps

  get-result -> Result:
    result/Result := Result
    result.range-status = driver_.get-result-range-status
    result.number-of-spad = driver_.get-result-spad-nb
    result.signal-rate-kcps = driver_.get-result-signal-rate
    result.ambient-rate-kcps = driver_.get-result-ambient-rate
    result.sigma-mm = driver_.get-result-sigma
    result.distance-mm = driver_.get-result-distance
    result.signal-per-spad-kcps = result.signal-rate-kcps / result.number-of-spad
    result.ambient-per-spad-kcps = result.ambient-rate-kcps / result.number-of-spad

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