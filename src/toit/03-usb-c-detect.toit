import gpio
import esp32

main: 
  usb-detect := gpio.Pin 9 --input=true

  while true:
    usb-detect.wait-for 0
    print "USB disconnected"
    usb-detect.wait-for 1
    print "USB connected"
   