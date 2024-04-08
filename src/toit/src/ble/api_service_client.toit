import system.services show ServiceClient ServiceSelector ServiceResourceProxy
import .api_service

class ApiClient extends ServiceClient:
  static SELECTOR ::= ApiService.SELECTOR
  constructor selector/ServiceSelector=SELECTOR:
    assert: selector.matches SELECTOR
    super selector

  set_on_trigger_callback callback/Lambda -> none:
    handle := invoke_ ApiService.ON-TRIGGER-INDEX []
    ApiSubscription this handle callback

  set_on_calibrate_callback callback/Lambda -> none:
    handle := invoke_ ApiService.ON-CALIBRATE-INDEX []
    ApiSubscription this handle callback

class ApiSubscription extends ServiceResourceProxy:
  callback/Lambda
  constructor client/ApiClient handle/int .callback:
    super client handle

  on_notified_ notification/any -> none:
    callback.call notification