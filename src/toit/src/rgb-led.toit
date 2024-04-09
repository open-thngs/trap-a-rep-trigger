import gpio show Pin
import gpio.pwm

class RGBLED:
  
  red_channel := ?
  green_channel := ?
  blue_channel := ?

  red_/float := 1.0
  green_/float := 1.0
  blue_/float := 1.0
  brightness_/float := 1.0

  constructor r=5 g=6 b=7:
    generator := pwm.Pwm --frequency=2050
    red := Pin r --output=true 
    green := Pin g --output=true
    blue := Pin b --output=true
    red_channel = generator.start red
    green_channel = generator.start green
    blue_channel = generator.start blue

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
    red_channel.stop
    green_channel.stop
    blue_channel.stop
    
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
    set-color 255 255 0

  off:
    set-color 0 0 0
  
