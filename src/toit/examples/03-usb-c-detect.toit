import gpio
import esp32

main: 
  usb-detect := gpio.Pin.in 9

  while true:
    usb-detect.wait-for 0
    print "USB disconnected"
    usb-detect.wait-for 1
    print "USB connected"
   