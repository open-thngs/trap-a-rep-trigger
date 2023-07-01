from machine import I2C, Pin
import time
import vl53l4cd
import _vl53l4cd as sensor

print ("Start...")

xshut_pin = Pin(7, Pin.OUT)
xshut_pin.off()
xshut_pin = Pin(5, Pin.OUT)
xshut_pin.off()
xshut_pin = Pin(3, Pin.OUT)
xshut_pin.off()
xshut_pin = Pin(0, Pin.OUT)
xshut_pin.off()

def calibrate_sensor_height(sensor:vl53l4cd.VL53L4CD, intensitiy) -> int:
    sensor.sensor_init(vl53l4cd.Mode.DEFAULT)
    sensor.set_measure_timings(100, 0)
    sensor.start_ranging()
    heights = []
    print("Start calibration")
    for x in range(intensitiy):
        while not sensor.is_data_ready():
            pass
        
        sensor.clear_interrupt()
        distance = sensor.get_distance()
        print("distance: {}mm".format(distance))
        heights.append(distance)

    average_height = 0
    max_height = 0
    min_height = 255
    for height in heights:
        average_height += height
        max_height = height if height > max_height else max_height
        min_height = height if height < min_height else min_height
    average_height = average_height/intensitiy

    print("average_height: {}, max_height: {}, min_height: {}".format(average_height, max_height, min_height))
    return min_height-5

def on_object_detected_1(pin):
    vl53_1.clear_interrupt()
    print("vl53_1 detection Distance: {} mm".format(vl53_1.get_distance()))

def on_object_detected_2(pin):
    vl53_2.clear_interrupt()
    print("vl53_2 detection Distance: {} mm".format(vl53_2.get_distance()))

def on_object_detected_3(pin):
    vl53_3.clear_interrupt()
    print("vl53_3 detection Distance: {} mm".format(vl53_3.get_distance()))

def on_object_detected_4(pin):
    vl53_4.clear_interrupt()
    print("vl53_4 detection Distance: {} mm".format(vl53_4.get_distance()))

i2c0 = I2C(1, sda=Pin(10), scl=Pin(11))
print(i2c0.scan()) ##should be empty

vl53_1 = vl53l4cd.VL53L4CD(i2c0, 6, 7, on_object_detected_1, 42, True)
# vl53_1 = vl53l4cd.VL53L4CD(i2c0, 6, 7, on_object_detected_1, 42)
# vl53_2 = vl53l4cd.VL53L4CD(i2c0, 4, 5, on_object_detected_2, 43)
# vl53_3 = vl53l4cd.VL53L4CD(i2c0, 2, 3, on_object_detected_3, 44)
# vl53_4 = vl53l4cd.VL53L4CD(i2c0, 0, 1, on_object_detected_4, 45)

# sensor_array = [vl53_1, vl53_2, vl53_3, vl53_4]

print(i2c0.scan())

threashold_mm = calibrate_sensor_height(vl53_1, 25)
vl53_1.sensor_init(vl53l4cd.Mode.LOW_POWER)
vl53_1.enable_interrupt(threashold_mm, True)
vl53_1.set_measure_timings(10, 200)
vl53_1.start_ranging()

# for sensor in sensor_array:
#     sensor.sensor_init(vl53l4cd.Mode.LOW_POWER)
#     sensor.enable_interrupt(threashold_mm, True)
#     sensor.set_measure_timings(10, 200)
#     sensor.start_ranging()




#vl53_1.reset()

# vl53_1.sensor_init(vl53l4cd.Mode.LOW_POWER)

# vl53_1.enable_interrupt(9, on_object_detected, 120, True)
# vl53_1.set_measure_timings(10, 200)

# vl53_1.start_ranging()
# while not vl53_1.is_data_ready():
#     pass

# print("clear")
# vl53_1.clear_interrupt()







# while True:
#     time.sleep(0.01)
    # while not vl53_1.is_data_ready():
    #     time.sleep(0.005)
    #     pass
    # vl53_1.clear_interrupt()
    # print("vl53_1 Distance: {} mm".format(vl53_1.get_distance()))
    


######### OLD DRIVER
# xshut_pin = Pin(18, Pin.OUT)
# xshut_pin.on()
# sensorino = sensor.VL53L4CD(i2c0)
# model_id, module_type = sensorino.model_info
# print("Model ID: 0x{:0X}".format(model_id))
# print("Module Type: 0x{:0X}".format(module_type))

# sensorino.start_ranging()
# print("ranging started")

# while True:
#     while not sensorino.data_ready:
#         pass
#     sensorino.clear_interrupt()
#     print("vl53_1 Distance: {} mm".format(sensorino.distance))



# print("VL53L4CD 1 Simple Test.")
# print("--------------------")
# model_id, module_type = vl53_1.model_info
# print("Model ID: 0x{:0X}".format(model_id))
# print("Module Type: 0x{:0X}".format(module_type))
# print("Timing Budget: {}".format(vl53_1.timing_budget))
# print("Inter-Measurement: {}".format(vl53_1.inter_measurement))
# print("--------------------")


# vl53_1.start_ranging()


# while True:
#     time.sleep(1000)
    # while not vl53_1.data_ready:
    #     pass
    # vl53_1.clear_interrupt()
    # print("vl53_1 Distance: {} mm".format(vl53_1.distance))

    # while not vl53_2.data_ready:
    #     pass
    # vl53_2.clear_interrupt()
    # print("vl53_2 Distance: {} cm".format(vl53_2.distance))

