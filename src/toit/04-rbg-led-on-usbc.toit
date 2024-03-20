import gpio
import esp32

main: 
  r := gpio.Pin 14 --output=true 
  g := gpio.Pin 13 --output=true 
  b := gpio.Pin 12 --output=true
  r.set 1
  g.set 1
  b.set 1

  usb-detect := gpio.Pin 9 --input=true

  while true:
    usb-detect.wait-for 0
    print "USB disconnected"
    r.set 0
    g.set 1
    b.set 1

    usb-detect.wait-for 1
    print "USB connected"
    r.set 1
    g.set 0
    b.set 1

   