from machine import Pin
from micropython import const
import machine
import time
import vl53l4cd_driver
import config
import statistics

class Mode:
    DEFAULT = 0
    LOW_POWER = 1


class VL53L4CD:

    sensor_id = None
    sensor_type = None
    i2caddr = None

    def __init__(self, i2c, xshut_pin, interrupt_pin, i2caddr=41, debug=False) -> None:
        self.driver = vl53l4cd_driver.VL53L4CD_DRIVER(i2c, debug)
        self.xshut_pin = Pin(xshut_pin, Pin.OUT)
        self.xshut_pin.off()
        self.interrupt_pin = Pin(interrupt_pin, Pin.IN, Pin.PULL_UP)
        self.i2caddr = i2caddr

    def begin(self):
        if self.i2caddr != 41:
            self.xshut_pin.on()
            time.sleep(0.01)
            self.driver.set_i2c_address(self.i2caddr)
            time.sleep(0.01)

    def set_interrupt(self, threshold_mm:int, trigger_only_below_threshold):
        self.driver.set_interrupt_configuration(threshold_mm, trigger_only_below_threshold)
        time.sleep(0.005)
        
    def enable_interrupt(self, interrupt_handler):
        self.interrupt_pin.irq(trigger=Pin.IRQ_FALLING, handler=interrupt_handler)

    def disable_interrupt(self):
        self.interrupt_pin.irq(trigger=Pin.IRQ_FALLING, handler=None)

    def get_sensor_model_id_and_type(self) -> tuple:
        if (not self.sensor_id or not self.sensor_type):
            info = self.driver.get_identification_model_id()
            self.sensor_id = info[0]
            self.sensor_type = info[1]
        return self.sensor_id, self.sensor_type
    
    def check(self):
        info = self.driver.get_identification_model_id()
        if not info == b'\xeb\xaa':
            print("Error!")
            return

    def sensor_init(self, mode:Mode):
        print("wait for boot")
        self._wait_for_boot()
        self.configure_sensor_mode(mode)

    def configure_sensor_mode(self, mode:Mode):
        if (mode == Mode.LOW_POWER):
            self._configure_sensor_low_power_mode()
        else:
            self._configure_sensor_default_mode()

    def _configure_sensor_low_power_mode(self):
        self.driver.write_config(config.VL53L4CD_ULTRA_LOW_POWER_CONFIG)
        self._start_vhv()
        self.driver.clear_interrupt()
        self.driver.stop_ranging()
        self.driver.set_macrop_loop_bound(b'\x09')
        self.driver.write(0x0B, b'\x00', addrsize=8)
        self.driver.write(0x0024, b'\x05\x00')
        self.driver.write(0x81, b'\x8a', addrsize=8)
        self.driver.write(0x004B, b'\x03')

    def _configure_sensor_default_mode(self):
        self.driver.write_config(config.VL53L4CD_ULTRA_LITE_DRIVER_CONFIG)
        self._start_vhv()
        self.driver.clear_interrupt()
        self.driver.stop_ranging()
        self.driver.set_macrop_loop_bound(b'\x09')
        self.driver.write(0x0B, b'\x00', addrsize=8)
        self.driver.write(0x0024, b'\x05\x00')
        self.set_measure_timings(50, 0)

    def set_inter_measurement_ms(self, inter_measurement_ms):
        self.driver.set_inter_measurement(inter_measurement_ms)
    
    def set_measure_timings(self, timing_budget, inter_measurement):
        self.driver.set_inter_measurement(inter_measurement)
        self.driver.set_timing_budget(timing_budget)

    def is_data_ready(self) -> bool:
        return self.driver.is_data_ready()

    def get_distance(self):
        return self.driver.get_distance()

    def enable_sensor(self):
        self.xshut_pin.on()

    def disable_sensor(self):
        self.xshut_pin.off()

    def reset(self):
        self.xshut_pin.off()
        time.sleep(0.1)
        self.xshut_pin.on()

    def get_system_status(self):
        return self.driver.get_system_status()

    def start_ranging(self):
        self.driver.start_ranging()

    def stop_ranging(self):
        self.driver.stop_ranging()

    def set_interrupt_configuration(self, threshold_mm, only_below_threshold):
        self.driver.set_interrupt_configuration(threshold_mm, only_below_threshold)
        time.sleep(0.005)

    def _wait_for_boot(self):
        for _ in range(1000):
            system_status = self.driver.get_system_status()
            if system_status == 0x03:
                return
            time.sleep(0.001)
        raise RuntimeError("Time out waiting for system boot.")
    
    def clear_interrupt(self):
        self.driver.clear_interrupt()
    
    def _start_vhv(self):
        self.driver.write(0x0087, b'\x40')
        for i in range(1000):
            if self.driver.is_data_ready:
                return
            time.sleep(0.001)
        raise RuntimeError("Timeout starting VHV")

    def start_temperature_update(self):
        print("start temperature update")
        self.driver.set_macrop_loop_bound(b'\x81')
        self.driver.write(0x0B, b'\x92')
        self.driver.set_inter_measurement(0)
        self.driver.start_ranging()

        for i in range(1000):
            while not self.driver.is_data_ready():
                time.sleep(0.001)
            
        print("temperature update done")
        self.driver.clear_interrupt()
        self.driver.stop_ranging()
        self.driver.set_macrop_loop_bound(b'\x09')
        self.driver.write(0x0B, b'\x00')
    
    def calibrate_offset(self, target_distance_mm, nb_samples):
        if (nb_samples < 5 or nb_samples > 255) or (target_distance_mm < 10 or target_distance_mm > 1000):
            raise RuntimeError("Invalid parameters")
        else:
            self.driver.set_offset(0x00, 0x00, 0x00)

            self.device_heat_loop()	

            # Device ranging
            self.driver.start_ranging()
            distances = []
            for x in range(nb_samples):
                while not self.driver.is_data_ready():
                    time.sleep(0.001)

                distances.append(self.driver.get_distance())
                self.driver.clear_interrupt()

            self.driver.stop_ranging()

            average = statistics.mean(distances)
            pre_offset = target_distance_mm - average
            tmpOff = pre_offset * 4 # who knows why they multiply by 4 mofos!? ¯\_(ツ)_/¯
            
            self.driver.set_offset(tmpOff)

    def device_heat_loop(self):
        print("Running Device heat loop (10 samples)")
        self.driver.start_ranging()
        for x in range(10): # Device heat loop (10 samples)
            while not self.driver.is_data_ready():
                time.sleep(0.001)
            
            self.driver.get_distance()
            self.driver.clear_interrupt()
        self.stop_ranging()

    def dump_debug_data(self):
        self.driver.dump_debug_data()

    def get_height_trigger_threashold(self, intensitiy=25) -> int:
        self.sensor_init(Mode.DEFAULT)

        heights = []
        print("Start calibration..")
        self.device_heat_loop()

        self.start_ranging()
        for x in range(intensitiy):
            # led.off()
            while not self.is_data_ready():
                time.sleep(0.001)

            # led.on()
            distance = self.get_distance()
            heights.append(distance)
            print("distance: {}mm".format(distance))
            self.clear_interrupt()
            
        self.stop_ranging()

        # led.off()
        mean_distance = statistics.mean(heights)
        std_deviation = statistics.stdev(heights)

        threshold = mean_distance - 5 * std_deviation
        if threshold > 1300:
            threshold = 1300

        print("Average:", mean_distance)
        print("std deviation:", std_deviation)
        print("threshold:", int(threshold))

        return int(threshold)
        