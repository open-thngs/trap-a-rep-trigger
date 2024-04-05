interface TestCase:
  run -> none

assertEquals expected/any actual/any msg/string="Test OK":
  result := expected == actual
  if result:
    print msg
    return
  else: 
    throw "Expected value $expected != actual value $actual" 

assertTrue actual/any msg/string="Test OK":
  result := true == actual
  if result:
    print msg
    return
  else: 
    throw "Expected value true != actual value $actual" 

assertFalse actual/any msg/string="Test OK":
  result := false == actual
  if result:
    print msg
    return
  else: 
    throw "Expected value false != actual value $actual" 

assertException exception/any:
  if exception: 
    return
  else: 
    throw "Expected exception was not thrown"   