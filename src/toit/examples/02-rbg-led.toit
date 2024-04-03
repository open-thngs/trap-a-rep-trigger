import gpio
import esp32

main: 
  r := gpio.Pin 14 --output=true 
  g := gpio.Pin 13 --output=true 
  b := gpio.Pin 12 --output=true
  r.set 1
  g.set 1
  b.set 1

  while true:
    r.set 0
    g.set 1
    b.set 1
    sleep --ms=1000
    r.set 1
    g.set 0
    b.set 1
    sleep --ms=1000
    r.set 1
    g.set 1
    b.set 0
    sleep --ms=1000
   