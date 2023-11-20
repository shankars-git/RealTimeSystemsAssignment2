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


  protected Event is
      entry Wait (id : out EventID );
      procedure Signal (id : in EventID );
  private
      -- assign priority that is ceiling of the
      -- user tasks ' priorities
      current_id : EventID ; -- event data
      signalled : Boolean := false ; -- flag for event signal
  end Event ;
  protected body Event is
      entry Wait (id : out EventID ) when Signalled is
      begin
          id := current_id ;
          signalled := false ;
      end Wait ;
      procedure Signal (id : in EventID ) is
      begin
          current_id := id;
          signalled := true ;
      end Signal ;
   end Event;

    task MotorControlTask is
   end MotorControlTask;

task body MotorControlTask is
   Count_Variable : Integer :=0;
   Motor_Speed : Integer :=500;
begin
   loop
      -- Waiting for an event
      declare
         Current_Event : EventID;
      begin
         Event.Wait(Current_Event);
         delay 0.1;
         ---Based on Event_ID Set The Motors speed and Direction
         case Current_Event is
            when UpPressed =>
               Set_Motor_Speed(RightMotor, Motor_Speed);
               Set_Motor_Speed(LeftMotor,  Motor_Speed);
            when DownPressed =>
               Set_Motor_Speed(RightMotor, -Motor_Speed);
               Set_Motor_Speed(LeftMotor,  -Motor_Speed);
            when LeftPressed =>
               Set_Motor_Speed(RightMotor, Motor_Speed);
               Set_Motor_Speed(LeftMotor, -Motor_Speed);
            when RightPressed =>
               Set_Motor_Speed(RightMotor, -Motor_Speed);
               Set_Motor_Speed(LeftMotor, Motor_Speed);
            when LightSensor2 =>
                Set_Motor_Speed(RightMotor, -Motor_Speed);
                  Set_Motor_Speed(LeftMotor,  +Motor_Speed);
             when UpReleased | DownReleased | LeftReleased | RightReleased  =>
               -- Stop the motors for other events
               Set_Motor_Speed(RightMotor, 0);
               Set_Motor_Speed(LeftMotor, 0);
            when LightSensor2Off =>
             --Set_Motor_Speed(RightMotor, 0);
             --Set_Motor_Speed(LeftMotor,  0);
               Put_Line("Hi");              
         end case;
      end;
   end loop;
end MotorControlTask;
    task EventDispatcherTask is
    end EventDispatcherTask;

   task body EventDispatcherTask is
      -- Variable to Hold Previous Button Press state
      Previous_Button_Press_State_Up : Boolean := False;
      Previous_Button_Press_State_Down : Boolean := False;
      Previous_Button_Press_State_Left : Boolean := False;
      Previous_Button_Press_State_Right : Boolean := False;
      Previous_Light_Sensor_2_State : Integer := 0;

      -- Event ID's
      UpButtonPressed : constant EventID := UpPressed;
      DownButtonPressed : constant EventID := DownPressed;
      LeftButtonPressed : constant EventID := LeftPressed;
      RightButtonPressed : constant EventID := RightPressed;
      UpButtonReleased : constant EventID := UpReleased;
      DownButtonReleased : constant EventID := DownReleased;
      LeftButtonReleased: constant EventID := LeftReleased;
      RightButtonReleased : constant EventID := RightReleased;
      LightSensorTwoActive : constant EventID := LightSensor2;
      LightSensorTwoInActive : constant EventID := LightSensor2Off;
      Minor_Delay    : constant Duration := 0.1;
   begin
      loop
         -- Call  Webots API function to read  the button press from Keyboard
         declare
            Present_Button_Pressed_Up : Boolean := Webots_API.button_pressed(UpButton);
            Present_Button_Pressed_Down : Boolean := Webots_API.button_pressed(DownButton);
            Present_Button_Pressed_Left : Boolean := Webots_API.button_pressed(LeftButton);
            Present_Button_Pressed_Right : Boolean := Webots_API.button_pressed(RightButton);
            Present_Light_Sensor_2_State : Integer := webots_API.read_light_sensor(LS2);
         begin
            -- Compare the Present state with the Previous state
            if Present_Button_Pressed_Up /= Previous_Button_Press_State_Up then
               -- State has changed, release the event
               if Present_Button_Pressed_Up then
                  Event.Signal(UpButtonPressed);
                  Put_Line("Up Pressed");
               else
                  Event.Signal(UpButtonReleased);
                  Put_Line("Up Released");
               end if;
               Previous_Button_Press_State_Up := Present_Button_Pressed_Up;
            end if;
            if Present_Button_Pressed_Down /= Previous_Button_Press_State_Down then
               -- State has changed, release the event
               if Present_Button_Pressed_Down then
                  Event.Signal(DownButtonPressed);
                  Put_Line("Down Pressed");
               else
                  Event.Signal(DownButtonReleased);
                  Put_Line("Down Released");
               end if;
               Previous_Button_Press_State_Down := Present_Button_Pressed_Down;
            end if;
            if Present_Button_Pressed_Left /= Previous_Button_Press_State_Left then
               -- State has changed, release the event
               if Present_Button_Pressed_Left then
                  Event.Signal(LeftButtonPressed);
                  Put_Line("Left Pressed");
               else
                  Event.Signal(LeftButtonReleased);
                  Put_Line("Left Released");
               end if;
               Previous_Button_Press_State_Left := Present_Button_Pressed_Left;
            end if;
            if Present_Button_Pressed_Right /= Previous_Button_Press_State_Right then
               -- State has changed, release the event
               if Present_Button_Pressed_Right then
                  Event.Signal(RightButtonPressed);
                  Put_Line("Right Pressed");
               else
                  Event.Signal(RightButtonReleased);
                  Put_Line("Right Released");
               end if;
               Previous_Button_Press_State_Right := Present_Button_Pressed_Right;
            end if;
          -- if Present_Light_Sensor_2_State /= Previous_Light_Sensor_2_State then
           if Present_Light_Sensor_2_State < 300  and Present_Light_Sensor_2_State > 0 then
               Event.Signal(LightSensorTwoActive);
               Put_Line("LS2 Is on Black , Stop the Bot");
               Put_Line(Integer'Image(Present_Light_Sensor_2_State));
            elsif Present_Light_Sensor_2_State > 800 then
               Event.Signal(LightSensorTwoInActive);
               Put_Line("LS2 is Not on Black");
               --Put_Line(Integer'Image(Present_Light_Sensor_2_State));
            --else
              -- Put_Line("LS2 No state Change");
            end if;
            --Previous_Light_Sensor_2_State := Present_Light_Sensor_2_State;
         --end if;
         end;
         delay Minor_Delay;
        end loop;
   end EventDispatcherTask;

  -- Background procedure required for package
  procedure Background is begin
    while not simulation_stopped loop
      delay 0.25;
    end loop;
  end Background;

end Tasks;
