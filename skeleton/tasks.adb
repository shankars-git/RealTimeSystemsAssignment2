with Ada.Text_IO;    use Ada.Text_IO;
with Ada.Real_Time;  use Ada.Real_Time;
with System;

with Webots_API;   use Webots_API;

package body Tasks is
  -------------
  --  Tasks  --
  -------------   
  task HelloworldTask is
    -- define its priority higher than the main procedure --
    -- main procedure priority is declared at main.adb:9
  end HelloworldTask;

  task body HelloworldTask is
    Next_Time : Time := Time_Zero;

  begin      
    -- task body starts here ---

    loop
      -- read sensors and print (have a look at webots_api.ads) ----

      Next_Time := Next_Time + Period_Display;
      delay until Next_Time;

      exit when simulation_stopped;
    end loop;
  end HelloworldTask;

  -- Background procedure required for package
  procedure Background is begin
    while not simulation_stopped loop
      delay 0.25;
    end loop;
  end Background;

end Tasks;
