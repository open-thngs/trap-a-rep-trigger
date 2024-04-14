import gpio
import esp32

import .trigger as trigger
import .ble.ble as ble-app
import .app as app

main:
  if esp32.wakeup-cause == esp32.WAKEUP-EXT1:
    spawn:: trigger.main
  else:
    spawn:: app.main
    
    ble-pin := gpio.Pin.in 9
    if ble-pin.get == 1:
      spawn:: ble-app.main true
    ble-pin.close
    