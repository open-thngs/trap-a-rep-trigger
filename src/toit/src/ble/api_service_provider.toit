import system.services show ServiceProvider ServiceResource ServiceHandler
import .api_service

class ApiServiceProvider extends ServiceProvider implements ServiceHandler:
  on-trigger/ApiSubscriptionResource? := null
  on-calibrate/ApiSubscriptionResource? := null
  on-calibrate-xtalk/ApiSubscriptionResource? := null
  on-stop/ApiSubscriptionResource? := null

  constructor:
    super "api" --major=1 --minor=0
    provides ApiService.SELECTOR --handler=this

  handle index/int arguments/any --gid/int --client/int -> any:
    if index == ApiService.ON-TRIGGER-INDEX:
      on-trigger = ApiSubscriptionResource this client
      return on-trigger
    else if index == ApiService.ON-CALIBRATE-INDEX:
      on-calibrate = ApiSubscriptionResource this client
      return on-calibrate
    else if  index == ApiService.ON-CALIBRATE-XTALK-INDEX:
      on-calibrate-xtalk = ApiSubscriptionResource this client
      return on-calibrate-xtalk
    else if index == ApiService.ON-STOP-INDEX:
      on-stop = ApiSubscriptionResource this client
      return on-stop
    else:
      return null
    unreachable

  trigger:
    on-trigger.notify_ null

  calibrate:
    on-calibrate.notify_ null

  calibrate-xtalk:
    on-calibrate-xtalk.notify_ null 

  stop:
    on-stop.notify_ null

class ApiSubscriptionResource extends ServiceResource:
  provider/ApiServiceProvider

  constructor .provider/ApiServiceProvider client/int:
    super provider client --notifiable

  on_closed -> none:
    //provider.unsubscribe this

