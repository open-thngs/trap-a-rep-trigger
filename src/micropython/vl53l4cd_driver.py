from constants import *
import config
import uerrno
import time
import struct

'''
uint32_t == 4 byte == >I
uint16_t == 2 byte == >H
uint8_t  == 1 byte == >B
struct.unpack(...)
'''

class VL53L4CD_DRIVER:

    def __init__(self, i2c):
        self.i2c_address = 41
        self._i2c = i2c

    def get_system_status(self):
        return self.read(FIRMWARE_SYSTEM_STATUS)[0]

    def get_identification_model_id(self):
        return self.read(IDENTIFICATION_MODEL_ID, 2)

    def set_i2c_address(self, newi2caddress):
        self.write(I2C_SLAVE_DEVICE_ADDRESS, bytearray([newi2caddress]))
        old = self.i2c_address
        self.i2c_address = newi2caddress
        print("old address: {} | new address: {}".format(old, int.from_bytes(self.read(I2C_SLAVE_DEVICE_ADDRESS), "big")))

    def write_config(self, config):
        self.write(SENSOR_CONFIG, config)

    def set_macrop_loop_bound(self, value):
        self.write(VHV_CONFIG_TIMEOUT_MACROP_LOOP_BOUND, value)

    def clear_interrupt(self):
        self.write(SYSTEM_INTERRUPT_CLEAR, b'\x01')

    def start_ranging(self):
        inter_ms = self.get_inter_measurement()
        if (inter_ms == 0):
            print("continuous mode")
            self.write(SYSTEM_START, b'\x21')
        else:
            print("autonomous mode")
            self.write(SYSTEM_START, b'\x40')

    def start_ranging_single_shot(self):
        self.write(SYSTEM_START, b'\x10')

    def stop_ranging(self):
        self.write(SYSTEM_START, b'\x00')

    def is_data_ready(self) -> bool:
        int_pol = self.get_interrupt_polaritiy()
        tmp = self.read(GPIO_TIO_HV_STATUS)[0] & 0x01
        return True if tmp == int_pol else False
    
    def get_interrupt_polaritiy(self):
        int_pol = self.read(GPIO_HV_MUX_CTRL)[0] & 0x10
        int_pol = (int_pol >> 4) & 0x01
        return 0 if int_pol else 1
    
    def get_timing_budget(self):
        """Ranging duration in milliseconds. Valid range is 10ms to 200ms."""
        osc_freq = struct.unpack(">H", self.read(0x0006, 2))[0]

        macro_period_us = 16 * (int(2304 * (0x40000000 / osc_freq)) >> 6)

        macrop_high = struct.unpack(">H", self.read(RANGE_CONFIG_A, 2))[0]

        ls_byte = (macrop_high & 0x00FF) << 4
        ms_byte = (macrop_high & 0xFF00) >> 8
        ms_byte = 0x04 - (ms_byte - 1) - 1

        timing_budget_ms = (((ls_byte + 1) * (macro_period_us >> 6)) - ((macro_period_us >> 6) >> 1)) >> 12
        if ms_byte < 12:
            timing_budget_ms >>= ms_byte
        if self.get_inter_measurement() == 0:
            # mode continuous
            timing_budget_ms += 2500
        else:
            # mode autonomous
            timing_budget_ms *= 2
            timing_budget_ms += 4300

        return int(timing_budget_ms / 1000)

    def set_timing_budget(self, timing_budget_ms):
        if not 10 <= timing_budget_ms <= 200:
            raise ValueError("Timing budget range duration must be 10ms to 200ms.")

        inter_meas = self.get_inter_measurement()
        if inter_meas != 0 and timing_budget_ms > inter_meas:
            raise ValueError(
                "Timing budget can not be greater than inter-measurement period ({})".format(
                    inter_meas
                )
            )

        osc_freq = struct.unpack(">H", self.read(0x0006, 2))[0]
        if osc_freq == 0:
            raise RuntimeError("Osc frequency is 0.")

        timing_budget_us = timing_budget_ms * 1000
        macro_period_us = int(2304 * (0x40000000 / osc_freq)) >> 6

        if inter_meas == 0:
            # continuous mode
            timing_budget_us -= 2500
        else:
            # autonomous mode
            timing_budget_us -= 4300
            timing_budget_us //= 2

        # VL53L4CD_RANGE_CONFIG_A register
        ms_byte = 0
        timing_budget_us <<= 12
        tmp = macro_period_us * 16
        ls_byte = int(((timing_budget_us + ((tmp >> 6) >> 1)) / (tmp >> 6)) - 1)
        while ls_byte & 0xFFFFFF00 > 0:
            ls_byte >>= 1
            ms_byte += 1
        ms_byte = (ms_byte << 8) + (ls_byte & 0xFF)
        self.write(RANGE_CONFIG_A, struct.pack(">H", ms_byte))

        # VL53L4CD_RANGE_CONFIG_B register
        ms_byte = 0
        tmp = macro_period_us * 12
        ls_byte = int(((timing_budget_us + ((tmp >> 6) >> 1)) / (tmp >> 6)) - 1)
        while ls_byte & 0xFFFFFF00 > 0:
            ls_byte >>= 1
            ms_byte += 1
        ms_byte = (ms_byte << 8) + (ls_byte & 0xFF)
        self.write(RANGE_CONFIG_B, struct.pack(">H", ms_byte))

    def get_inter_measurement(self):
        """
        Inter-measurement period in milliseconds. Valid range is timing_budget to
        5000ms, or 0 to disable.
        """
        reg_val = struct.unpack(">I", self.read(INTERMEASUREMENT_MS, 4))[0]
        clock_pll = struct.unpack(">H", self.read(RESULT_OSC_CALIBRATE_VAL, 2))[0]
        clock_pll &= 0x3FF
        clock_pll = int(1.065 * clock_pll)
        if clock_pll is 0: return 0
        return int(reg_val / clock_pll)

    def set_inter_measurement(self, inter_measurement_ms):
        timing_bud = self.get_timing_budget()
        if inter_measurement_ms != 0 and inter_measurement_ms < timing_bud:
            raise ValueError("Inter-measurement period can not be less than timing budget ({})".format(timing_bud))

        clock_pll = struct.unpack(">H", self.read(RESULT_OSC_CALIBRATE_VAL, 2))[0]
        clock_pll &= 0x3FF
        int_meas = int(INTER_MEASUREMENT_FACTOR * inter_measurement_ms * clock_pll)
        self.write(INTERMEASUREMENT_MS, struct.pack(">I", int_meas))

        # need to reset timing budget so that it will be based on new inter-measurement period
        #self.set_timing_budget(timing_bud)

    def _get_clock_pll(self):
        clock_pll_bytes = self.read(RESULT_OSC_CALIBRATE_VAL, 2)
        clock_pll = int.from_bytes(clock_pll_bytes, 'big') & 0x3FF
        return clock_pll

    def _get_inter_measurement(self):
        reg_val_bytes = self.read(INTERMEASUREMENT_MS, 4)
        return int.from_bytes(reg_val_bytes, 'big')

    def get_osc_frequency(self):
        osc_freq_bytes = self.read(OSC_FREQUENCY, 2)
        return int.from_bytes(osc_freq_bytes, 'big')
    
    def get_range_config_a(self):
        range_config_a = self.read(RANGE_CONFIG_A, 2)
        return int.from_bytes(range_config_a, "big")

    def get_distance(self):
        dist = self.read(RESULT_DISTANCE, 2)
        return int.from_bytes(dist, "big")
    
    def set_interrupt_configuration(self, threshold_mm, trigger_only_below_threshold):
        self.write(SYSTEM_INTERRUPT, b'\x00' if trigger_only_below_threshold else b'\x20')
        self.write(THRESH_HIGH, struct.pack(">H", threshold_mm))
        self.write(THRESH_LOW, struct.pack(">H", threshold_mm))

    def write(self, address, data, addrsize=16):
        try:
            self._i2c.writeto_mem(self.i2c_address, address, data, addrsize=addrsize)
        except OSError as error:
            if error.errno == uerrno.ENODEV:
                raise RuntimeError("Sensor not found")
            else:
                raise RuntimeError(f"Error while writing to I2C bus: OSError code {error.errno}")

    def read(self, address, length=1, addrsize=16):
        try:
            return self._i2c.readfrom_mem(self.i2c_address, address, length, addrsize=addrsize)
        except OSError as error:
            if error.errno == uerrno.ENODEV:
                raise RuntimeError("Sensor could not be found")
            else:
                raise RuntimeError(f"Error while reading from to I2C bus: OSError code {error.errno}")
