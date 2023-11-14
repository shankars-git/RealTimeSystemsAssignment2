with Tasks;
with System;
with Ada.Real_Time;  use Ada.Real_Time;

with Webots_API;     use Webots_API;

procedure main is

  pragma Priority (System.Priority'First);

  -- do not modify below task, it syncs with Webots
  task SyncTask is
    entry start;
    pragma Priority (System.Priority'Last);
  end SyncTask;
  task body SyncTask is
    NextTime : Time := Clock;
    Period   : Time_Span := Milliseconds(1);
  begin
    WebotsSync.start;
    WebotsSync.sync;
    accept start;
    loop
      --Ada.Text_IO.Put_Line("synctask @" & SimTime'Image);
      WebotsSync.sync;
      exit when simulation_stopped;
      NextTime := NextTime + Period;
      delay until NextTime;
    end loop;
  end SyncTask;

begin
  SyncTask.start;
  Tasks.Background;

end main;
