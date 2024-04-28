import esp32

import .sensor-manager show PIN-MASK

deep-sleep:
  esp32.enable-external-wakeup PIN-MASK false
  esp32.deep-sleep (Duration --h=12)

extract-pins value-> List:
  pins := []
  21.repeat:
    if value & (1 << it) != 0:
      pins.add it
  return pins