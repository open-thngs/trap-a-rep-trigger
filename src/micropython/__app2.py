from machine import I2C, Pin, deepsleep
import machine
import micropython
from micropython import const
import time
import vl53l4cd
import statistics
from rgbled import RGBLED
from sensorcfg import SensorCfg
import esp32

TEMPERATURE_CONVERSION_FACTOR = 3.3 / (65535)
TEMPERATURE_OFFSET = const(0.706)

TIME_TO_MEASURE = const(40)
MEASURE_FREQUENCY = const(50)

VL53_ADDR_2 = const(43)
VL53_XSHUNT_2 = const(17)
VL53_INT_2 = const(18)

debugging = False
last_temperature = 0
led = RGBLED()
led.green()

shutter = Pin(11, Pin.OUT, Pin.PULL_DOWN)
focus = Pin(10, Pin.OUT, Pin.PULL_DOWN)

i2c = I2C(1, sda=Pin(38), scl=Pin(48))
vl53_2 = vl53l4cd.VL53L4CD(i2c, "VL53_2", VL53_XSHUNT_2, VL53_INT_2, VL53_ADDR_2, debug=debugging)

# Globale Variable, die den aktuellen Status des Events speichert
global event_in_progress
event_in_progress = False

global is_initial_irq
is_initial_irq = True


def event_handler(args):
    global event_in_progress

    print("Start Event")
    led.blue()
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
    global is_initial_irq

    if pin is vl53_2.interrupt_pin:
        vl53_2.clear_interrupt()

    if is_initial_irq:
        print("irq ignored")
        return

    if not event_in_progress:
        event_in_progress = True
        print("Scheduling event...")
        micropython.schedule(event_handler, None)

    print("IRQ on pin {} ended!".format(pin))

# def disable_interrupts():
#     print("Disabling interrupts...")
#     for sensor in sensor_array:
#         sensor.disable_interrupt()

# def enable_interrupts():
#     print("Enabling interrupts...")
#     for sensor in sensor_array:
#         sensor.enable_interrupt(interrupt_handler)

def apply_sensor_cfg(sensorcfg):
    if sensorcfg:
        for sensor in sensor_array:
            if sensorcfg.get_sensor(sensor.name):
                sensor.set_xtalk(sensorcfg.get_sensor(sensor.name)["xtalk"])
                sensor.set_offset(sensorcfg.get_sensor(sensor.name)["offset"])
            else:
                print("No sensor data found for sensor: {}".format(sensor.name))
    else:
        print("No sensor cfg data found")

sensor_array = []
# sensor_array.append(vl53_1)
sensor_array.append(vl53_2)
# sensor_array.append(vl53_3)
# sensor_array.append(vl53_4)
print(i2c.scan())
for sensor in sensor_array:
    sensor.begin()

sensorcfg = SensorCfg()
sensorcfg.load()

for sensor in sensor_array:
    print("----------{}------------".format(sensor.name))
    sensor.start_temperature_update()
    # apply_sensor_cfg(sensorcfg)
    time.sleep(0.005)
    threashold_mm = sensor.get_height_trigger_threashold(5, 10)
    sensor.sensor_init(vl53l4cd.Mode.LOW_POWER)
    sensor.set_signal_threshold(5000)
    sensor.set_sigma_threshold(10)
    sensor.set_measure_timings(80, 100)
    sensor.set_interrupt(800, True)
    sensor.enable_interrupt(interrupt_handler)
    sensor.clear_interrupt()
    time.sleep(0.005)
    sensor.start_ranging()

time.sleep(0.1)
is_initial_irq = False

for i in range(3):
    led.red()
    time.sleep(0.25)
    led.off()
    time.sleep(0.25)
