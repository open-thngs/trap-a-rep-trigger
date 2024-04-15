import system.services show ServiceClient ServiceSelector ServiceResourceProxy
import .api_service

class ApiClient extends ServiceClient:
  static SELECTOR ::= ApiService.SELECTOR
  constructor selector/ServiceSelector=SELECTOR:
    assert: selector.matches SELECTOR
    super selector

  set-on-trigger-callback callback/Lambda -> none:
    handle := invoke_ ApiService.ON-TRIGGER-INDEX []
    ApiSubscription this handle callback

  set-on-calibrate-callback callback/Lambda -> none:
    handle := invoke_ ApiService.ON-CALIBRATE-INDEX []
    ApiSubscription this handle callback

  set-on-calibrate-xtalk-callback callback/Lambda -> none:
    handle := invoke_ ApiService.ON-CALIBRATE-XTALK-INDEX []
    ApiSubscription this handle callback

  set-on-stop-callback callback/Lambda -> none:
    handle := invoke_ ApiService.ON-STOP-INDEX []
    ApiSubscription this handle callback

  set-device-status status/ByteArray -> none:
    invoke_ ApiService.DEVICE-STATUS-INDEX [status]

class ApiSubscription extends ServiceResourceProxy:
  callback/Lambda
  constructor client/ApiClient handle/int .callback:
    super client handle

  on_notified_ notification/any -> none:
    callback.call notification