import system.services

interface ApiService:
  static SELECTOR ::= services.ServiceSelector
      --uuid="c5323ebe-02d2-45d3-b7a6-25f24c1f98e9" //Custom UUID
      --major=0
      --minor=1

  on-trigger -> services.ServiceResource
  static ON-TRIGGER-INDEX ::= 0

  on-calibrate -> services.ServiceResource
  static ON-CALIBRATE-INDEX ::= 1

  on-calibrate-xtalk -> services.ServiceResource
  static ON-CALIBRATE-XTALK-INDEX ::= 2

  on-stop -> services.ServiceResource
  static ON-STOP-INDEX ::= 3