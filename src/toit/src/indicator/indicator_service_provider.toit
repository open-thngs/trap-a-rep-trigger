import system.services show ServiceProvider ServiceResource ServiceHandler
import .indicator_service
import .color show Color

class IndicatorServiceProvider extends ServiceProvider implements ServiceHandler:
  color-handler/Lambda? := null

  constructor:
    super "indicator" --major=1 --minor=0
    provides IndicatorService.SELECTOR --handler=this

  handle index/int arguments/any --gid/int --client/int -> any:
    if index == IndicatorService.COLOR-INDEX:
      return set-color (Color arguments[0])
    else:
      return null
    unreachable

  set-color color/Color:
    color-handler.call color

  set-color-handler handler/Lambda:
    color-handler = handler

class IndicatorSubscriptionResource extends ServiceResource:
  provider/IndicatorServiceProvider

  constructor .provider/IndicatorServiceProvider client/int:
    super provider client --notifiable

  on_closed -> none:
    //provider.unsubscribe this

