with Ada.Text_IO;   use Ada.Text_IO;
with Ada.Real_Time; use Ada.Real_Time;

with System;

with Webots_API; use Webots_API;

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

   type EventID is (Forward, Stop, Continue, LeftTurn, RightTurn); -- events

   protected CommonData is
      procedure Set (V : EventID);
      function Get return EventID;
   private
      -- Data goes here
      Shared_Data : EventID := Forward;
   end CommonData;

   protected body CommonData is
      procedure Set (V : EventID) is
      begin
         Shared_Data := V;
      end Set;
      -- functions cannot modify the data
      function Get return EventID is
      begin
         return Shared_Data;
      end Get;
   end CommonData;

   task MotorControlTask is
   end MotorControlTask;

   task body MotorControlTask is
      MotorCommand : EventID;
      Stopped      : Boolean := False;
      Motor_Speed  : Integer := 700;

   begin
      loop
         -- Read driving command from shared data
         MotorCommand := CommonData.Get;
         if Stopped and (MotorCommand = Continue) then
            Stopped := False;
         end if;
         if not Stopped then
            case MotorCommand is
               when Continue =>
                  null;
               when Stop =>
                  Set_Motor_Speed (RightMotor, 0);
                  Set_Motor_Speed (LeftMotor, 0);
                  Stopped := True;
               when Forward =>

                  Set_Motor_Speed (RightMotor, Motor_Speed);
                  Set_Motor_Speed (LeftMotor, Motor_Speed);
               when LeftTurn =>
                  Set_Motor_Speed (RightMotor, Motor_Speed);
                  Set_Motor_Speed (LeftMotor, 0);
               when RightTurn =>
                  Set_Motor_Speed (RightMotor, 0);
                  Set_Motor_Speed (LeftMotor, Motor_Speed);
                  delay 0.1;
            end case;
         end if;
      end loop;
   end MotorControlTask;

   task LineFollowingTask is
   end LineFollowingTask;

   task body LineFollowingTask is
      SetCommand           : EventID;
      Light_Sensor_1_State : Integer := 0;
      Light_Sensor_2_State : Integer := 0;
      Light_Sensor_3_State : Integer := 0;

   begin
      loop
         declare
            Light_Sensor_1_State : Integer :=
              webots_API.read_light_sensor (LS1);
            Light_Sensor_2_State : Integer :=
              webots_API.read_light_sensor (LS2);
            Light_Sensor_3_State : Integer :=
              webots_API.read_light_sensor (LS3);
         begin
            -- If LS1 goes on White trun Right
            if Light_Sensor_1_State > 800 then
               CommonData.Set (RightTurn);
               -- IF LS2 is on Black Keep going Forward
            elsif Light_Sensor_2_State > 300 then
               CommonData.Set (Forward);
               -- If LS3 goes on White trun Right
            elsif Light_Sensor_3_State > 800 then
               CommonData.Set (LeftTurn);
            end if;
         end;
         delay 0.1;
      end loop;
   end LineFollowingTask;

   task DistanceTask is
   end DistanceTask;

   task body DistanceTask is
      SetCommand : EventID;
      Distance   : Integer;
   begin
      loop
         Distance := webots_API.read_distance_sensor;
         if Distance > 100 then
            CommonData.Set (Stop);
         else
            CommonData.Set (Continue);
         end if;
         delay 0.1;
      end loop;
   end DistanceTask;

   task DisplayTask is
   end DisplayTask;

   task body DisplayTask is
   begin
      loop
         Put_Line ("Distance:" & Integer'Image (webots_API.read_distance_sensor));
         Put_Line ("LS1:" & Integer'Image (webots_API.read_light_sensor (LS1)));
         Put_Line ("LS2:" & Integer'Image (webots_API.read_light_sensor (LS2)));
         Put_Line ("LS3:" & Integer'Image (webots_API.read_light_sensor (LS3)));
         delay 0.1;
      end loop;

   end DisplayTask;

   -- Background procedure required for package
   procedure Background is
   begin
      while not simulation_stopped loop
         delay 0.25;
      end loop;
   end Background;

end Tasks;
