from machine import Pin
import time
import vl53l4cd_driver
import config


class Mode:
    DEFAULT = 0
    LOW_POWER = 1


class VL53L4CD:

    sensor_id = None
    sensor_type = None
    i2caddr = None

    def __init__(self, i2c, xshut_pin, interrupt_pin, interrupt_handler, i2caddr=41, interrupt_enalbed=True) -> None:
        self.driver = vl53l4cd_driver.VL53L4CD_DRIVER(i2c)
        self.xshut_pin = Pin(xshut_pin, Pin.OUT)
        if interrupt_enalbed:
            self.interrupt_pin = Pin(interrupt_pin, Pin.IN, Pin.PULL_UP)
            self.interrupt_pin.irq(trigger=Pin.IRQ_FALLING, handler=interrupt_handler)
        self.i2caddr = i2caddr
        if i2caddr != 41:
            self.xshut_pin.on()
            time.sleep(0.01)
            self.driver.set_i2c_address(i2caddr)

    def enable_interrupt(self, threshold_mm:int, trigger_only_below_threshold):
        self.driver.set_interrupt_configuration(threshold_mm, trigger_only_below_threshold)

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
        self.driver.set_inter_measurement(1000)

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
        self.driver.set_timing_budget(timing_budget)
        self.driver.set_inter_measurement(inter_measurement)

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

    def set_interrupt_configuration(self, threshold_mm, only_below_threshold):
        self.driver.set_interrupt_configuration(threshold_mm, only_below_threshold)

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
        raise RuntimeError("Time out starting VHV.")
