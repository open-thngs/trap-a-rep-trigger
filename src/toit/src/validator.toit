import system.firmware

main:
  print "hello after update"

  if firmware.is-validation-pending:
    if firmware.validate:
      print "firmware update validated"
    else:
      print "firmware update failed to validate"