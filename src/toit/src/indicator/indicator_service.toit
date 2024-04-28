import system.services
import .color show Color

interface IndicatorService:
  static SELECTOR ::= services.ServiceSelector
      --uuid="8484482c-6db5-41a8-855b-21ce4d903472" //Custom UUID
      --major=0
      --minor=1

  set-color color/Color -> none
  static COLOR-INDEX ::= 0