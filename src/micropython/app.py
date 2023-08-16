from machine import I2C, Pin
import micropython
import time
import vl53l4cd
import _vl53l4cd as sensor
import uasyncio
import statistics

print ("Start...")

scheduler = micropython.schedule

shutter = Pin(29, Pin.OUT, Pin.PULL_DOWN)
focus = Pin(28, Pin.OUT, Pin.PULL_DOWN)
led = Pin(13, Pin.OUT)

i2c0 = I2C(1, sda=Pin(10), scl=Pin(11))
##########################(i2c | shunt | int | address)
vl53_1 = vl53l4cd.VL53L4CD(i2c0,    0,     1,  42)
vl53_2 = vl53l4cd.VL53L4CD(i2c0,    2,     3,  43)
vl53_3 = vl53l4cd.VL53L4CD(i2c0,    4,     5,  44)
vl53_4 = vl53l4cd.VL53L4CD(i2c0,    25,    24, 45)

# Globale Variable, die den aktuellen Status des Events speichert
global event_in_progress
event_in_progress = False

global is_initial_irq
is_initial_irq = True

def event_handler(arg):
    global event_in_progress

    print("Start Event")
    led.on()
    focus.on()
    time.sleep(0.01)
    shutter.on()
    time.sleep(0.5)
    focus.off()
    shutter.off()
    time.sleep(3)
    led.off()

    print("Camera Triggered")
    event_in_progress = False

def calibrate_sensor_height(sensor:vl53l4cd.VL53L4CD, intensitiy) -> int:
    sensor.sensor_init(vl53l4cd.Mode.DEFAULT)
    sensor.set_measure_timings(100, 200)
    sensor.start_ranging()
    heights = []
    print("Start calibration")
    for x in range(intensitiy):
        while not sensor.is_data_ready():
            time.sleep(0.01)
        
        distance = sensor.get_distance()
        print("distance: {}mm".format(distance))
        heights.append(distance)
        time.sleep(0.1)

    mean_distance = statistics.mean(heights)
    std_deviation = statistics.stdev(heights)

    threshold = mean_distance - 5 * std_deviation

    print("Durchschnitt:", mean_distance)
    print("Standardabweichung:", std_deviation)
    print("Schwellenwert:", int(threshold))
    return int(threshold)

def interrupt_handler(pin):
    print("IQR on pin {}".format(pin))
    global event_in_progress
    
    # if pin is vl53_1.interrupt_pin:
    #     vl53_1.clear_interrupt()
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
        micropython.schedule(event_handler, None)
    #print("vl53_4 detection Distance: {} mm".format(vl53_4.get_distance()))

sensor_array = [ vl53_2, vl53_3, vl53_4]
print(i2c0.scan())

for sensor in sensor_array:
    sensor.begin()
    threashold_mm = calibrate_sensor_height(sensor, 25)
    sensor.sensor_init(vl53l4cd.Mode.LOW_POWER)
    sensor.set_interrupt(threashold_mm, True)
    sensor.enable_interrupt(interrupt_handler)
    sensor.set_measure_timings(100, 200)
    sensor.start_ranging()

is_initial_irq = False