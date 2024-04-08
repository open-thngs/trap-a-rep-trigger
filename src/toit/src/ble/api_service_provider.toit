import system.services show ServiceProvider ServiceResource ServiceHandler
import .api_service

class ApiServiceProvider extends ServiceProvider implements ServiceHandler:
  on-trigger/ApiSubscriptionResource? := null
  on-calibrate/ApiSubscriptionResource? := null

  constructor:
    super "api" --major=1 --minor=0
    provides ApiService.SELECTOR --handler=this

  handle index/int arguments/any --gid/int --client/int -> any:
    if index == ApiService.ON-TRIGGER-INDEX:
      on-trigger = ApiSubscriptionResource this client
      return on-trigger
    if index == ApiService.ON-CALIBRATE-INDEX:
      on-calibrate = ApiSubscriptionResource this client
      return on-calibrate
    unreachable

  trigger:
    on-trigger.notify_ null

  calibrate:
    on-calibrate.notify_ null

class ApiSubscriptionResource extends ServiceResource:
  provider/ApiServiceProvider

  constructor .provider/ApiServiceProvider client/int:
    super provider client --notifiable

  on_closed -> none:
    //provider.unsubscribe this

