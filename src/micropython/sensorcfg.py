import json
from micropython import const

FILENAME = const("sensorcfg.json")
READ = const("r")
WRITE = const("w")

def save_sensor_data(sensordata):
    try:
      with open(FILENAME, WRITE) as f:
          json.dump(sensordata, f)
      print("Sensor data saved to file.")
    except:
      print("Error saving sensor data to file.")

def get_sensor_data():
    try:
      with open(FILENAME, READ) as f:
          return json.load(f)
    except:
      print("Error loading sensor data from file.")
    return None
    
class SensorCfg:
   sensorcfgs = []

   def set_sensor(self, name, offset, xtalk):
      self.sensorcfgs.append({"name": name, "offset": offset, "xtalk": xtalk})

   def get_sensor(self, name):
      for sensor in self.sensorcfgs:
         if sensor["name"] == name:
            return sensor
      return None

   def save(self):
      print("Saving sensor data: {}".format(self.sensorcfgs))
      save_sensor_data(self.sensorcfgs)

   def load(self):
      self.sensorcfgs = get_sensor_data()
      print("Loaded sensor data: {}".format(self.sensorcfgs))
      if self.sensorcfgs is None:
         self.sensorcfgs = []
         return False
      return True
   
   def clear(self):
      self.sensorcfgs = []
      save_sensor_data(self.sensorcfgs)