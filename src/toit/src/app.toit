import .rgb-led show RGBLED
import gpio
import i2c
import .vl53l4cd
import system.storage
import esp32
import .trigger
import .ble.api_service_client show ApiClient
import .ble.command
import log
import monitor

// TEMPERATURE_CONVERSION_FACTOR ::= 3.3 / (65535)
// TEMPERATURE_OFFSET ::= 0.706

TIME-TO-MEASURE   ::= 40
MEASURE-FREQUENCY ::= 70

VL53_ADDR_1     ::= 42
VL53_XSHUNT_1   ::= 47
VL53_INT_1      ::= 21

VL53_ADDR_2     ::= 43
VL53_XSHUNT_2   ::= 17
VL53_INT_2      ::= 18

VL53_ADDR_3     ::= 44
VL53_XSHUNT_3   ::= 5
VL53_INT_3      ::= 6

VL53_ADDR_4     ::= 45
VL53_XSHUNT_4   ::= 8
VL53_INT_4      ::= 7

vl53-1 := ?
irq-task-1 := ?
vl53-2 := ?
irq-task-2 := ?
vl53-3 := ?
irq-task-3 := ?
vl53-4 := ?
irq-task-4 := ?

logger ::= log.Logger log.DEBUG_LEVEL log.DefaultTarget --name="app"
command-channel := monitor.Channel 1
api/ApiClient:=?
sensor-array := []
bucket := ?
led := ?

main:
  log.debug "Starting VL53L4CD Sensor Array $esp32.reset-reason"
  log.debug "Wakeup cause: $esp32.wakeup-cause"
  // if esp32 

  debugging := false
  last_temperature := 0
  led = RGBLED 14 13 12
  led.yellow

  init-ble-api

  bucket = storage.Bucket.open --flash "sensor-cfg"

  bus := i2c.Bus
    --sda=gpio.Pin 38
    --scl=gpio.Pin 48

  vl53-1 = VL53L4CD bus "VL53_1" VL53_XSHUNT_1 VL53_INT_1 VL53_ADDR_1 --debug=debugging --low-power=true
  vl53-2 = VL53L4CD bus "VL53_2" VL53_XSHUNT_2 VL53_INT_2 VL53_ADDR_2 --debug=debugging --low-power=true
  vl53-3 = VL53L4CD bus "VL53_3" VL53_XSHUNT_3 VL53_INT_3 VL53_ADDR_3 --debug=debugging --low-power=true
  vl53-4 = VL53L4CD bus "VL53_4" VL53_XSHUNT_4 VL53_INT_4 VL53_ADDR_4 --debug=debugging --low-power=true

  sensor-array = [vl53_1, vl53_2, vl53_3, vl53_4]
  print bus.scan
  sensor-array.do: |sensor|
    sensor.init

  start-detection
  enable-interrupt-handler
  
  3.repeat:
    led.red
    sleep --ms=250
    led.off
    sleep --ms=250
  
  command := ?
  while true:
    handle-command

handle-command:
  command := command-channel.receive --blocking=true
  if command == Command.TRIGGER:
    led.blue
    trigger
    led.off
  else if command == Command.CALIBRATE:
    calibrate
  else:
    print "Unknown Command"

  // deep-sleep

init-ble-api:
  logger.debug "Initializing BLE API"
  api = ApiClient
  api.open --timeout=(Duration --s=10) --if_absent=: null
  if not api:
    logger.error "API Service unavailable"
  
  on-trigger/Lambda := ::
    command-channel.send Command.TRIGGER

  on-calibrate/Lambda := ::
    command-channel.send Command.CALIBRATE

  api.set-on-trigger-callback on-trigger
  api.set-on-calibrate-callback on-calibrate

calibrate:
  led.green
  disable-interrupt-handler
  
  sensor-array.do: |sensor|
    sensor.disable
  sensor-array.do: |sensor|
    sensor.init
  start-detection
  enable-interrupt-handler
  
  led.off

disable-interrupt-handler:
  irq-task-1.cancel
  irq-task-2.cancel
  irq-task-3.cancel
  irq-task-4.cancel

enable-interrupt-handler:
  irq-task-1 = task::vl53l-1-interrupt-handler
  irq-task-2 = task::vl53l-2-interrupt-handler
  irq-task-3 = task::vl53l-3-interrupt-handler
  irq-task-4 = task::vl53l-4-interrupt-handler

deep-sleep:
  esp32.enable-external-wakeup ((1 << VL53-INT-1) | (1 << VL53-INT-2) | (1 << VL53-INT-3) | (1 << VL53-INT-4)) false
  esp32.deep-sleep (Duration --m=1)

start-detection:
  sensor-array.do: |sensor|
    print "---------- $sensor.name ------------"
    sensor.start-temperature-update
    apply_sensor_cfg sensor bucket
    threashold-mm := sensor.get-height-trigger-threshold 30 10
    sensor.set-mode MODE-LOW-POWER
    sensor.set-signal-threshold 5000
    print "Signal Threashold: $sensor.get-signal-threshold"
    sensor.set-sigma-threshold 10
    print "Sigma mm: $sensor.get_sigma_threshold"
    sensor.set-measure-timings TIME-TO-MEASURE MEASURE-FREQUENCY
    sensor.set-interrupt threashold-mm true
    sensor.start-ranging
    print "System Status: $sensor.get-system-status"
    print "result-range-status: $sensor.driver_.get-result-range-status"
    sensor.clear-interrupt

apply-sensor-cfg sensor bucket:
  e1 := catch:
    offset := bucket[sensor.name+"-offset"]
    print "Setting offset for $sensor.name to $offset"
    sensor.set-offset offset
  if e1: print "Error setting offset for $sensor.name"

  e2 := catch:
    xtalk := bucket[sensor.name+"-xtalk"]
    if xtalk > 0:
      print "Setting xtalk for $sensor.name to $xtalk"
      sensor.set-xtalk xtalk
  if e2: print "Error setting xtalk for $sensor.name"

vl53l-1-interrupt-handler:
  interrupt-handler vl53-1

vl53l-2-interrupt-handler:
  interrupt-handler vl53-2

vl53l-3-interrupt-handler:
  interrupt-handler vl53-3

vl53l-4-interrupt-handler:
  interrupt-handler vl53-4

interrupt-handler sensor:
  catch --trace:
    while true:
      sensor.interrupt_pin_.wait-for 0
      led.green
      print "Interrupt $sensor.name 0"
      print "Distance: $sensor.get-distance"
      trigger
      sensor.clear-interrupt
      sensor.interrupt_pin_.wait-for 1
      led.off
      print "Interrupt $sensor.name 1"