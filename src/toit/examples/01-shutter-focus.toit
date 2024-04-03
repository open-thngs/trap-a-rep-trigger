import gpio
import esp32

main: 
  autofocus := gpio.Pin 10 --output=true
  shutter := gpio.Pin 11 --output=true

  while true:
    print "autofocus on"
    autofocus.set 1
    sleep --ms=500
    print "shutter on"
    shutter.set 1
    sleep --ms=2000
    print "autofocus off"
    autofocus.set 0
    print "shutter off"
    shutter.set 0

    print "sleeping"
    sleep --ms=5000

  // esp32.deep-sleep (Duration --ms=5000)