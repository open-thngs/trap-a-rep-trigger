import gpio 

trigger:
  exception := catch:
    shutter := gpio.Pin 11 --output=true
    focus := gpio.Pin 10 --output=true

    focus.set 1
    sleep --ms=2
    shutter.set 1
    sleep --ms=250
    print "Camera has been triggered"
    shutter.set 0
    focus.set 0
    shutter.close
    focus.close
  if exception:
    print "Ignored trigger"