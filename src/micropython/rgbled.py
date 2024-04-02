from machine import Pin, PWM

class RGBLED:
    def __init__(self):
        self.red_pin = Pin(14, Pin.OUT)
        self.green_pin = Pin(13, Pin.OUT)
        self.blue_pin = Pin(12, Pin.OUT)

        self.red_pwm = PWM(self.red_pin, freq=2050)
        self.green_pwm = PWM(self.green_pin, freq=2050)
        self.blue_pwm = PWM(self.blue_pin, freq=2050)

        self.red_ = 1.0
        self.green_ = 1.0
        self.blue_ = 1.0
        self.brightness_ = 1.0

    def set_color(self, red, green, blue):
        assert 0 <= red <= 255
        assert 0 <= green <= 255
        assert 0 <= blue <= 255

        self.red_ = red / 255.0
        self.green_ = green / 255.0
        self.blue_ = blue / 255.0
        self.apply_color()

    def apply_color(self):
        self.red_pwm.duty(int((1.0 - self.red_ * self.brightness_) * 1023))
        self.green_pwm.duty(int((1.0 - self.green_ * self.brightness_) * 1023))
        self.blue_pwm.duty(int((1.0 - self.blue_ * self.brightness_) * 1023))

    def set_brightness(self, brightness):
        assert 0 <= brightness <= 100
        self.brightness_ = brightness / 100.0
        self.apply_color()

    def red(self):
        self.set_color(255, 0, 0)

    def green(self):
        self.set_color(0, 255, 0)

    def blue(self):
        self.set_color(0, 0, 255)

    def white(self):
        self.set_color(255, 255, 255)

    def pink(self):
        self.set_color(255, 0, 255)

    def lila(self):
        self.set_color(125, 68, 255)

    def cyan(self):
        self.set_color(0, 255, 255)

    def yellow(self):
        self.set_color(255, 255, 0)

    def off(self):
        self.set_color(0, 0, 0)