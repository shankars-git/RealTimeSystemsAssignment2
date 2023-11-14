with Ada.Real_Time;       use Ada.Real_Time;
-- Add required sensor and actuator package --

package Tasks is
  procedure Background;
private

  --  Define periods and times  --
  Period_Display : Time_Span := Milliseconds(100); 
  Time_Zero      : Time := Clock;
      
  --  Other specifications  --

end Tasks;
