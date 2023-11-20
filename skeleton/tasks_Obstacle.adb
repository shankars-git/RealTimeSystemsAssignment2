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
    loop
      -- read sensors and print (have a look at webots_api.ads) ----
      Next_Time := Next_Time + Period_Display;
      delay until Next_Time;

      exit when simulation_stopped;
    end loop;
  end HelloworldTask;

   type EventID is ( UpPressed , DownPressed , LeftPressed, RightPressed, LightSensor2,UpReleased, DownReleased ,LeftReleased,RightReleased,LightSensor2Off); -- events      
   
   protected CommonData is
      procedure Set (V : Integer );
      function Get return Integer ;
      private
      -- Data goes here
         Shared_Data : Integer := 0;
   end CommonData;

   protected body CommonData is
      procedure Set ( V : Integer ) is
      begin
         Shared_Data := V ;
      end Set ;
      -- functions cannot modify the data
      function Get return Integer is
      begin
         return Shared_Data ;
      end Get ;
   end CommonData ;

    task MotorControlTask is
   end MotorControlTask;

   task body MotorControlTask is
      MotorCommand: Integer;
         begin
            loop
            -- Read driving command from shared data
            MotorCommand := CommonData.Get;

            -- Add  implementation here

            delay 0.1; 
            end loop;
   end MotorControlTask;

  task LineFollowingTask is
   end LineFollowingTask;

   task body LineFollowingTask is
   SetCommand: Integer;
   begin
      loop
         -- Read Light sensors Data and update the Steering command in Shared Data
         CommonData.Set(SetCommand);

         delay 0.1;
      end loop;
   end LineFollowingTask;

     task DistanceTask is
   end DistanceTask;

   task body DistanceTask is
   SetCommand: Integer;
   begin
      loop
         -- Read Distance sensors Data and update the Steering command in Shared Data
         CommonData.Set(SetCommand);
         delay 0.1;
      end loop;
   end DistanceTask;

  task DisplayTask is
   end DisplayTask;

   task body DisplayTask is
   begin
      null;
   end DisplayTask;

  -- Background procedure required for package
  procedure Background is begin
    while not simulation_stopped loop
      delay 0.25;
    end loop;
  end Background;

end Tasks;
