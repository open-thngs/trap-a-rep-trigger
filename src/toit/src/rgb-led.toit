import gpio show Pin
import gpio.pwm show Pwm PwmChannel

import .indicator.color show Color

class RGBLED:
  
  red-pin/Pin := ?
  green-pin/Pin := ?
  blue-pin/Pin := ?

  red_channel/PwmChannel := ?
  green_channel/PwmChannel := ?
  blue_channel/PwmChannel := ?

  red_/float := 1.0
  green_/float := 1.0
  blue_/float := 1.0
  brightness_/float := 1.0

  constructor r=14 g=13 b=12:
    generator := Pwm --frequency=2050
    red-pin = Pin r --output=true 
    green-pin = Pin g --output=true
    blue-pin = Pin b --output=true
    red_channel = generator.start red-pin
    green_channel = generator.start green-pin
    blue_channel = generator.start blue-pin

  set-color color/Color:
    red_ = color.color[0] / 255.0
    green_ = color.color[1] / 255.0
    blue_ = color.color[2] / 255.0
    apply-color

  set-color red/int green/int blue/int:
    assert: 0 <= red <= 255
    assert: 0 <= green <= 255
    assert: 0 <= blue <= 255

    red_ = red / 255.0
    green_ = green / 255.0
    blue_ = blue / 255.0
    apply-color

  apply-color:
    red_channel.set-duty-factor 1.0 - (red_ * brightness_)
    green_channel.set-duty-factor 1.0 - (green_ * brightness_)
    blue_channel.set-duty-factor 1.0 - (blue_ * brightness_)

  set-brightness brightness/int:
    assert: 0 <= brightness <= 100
    brightness_ = brightness / 100.0
    apply-color

  close:
    red_channel.close
    green_channel.close
    blue_channel.close
    red-pin.close
    green-pin.close
    blue-pin.close
    
  red:
    set-color 255 0 0
  
  green:
    set-color 0 255 0

  blue:
    set-color 0 0 255

  white:
    set-color 255 255 255

  pink:
    set-color 255 0 255

  lila:
    set-color 125 68 255

  cyan:
    set-color 0 255 255

  yellow:
    set-color 255 200 0

  off:
    set-color 0 0 0
  
