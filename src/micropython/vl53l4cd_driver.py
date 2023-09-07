from constants import *
import uerrno
import struct

'''
uint32_t == 4 byte == >I
uint16_t == 2 byte == >H
uint8_t  == 1 byte == >B
struct.unpack(...)
'''

class VL53L4CD_DRIVER:

    status_rtn = [ 255, 255, 255, 5, 2, 4, 1, 7, 3,
                0, 255, 255, 9, 13, 255, 255, 255, 255, 10, 6,
                255, 255, 11, 12 ]

    def __init__(self, i2c, debug=False):
        self.i2c_address = 41
        self._i2c = i2c
        self.debug = debug

    def get_system_status(self):
        self.debug_print("get_system_status")
        return self.read(FIRMWARE_SYSTEM_STATUS)[0]

    def get_identification_model_id(self):
        self.debug_print("get_identification_model_id")
        return self.read(IDENTIFICATION_MODEL_ID, 2)

    def set_i2c_address(self, newi2caddress):
        self.debug_print("set_i2c_address")
        self.write(I2C_SLAVE_DEVICE_ADDRESS, bytearray([newi2caddress]))
        old = self.i2c_address
        self.i2c_address = newi2caddress
        print("old address: {} | new address: {}".format(old, int.from_bytes(self.read(I2C_SLAVE_DEVICE_ADDRESS), "big")))

    def write_config(self, config):
        self.debug_print("write_config")
        self.write(SENSOR_CONFIG, config)

    def set_macrop_loop_bound(self, value):
        self.debug_print("set_macrop_loop_bound")
        self.write(VHV_CONFIG_TIMEOUT_MACROP_LOOP_BOUND, value)

    def clear_interrupt(self):
        self.debug_print("clear_interrupt")
        self.write(SYSTEM_INTERRUPT_CLEAR, b'\x01')

    def start_ranging(self):
        self.debug_print("start_ranging")
        inter_ms = self.get_inter_measurement()
        if (inter_ms == 0):
            self.debug_print("continuous mode")
            self.write(SYSTEM_START, b'\x21')
        else:
            self.debug_print("autonomous mode")
            self.write(SYSTEM_START, b'\x40')

    def start_ranging_single_shot(self):
        self.debug_print("start_ranging_single_shot")
        self.write(SYSTEM_START, b'\x10')

    def stop_ranging(self):
        self.debug_print("stop_ranging")
        self.write(SYSTEM_START, b'\x00')

    def is_data_ready(self) -> bool:
        self.debug_print("is_data_ready")
        int_pol = self.get_interrupt_polaritiy()
        tmp = self.read(GPIO_TIO_HV_STATUS)[0] & 0x01
        return True if tmp == int_pol else False
    
    def get_interrupt_polaritiy(self):
        self.debug_print("get_interrupt_polaritiy")
        int_pol = self.read(GPIO_HV_MUX_CTRL)[0] & 0x10
        int_pol = (int_pol >> 4) & 0x01
        return 0 if int_pol else 1
    
    def get_timing_budget(self):
        self.debug_print("get_timing_budget")
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
        self.debug_print("set_timing_budget")
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
        self.debug_print("get_inter_measurement")
        reg_val = struct.unpack(">I", self.read(INTERMEASUREMENT_MS, 4))[0]
        clock_pll = struct.unpack(">H", self.read(RESULT_OSC_CALIBRATE_VAL, 2))[0]
        clock_pll &= 0x3FF
        clock_pll = int(1.065 * clock_pll)
        if clock_pll is 0: return 0
        return int(reg_val / clock_pll)

    def set_inter_measurement(self, inter_measurement_ms):
        self.debug_print("set_inter_measurement")
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
        self.debug_print("_get_clock_pll")
        clock_pll_bytes = self.read(RESULT_OSC_CALIBRATE_VAL, 2)
        clock_pll = int.from_bytes(clock_pll_bytes, 'big') & 0x3FF
        return clock_pll

    def _get_inter_measurement(self):
        self.debug_print("_get_inter_measurement")
        reg_val_bytes = self.read(INTERMEASUREMENT_MS, 4)
        return int.from_bytes(reg_val_bytes, 'big')

    def get_osc_frequency(self):
        self.debug_print("get_osc_frequency")
        osc_freq_bytes = self.read(OSC_FREQUENCY, 2)
        return int.from_bytes(osc_freq_bytes, 'big')
    
    def get_range_config_a(self):
        self.debug_print("get_range_config_a")
        range_config_a = self.read(RANGE_CONFIG_A, 2)
        return int.from_bytes(range_config_a, "big")

    def get_distance(self):
        self.debug_print("get_distance")
        dist = self.read(RESULT_DISTANCE, 2)
        return int.from_bytes(dist, "big")
    
    def set_interrupt_configuration(self, threshold_mm, trigger_only_below_threshold):
        self.debug_print("set_interrupt_configuration")
        self.write(SYSTEM_INTERRUPT, b'\x00' if trigger_only_below_threshold else b'\x20')
        self.write(THRESH_HIGH, struct.pack(">H", threshold_mm))
        self.write(THRESH_LOW, struct.pack(">H", threshold_mm))

    def set_offset(self, range_offset_mm, inner_offset_mm=0x00, outer_offset_mm=0x00):
        self.write(RANGE_OFFSET_MM, struct.pack(">H", range_offset_mm))
        self.write(INNER_OFFSET_MM, struct.pack(">H", inner_offset_mm))
        self.write(OUTER_OFFSET_MM, struct.pack(">H", outer_offset_mm))

    # def set_cross_talk_manual(self, xtalk_plane_offset_kcps):
    #     self.write(XTALK_PLANE_OFFSET_KCPS, struct.pack(">H", (xtalk_plane_offset_kcps << 9)))
    #     self.write(XTALK_X_PLANE_GRADIENT_KCPS, struct.pack(">H", 0x00))
    #     self.write(XTALK_Y_PLANE_GRADIENT_KCPS, struct.pack(">H", 0x00))

    def set_cross_talk(self, xtalk_plane_offset_kcps):
        self.write(XTALK_PLANE_OFFSET_KCPS, struct.pack(">H", (xtalk_plane_offset_kcps * 512)))

    def get_cross_talk(self):
        xtalk_plane_offset_kcps = struct.unpack(">H", self.read(XTALK_PLANE_OFFSET_KCPS, 2))[0]
        tmp_xtalk = xtalk_plane_offset_kcps / 512.0
	    
        return int(tmp_xtalk)
    
    # Sigma threshold. This is the estimated standard deviation of the
	# measurement. A low value means that the accuracy is good. Reducing
	# this threshold reduces the max ranging distance, but it reduces the
	# number of false-positives.
    def set_sigma_threshold(self, sigma_thresh_mm):
        if(sigma_thresh_mm > 16383):
            raise RuntimeError("Invalid sigma threshold value")
        
        self.write(RANGE_CONFIG_SIGMA_THRESH, struct.pack(">H", sigma_thresh_mm << 2))
    
    def get_sigma_threshold(self):
        sigma_mm = int.from_bytes(self.read(RANGE_CONFIG_SIGMA_THRESH, 2), "big")
        sigma_mm = sigma_mm >> 2

        return sigma_mm

    # Signal threshold. This is the quantity of photons measured by the
	# sensor. A high value means that the accuracy is good. Increasing
	# this threshold reduces the max ranging distance, but it reduces the
	# number of false-positives.
    def set_signal_threshold(self, signal_kcps):
        if((signal_kcps < 1) or (signal_kcps > 16384)):
            raise RuntimeError("Invalid signal threshold value")
        
        self.write(MIN_COUNT_RATE_RTN_LIMIT_MCPS, struct.pack(">H", signal_kcps >> 3))

    def get_signal_threshold(self):
        signal_kcps = int.from_bytes(self.read(MIN_COUNT_RATE_RTN_LIMIT_MCPS, 2), "big")
        signal_kcps = signal_kcps << 3

        return signal_kcps

    def get_result_range_status(self):
        range_status = int.from_bytes(self.read(RESULT_RANGE_STATUS), "big")
        range_status = range_status & 0x1F
        if (range_status < 24):
            return self.status_rtn[range_status]
        return range_status
    
    def get_result_spad_nb(self):
        return int.from_bytes(self.read(RESULT_SPAD_NB, 2), "big") / 256
    
    def get_result_signal_rate(self):
        return int.from_bytes(self.read(RESULT_SIGNAL_RATE, 2), "big") * 8
    
    def get_result_ambient_rate(self):
        return int.from_bytes(self.read(RESULT_AMBIENT_RATE, 2), "big") * 8
    
    def get_result_sigma(self):
        return int.from_bytes(self.read(RESULT_SIGMA, 2), "big") / 4
    
    def get_result_distance(self):
        return int.from_bytes(self.read(RESULT_DISTANCE, 2), "big")

    def dump_debug_data(self):
        p_measurement_status = self.get_result_range_status()
        p_estimated_distance_mm = self.get_result_distance()
        p_signal_kcps = self.get_result_signal_rate()
        p_sigma_mm = self.get_result_sigma()
        p_ambient_kcps = self.get_result_ambient_rate()

        print("-------------------DEBUG DATA -----------------")
        print("p_measurement_status:    {}".format(p_measurement_status))
        print("p_estimated_distance_mm: {}".format(p_estimated_distance_mm))
        print("p_signal_kcps:           {}".format(p_signal_kcps))
        print("p_sigma_mm:              {}".format(p_sigma_mm))
        print("p_ambient_kcps:          {}".format(p_ambient_kcps))
        print("-----------------------------------------------")

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

    def debug_print(self, msg):
        if self.debug:
            print("{}: {}".format(self.i2c_address, msg))