with Ada.Streams;  use Ada.Streams;
with GNAT.Sockets; use GNAT.Sockets;
with Interfaces;    use Interfaces;



package body Webots_API is

  Webots_API_Exception : exception;

  type Data_Field is Array (Positive Range <>) of Integer_32;
  type Exchange_Package is record
    size                 : Unsigned_8;
    header               : Unsigned_8;
    simulation_stopped   : Unsigned_8;
    unused               : Unsigned_8;
    up_button_pressed    : Unsigned_8;
    down_button_pressed  : Unsigned_8;
    left_button_pressed  : Unsigned_8;
    right_button_pressed : Unsigned_8;
    simulation_time      : Unsigned_32;
    data                 : Data_Field(1 .. 8); 
  end record;
  
  protected Obj is
    procedure set_motor_speed (id : MotorID; value : Integer);
    function get_light_sensor (id : LightSensorID) return Integer;
    function get_distance_sensor return Integer;
    function get_simulation_stopped return Boolean;
    function get_button_pressed (id : ButtonID) return Boolean;
    function get_simulation_time return Integer;
      
    function get_sent_package return Exchange_Package;
    procedure set_recv_package (p : Exchange_Package);
  private
    sent_package : Exchange_Package := (44,42,0,0,0,0,0,0,0,(0,0,0,0,0,0,0,0));
    recv_package : Exchange_Package;
  end Obj;

  protected body Obj is
    procedure set_motor_speed (id : MotorID; value : Integer) is begin
      case id is
        when LeftMotor  => sent_package.data(1) := Integer_32(value);
        when RightMotor => sent_package.data(2) := Integer_32(value);
        when others => raise Webots_API_Exception with "Not a valid MotorID.";
      end case;
    end set_motor_speed;

    function get_light_sensor  (id : LightSensorID) return Integer is begin
      case id is
        when LS1 => return Integer(recv_package.data(1));
        when LS2 => return Integer(recv_package.data(2));
        when LS3 => return Integer(recv_package.data(3));
        when others => raise Webots_API_Exception with "Not a valid LightSensorID.";
      end case;
    end get_light_sensor;

    function get_distance_sensor return Integer is begin
      return Integer(recv_package.data(4));
    end get_distance_sensor;

    function get_simulation_stopped return Boolean is begin
      return recv_package.simulation_stopped = 1;
    end get_simulation_stopped;

    function get_button_pressed (id : ButtonID) return Boolean is begin
      case id is
        when UpButton => return recv_package.up_button_pressed = 1;
        when DownButton => return recv_package.down_button_pressed = 1;
        when LeftButton => return recv_package.left_button_pressed = 1;
        when RightButton => return recv_package.right_button_pressed = 1;
        when others => raise Webots_API_Exception with "Not a valid ButtonID.";
      end case;
    end get_button_pressed;
      
    function get_simulation_time return Integer is begin
      return Integer(recv_package.simulation_time);
    end get_simulation_time;

    procedure set_recv_package (p : Exchange_Package) is begin
      recv_package := p;
    end set_recv_package;

    function get_sent_package return Exchange_Package is begin
      return sent_package;
    end get_sent_package;

  end Obj;



  task body WebotsSync is
    Client  : Socket_Type;
    Address : Sock_Addr_Type;
    Channel : Stream_Access;
    tx_buffer : Exchange_Package;
    rx_buffer : Exchange_Package;
  begin
    accept start do
      GNAT.Sockets.Initialize;
      Create_Socket (Client);
      Address.Addr := Inet_Addr("127.0.0.1");
      Address.Port := 10020;

      Connect_Socket (Client, Address);
      Channel := Stream (Client);
    end start;
    loop
      accept sync do -- update sent_package before sync as needed
        tx_buffer := Obj.get_sent_package;
        Exchange_Package'Write(Channel, tx_buffer);
        Exchange_Package'Read(Channel,  rx_buffer);
        Obj.set_recv_package(rx_buffer);
      end sync;
      if simulation_stopped then
        Close_Socket (Client);
        exit;
      end if;
    end loop;
  end WebotsSync;

  procedure set_motor_speed(id : MotorID; value : Integer) is begin
    Obj.set_motor_speed(id, value);
  end set_motor_speed;

  function read_light_sensor (id : LightSensorID) return Integer is begin
    return Obj.get_light_sensor(id);
  end read_light_sensor;

  function read_distance_sensor return Integer is begin
    return Obj.get_distance_sensor;
  end read_distance_sensor;

  -- returns true if simulation is reset or reloaded in Webots (not paused)
  function simulation_stopped return Boolean is begin
    return Obj.get_simulation_stopped;
  end simulation_stopped;

  -- returns true if directional up button is pressed in Webots
  function button_pressed (id : ButtonID) return Boolean is begin
    return Obj.get_button_pressed(id);
  end button_pressed;

  function simulation_time return Integer is begin
    return Obj.get_simulation_time;
  end simulation_time;

begin
  null;
end Webots_API;
