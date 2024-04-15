import esp32

import .sensor-manager show PIN-MASK

deep-sleep:
  esp32.enable-external-wakeup PIN-MASK false
  esp32.deep-sleep (Duration --m=1)