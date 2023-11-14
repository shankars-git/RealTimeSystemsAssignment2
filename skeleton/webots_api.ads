package Webots_API is
  
  task WebotsSync is
    entry start; -- initialisation of the sync task
    entry sync;  -- syncs data with Webots
  end WebotsSync;
  
  type MotorID is (LeftMotor, RightMotor);
  type LightSensorID is (LS1, LS2, LS3); -- ground facing light sensors
  type ButtonID is (UpButton, DownButton, LeftButton, RightButton);
  procedure set_motor_speed(id : MotorID; value : Integer);
  function read_light_sensor(id : LightSensorID) return Integer;
  function read_distance_sensor                  return Integer;
  function simulation_stopped                    return Boolean;
  function button_pressed(id : ButtonID)         return Boolean;
  function simulation_time                       return Integer;

end Webots_API;
