mpremote connect COM19 cp app2.py :/app.py
mpremote connect COM19 cp sensorcfg.py :/sensorcfg.py
mpremote connect COM19 cp vl53l4cd.py :/vl53l4cd.py
mpremote connect COM19 cp vl53l4cd_driver.py :/vl53l4cd_driver.py
mpremote connect COM19 cp constants.py :/constants.py
mpremote connect COM19 cp config.py :/config.py
mpremote connect COM19 cp statistics.py :/statistics.py
mpremote connect COM19 cp rgbled.py :/rgbled.py
mpremote connect COM19 cp calibrator.py :/calibrator.py

putty -load "COM19"