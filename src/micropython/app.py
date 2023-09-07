from machine import I2C, Pin
import machine
import micropython
from micropython import const
import time
import vl53l4cd
import statistics
import lowpower
import sensorcfg

TEMPERATURE_CONVERSION_FACTOR = 3.3 / (65535)
TEMPERATURE_OFFSET = const(0.706)

TIME_TO_MEASURE = const(100)
MEASURE_FREQUENCY = const(300)

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

start_delay = 5
for i in range(start_delay):
    print("Start in {}s".format(start_delay-i))
    time.sleep(1)
print ("Starting...")

print("Current RP2040 frequency: {} MHz".format(machine.freq() / 1000000))
# machine.freq(62500000)
# print("New RP2040 frequency: {} MHz".format(machine.freq() / 1000000))

debugging = False
scheduler = micropython.schedule
last_temperature = 0

shutter = Pin(29, Pin.OUT, Pin.PULL_DOWN)
focus = Pin(28, Pin.OUT, Pin.PULL_DOWN)
led = Pin(13, Pin.OUT)
temperature_pin = machine.ADC(4)

i2c = I2C(1, sda=Pin(10), scl=Pin(11))
vl53_1 = vl53l4cd.VL53L4CD(i2c, "VL53_1", VL53_XSHUNT_1, VL53_INT_1, VL53_ADDR_1, debug=debugging)
vl53_2 = vl53l4cd.VL53L4CD(i2c, "VL53_2", VL53_XSHUNT_2, VL53_INT_2, VL53_ADDR_2, debug=debugging)
vl53_3 = vl53l4cd.VL53L4CD(i2c, "VL53_3", VL53_XSHUNT_3, VL53_INT_3, VL53_ADDR_3, debug=debugging)
vl53_4 = vl53l4cd.VL53L4CD(i2c, "VL53_4", VL53_XSHUNT_4, VL53_INT_4, VL53_ADDR_4, debug=debugging)

# Globale Variable, die den aktuellen Status des Events speichert
global event_in_progress
event_in_progress = False

global is_initial_irq
is_initial_irq = True

def event_handler(args):
    global event_in_progress

    print("Start Event")
    led.on()
    focus.on()
    time.sleep(0.01)
    shutter.on()
    time.sleep(0.5)
    focus.off()
    shutter.off()
    time.sleep(1.5)
    led.off()

    print("Camera Triggered")
    event_in_progress = False

def interrupt_handler(pin):
    print("IQR on pin {}".format(pin))
    global event_in_progress
    
    if pin is vl53_1.interrupt_pin:
        vl53_1.clear_interrupt()
    if pin is vl53_2.interrupt_pin:
        vl53_2.clear_interrupt()
    elif pin is vl53_3.interrupt_pin:
        vl53_3.clear_interrupt()
    elif pin is vl53_4.interrupt_pin:
        vl53_4.clear_interrupt()

    global is_initial_irq
    if is_initial_irq:
        return
    if not event_in_progress:
        event_in_progress = True
        print("Scheduling event...")
        micropython.schedule(event_handler, None)

    print("IQR on pin {} ended!".format(pin))

def get_temperature():
    temps = []
    for i in range(25):
        reading = temperature_pin.read_u16() * TEMPERATURE_CONVERSION_FACTOR 
        temperature = 27 - (reading - TEMPERATURE_OFFSET)/0.001721
        # print("{}C".format(temperature))
        temps.append(temperature)
        time.sleep(0.05)

    avg_temp = statistics.mean(temps)
    print("Average temperature: {}C".format(avg_temp))
    return avg_temp

# last_temperature = get_temperature()

sensor_array = [vl53_1, vl53_2, vl53_3, vl53_4]
print(i2c.scan())
for sensor in sensor_array:
    sensor.begin()

sensorcfg = sensorcfg.SensorCfg()
success = sensorcfg.load()
# success = False
if not success:
    sensorcfg.clear()
    print("No sensor data found. Calibrating...")
    for sensor in sensor_array:
        offset = sensor.calibrate_offset(100, 30)
        xtalk = sensor.calibrate_xtalk(100, 30)
        sensorcfg.set_sensor(sensor.name, offset, xtalk)
    sensorcfg.save()

for sensor in sensor_array:
    print("----------{}------------".format(sensor.name))
    sensor.start_temperature_update()
    sensor.set_xtalk(sensorcfg.get_sensor(sensor.name)["xtalk"])
    sensor.set_offset(sensorcfg.get_sensor(sensor.name)["offset"])
    threashold_mm = sensor.get_height_trigger_threashold(30, 6)
    sensor.sensor_init(vl53l4cd.Mode.LOW_POWER)
    sensor.set_signal_threshold(7000)
    print("Signal Threashold: {}".format(sensor.get_signal_threshold()))
    sensor.set_sigma_threshold(10)
    print("Sigma mm: {}".format(sensor.get_sigma_threshold()))
    sensor.set_measure_timings(TIME_TO_MEASURE, MEASURE_FREQUENCY)
    sensor.set_interrupt(threashold_mm, True)
    sensor.enable_interrupt(interrupt_handler)
    sensor.start_ranging()

time.sleep(0.1)
is_initial_irq = False

def check_temperature(tmp):
    global last_temperature
    print("Check Temperature task running...")
    current_temperature = get_temperature()
    if abs(current_temperature - last_temperature) > 5:
        print("Temperature changed by more than 5 degrees. Recalibrating...")
        machine.reset()

# temperature_timer = machine.Timer(-1)
# temperature_timer.init(period=3600*1000, mode=machine.Timer.PERIODIC, callback=check_temperature)

while True:
    print("Sleeping...")
    # machine.lightsleep()
#     print("woke... n wait")
    lowpower.dormant_until_pins([VL53_INT_1, VL53_INT_2, VL53_INT_3, VL53_INT_4], edge=False , high=False)
    # lowpower.lightsleep()
    print("woke... n wait")
    time.sleep(3)
