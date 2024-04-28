import system.services show ServiceClient ServiceSelector ServiceResourceProxy
import .indicator_service
import .color show Color

class IndicatorClient extends ServiceClient:
  static SELECTOR ::= IndicatorService.SELECTOR
  constructor selector/ServiceSelector=SELECTOR:
    assert: selector.matches SELECTOR
    super selector

  set-color color/Color -> none:
    invoke_ IndicatorService.COLOR-INDEX [color.serialize]

class IndicatorSubscription extends ServiceResourceProxy:
  callback/Lambda
  constructor client/IndicatorClient handle/int .callback:
    super client handle

  on_notified_ notification/any -> none:
    callback.call notification