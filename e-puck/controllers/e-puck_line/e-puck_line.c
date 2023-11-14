#include <math.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <time.h>
#include <stdint.h>

#include <assert.h>

#include <webots/distance_sensor.h>
#include <webots/led.h>
#include <webots/light_sensor.h>
#include <webots/motor.h>
#include <webots/robot.h>

#include <webots/keyboard.h>

#ifdef _WIN32
#include <winsock2.h>
#include <winsock.h>
#else
#include <arpa/inet.h>  /* definition of inet_ntoa */
#include <netdb.h>      /* definition of gethostbyname */
#include <netinet/in.h> /* definition of struct sockaddr_in */
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h> /* definition of close */
#endif

#define SOCKET_PORT 10020
#define NB_IR_SENSOR 8
#define TIMESTEP 1

// Global defines
#define TRUE 1
#define FALSE 0
#define NO_SIDE -1
#define LEFT 0
#define RIGHT 1
#define WHITE 0
#define BLACK 1
#define SIMULATION 0  // for wb_robot_get_mode() function
#define REALITY 2     // for wb_robot_get_mode() function
#define TIME_STEP 32  // [ms]

// 8 IR proximity sensors
#define NB_DIST_SENS 8
#define PS_RIGHT_00 0
#define PS_RIGHT_45 1
#define PS_RIGHT_90 2
#define PS_RIGHT_REAR 3
#define PS_LEFT_REAR 4
#define PS_LEFT_90 5
#define PS_LEFT_45 6
#define PS_LEFT_00 7
WbDeviceTag ps[NB_DIST_SENS]; /* proximity sensors */
int ps_value[NB_DIST_SENS] = {0, 0, 0, 0, 0, 0, 0, 0};
const int PS_OFFSET_SIMULATION[NB_DIST_SENS] = {300, 300, 300, 300, 300, 300, 300, 300};
// *** TO BE ADAPTED TO YOUR ROBOT ***
const int PS_OFFSET_REALITY[NB_DIST_SENS] = {480, 170, 320, 500, 600, 680, 210, 640};

// 3 IR ground color sensors
#define NB_GROUND_SENS 3
#define GS_WHITE 900
#define GS_LEFT 0
#define GS_CENTER 1
#define GS_RIGHT 2
WbDeviceTag gs[NB_GROUND_SENS]; /* ground sensors */
unsigned short gs_value[NB_GROUND_SENS] = {0, 0, 0};

// Motors
WbDeviceTag left_motor, right_motor;

// LEDs
#define NB_LEDS 8
WbDeviceTag led[NB_LEDS];

/* Debugging */
#include <stdarg.h>
// comment out the following line to disable dprintf
//#define DEBUG_PRINT
void debugPrintf(const char *format, ...){
  #ifdef DEBUG_PRINT
  va_list args;
  va_start(args, format);
  vprintf(format,args);
  va_end(args);
  #endif
}

/* TCP/IP Stuff */
static int fd;
static fd_set rfds;

static int accept_client(int server_fd) {
  int cfd;
  struct sockaddr_in client;
#ifndef _WIN32
  socklen_t asize;
#else
  int asize;
#endif
  struct hostent *client_info;

  asize = sizeof(struct sockaddr_in);

  cfd = accept(server_fd, (struct sockaddr *)&client, &asize);
  if (cfd == -1) {
    printf("cannot accept client\n");
    return -1;
  }
  client_info = gethostbyname((char *)inet_ntoa(client.sin_addr));
  printf("Accepted connection from: %s \n", client_info->h_name);

  return cfd;
}

static int create_socket_server(int port) {
  int sfd, rc;
  struct sockaddr_in address;

#ifdef _WIN32
  /* initialize the socket api */
  WSADATA info;

  rc = WSAStartup(MAKEWORD(1, 1), &info); /* Winsock 1.1 */
  if (rc != 0) {
    printf("cannot initialize Winsock\n");
    return -1;
  }
#endif
  /* create the socket */
  sfd = socket(AF_INET, SOCK_STREAM, 0);
  if (sfd == -1) {
    printf("cannot create socket\n");
    return -1;
  }

  /* fill in socket address */
  memset(&address, 0, sizeof(struct sockaddr_in));
  address.sin_family = AF_INET;
  address.sin_port = htons((unsigned short)port);
  address.sin_addr.s_addr = INADDR_ANY;

  /* bind to port */
  rc = bind(sfd, (struct sockaddr *)&address, sizeof(struct sockaddr));
  if (rc == -1) {
    printf("cannot bind port %d\n", port);
#ifdef _WIN32
    closesocket(sfd);
#else
    close(sfd);
#endif
    return -1;
  }

  /* listen for connections */
  if (listen(sfd, 1) == -1) {
    printf("cannot listen for connections\n");
#ifdef _WIN32
    closesocket(sfd);
#else
    close(sfd);
#endif
    return -1;
  }
  printf("Waiting for a connection on port %d...\n", port);

  return accept_client(sfd);
}

/* Code that communicates with Ada side */
// Defines (currently not checked)
#define ADA_TX_LENGTH 44
#define ADA_RX_LENGTH 44
#define ADA_TX_HEADER 43
#define ADA_RX_HEADER 42

// Message structure
typedef struct package {
  uint32_t sim_time;   // only used in tx packages
  uint8_t sim_stopped; // only used in tx packages
  uint8_t up_button_pressed;
  uint8_t down_button_pressed;
  uint8_t left_button_pressed;
  uint8_t right_button_pressed;
  int32_t data[8];
}package;

// byte pack/unpack (little_endian)
inline int32_t pack_le(char c0, char c1, char c2, char c3) {
    return (((uint8_t)c3) << 24) | ((uint8_t)c2 << 16) |
    ((uint8_t)c1 << 8) | (uint8_t)c0;
}

void unpack_int_le(int32_t data, char* c) {
    c[3] = data >> 24;
    c[2] = (data >> 16) & 0xff;
    c[1] = (data >> 8) & 0xff;
    c[0] = data & 0xff;
}

void unpack_uint_le(uint32_t data, char* c) {
    c[3] = data >> 24;
    c[2] = (data >> 16) & 0xff;
    c[1] = (data >> 8) & 0xff;
    c[0] = data & 0xff;
}

// parses the buffer received from Ada (into the package)
// currently header & length are not checked, but possibly
// can be used to align messages if communication is shaky.
void parse_rcv_bufffer(char* in, package* out) {
  // byte #   name
  //   1      length
  //   2      header
  //   3-4    unused_1_2
  //   5-8    unused 3-6
  //   9-12   sim_time
  //   13-16  data1
  //   ...
  //   41-44  data8
  int offset = 8; // sim_time
  out->sim_time = pack_le(in[offset], in[offset+1], in[offset+2], in[offset+3]);
  offset = 12; // data1
  for (int i = 0; i < 8; ++i){
    out->data[i] = pack_le(in[offset], in[offset+1], in[offset+2], in[offset+3]);
    offset += 4;
  }
}

// prepares the buffer to be sent to Ada (from the package)
void prep_tx_buffer(package* in, char* out) {
  // byte #   name
  //   1      length
  //   2      header
  //   3      sim_stopped
  //   4      unused
  //   5-8    up/down/left/right button presses
  //   9-12   sim_time
  //   13-16  data1
  //   ...
  //   41-44  data8
  out[0] = ADA_TX_LENGTH; // tx length
  out[1] = ADA_TX_HEADER; // tx header
  out[2] = in->sim_stopped;
  out[3] = 0;             // unused
  out[4] = in->up_button_pressed;
  out[5] = in->down_button_pressed;
  out[6] = in->left_button_pressed;
  out[7] = in->right_button_pressed;

  unpack_uint_le(in->sim_time, &out[8]);
  for (int i = 0; i < 8; ++i){
    unpack_int_le(in->data[i], &out[12+i*4]);
  }
}

//------------------------------------------------------------------------------
//
//    CONTROLLER
//
//------------------------------------------------------------------------------
////////////////////////////////////////////
// Simulation step function
void run(void){
  int ps_offset[NB_DIST_SENS] = {0, 0, 0, 0, 0, 0, 0, 0};
  int n;
  char buffer[256];
  package from_ada, to_ada; //data received from / sent to Ada
  float newLeftSpeed, newRightSpeed;
  float motorMaxVelocity = wb_motor_get_max_velocity(left_motor);
  int status;
  // assuming right motor has same max velocity

  to_ada.sim_time = 0;
  while(1) {  // Main loop
    // blocking wait (can make last argument NULL to make it non-blocking)
    n = recv(fd, buffer, ADA_RX_LENGTH, MSG_WAITALL);
    if (n < 0) {
      debugPrintf("error reading from socket\n");
      return;
    }

    debugPrintf("Received %d bytes:\n", n);
    for(int i = 0; i < n; ++i){
      debugPrintf("%d ", buffer[i]);
    }
    debugPrintf("\nReceived data:\n");
    parse_rcv_bufffer(buffer, &from_ada);

    for(int i = 0; i < 8; ++i) {
      debugPrintf("%d ", from_ada.data[i]);
    }

    // read sensors, update motors and step the simulator

    // update motor commands
    float range = 1000.0;
    newLeftSpeed = ((float)from_ada.data[0])/range*motorMaxVelocity;
    newRightSpeed = ((float)from_ada.data[1])/range*motorMaxVelocity;

    debugPrintf("Left raw: %d", from_ada.data[0]);
    debugPrintf("Motor max velocity: %f\n", motorMaxVelocity);
    debugPrintf("New left motor speed: %f\n", newLeftSpeed);
    debugPrintf("New right motor speed: %f\n", newRightSpeed);

    wb_motor_set_velocity(left_motor, newLeftSpeed);
    wb_motor_set_velocity(right_motor, newRightSpeed);

    // run the simulation
    status = wb_robot_step(1);

    // read updated sensor values
    // this reads all distance sensors (8 of them)
    // we can maybe initially use only one (the one
    // int the front) to implement stopping if there is an obstacle
    // which we can add ourselves while the simulation is running
      for (int i = 0; i < NB_DIST_SENS; i++)
        ps_value[i] = (((int)wb_distance_sensor_get_value(ps[i]) - ps_offset[i]) < 0) ?
                        0 :
                        ((int)wb_distance_sensor_get_value(ps[i]) - ps_offset[i]);
      // gs_value holds the three (optional) ground sensors in front of e-puck
      // we can pass 1 or more of these values to ada
      // in the lego lab, we only used 1 sensor
      for (int i = 0; i < NB_GROUND_SENS; i++)
        gs_value[i] = wb_distance_sensor_get_value(gs[i]);

      // send simulation time in milliseconds
      to_ada.sim_time = (uint32_t)(wb_robot_get_time()*1000);

      // send all 3 ground sensor readings
      for(int i = 0; i < 3; ++i) {
        to_ada.data[i] = gs_value[i];
      }

      // fill the rest with distance sensor readings
      for(int i = 3; i < 8; ++i) {
        to_ada.data[i] = ps_value[i-3];
      }
      
      to_ada.sim_stopped = status == -1;
      
      to_ada.up_button_pressed = 0;
      to_ada.down_button_pressed = 0;
      to_ada.left_button_pressed = 0;
      to_ada.right_button_pressed = 0;
      
      int cur_key = wb_keyboard_get_key();
      while(cur_key != -1) {
        switch(cur_key) {
          case WB_KEYBOARD_UP:
            to_ada.up_button_pressed = 1;
            break;
          case WB_KEYBOARD_DOWN:
            to_ada.down_button_pressed = 1;
            break;
          case WB_KEYBOARD_LEFT:
            to_ada.left_button_pressed = 1;
            break;
          case WB_KEYBOARD_RIGHT:
            to_ada.right_button_pressed = 1;
            break;
          default:
            break; // other key presses are ignored;
        }
        cur_key = wb_keyboard_get_key();
      }
            
      prep_tx_buffer(&to_ada, buffer);

      debugPrintf("tx buffer\n");
      for(int i = 0; i < ADA_TX_LENGTH; ++i){
        debugPrintf("%d ", buffer[i]);
      }
      debugPrintf("\n");
    send(fd, buffer, ADA_TX_LENGTH, 0);
    if(status == -1) // simulation stopped or reset
      return;
  }
}

////////////////////////////////////////////
// Main
int main() {
  int i;//, speed[2]//, ps_offset[NB_DIST_SENS] = {0, 0, 0, 0, 0, 0, 0, 0}, Mode = 1;

  /* intialize Webots */
  wb_robot_init();

  /* initialization */
  char name[20];
  for (i = 0; i < NB_LEDS; i++) {
    sprintf(name, "led%d", i);
    led[i] = wb_robot_get_device(name); /* get a handler to the sensor */
  }
  for (i = 0; i < NB_DIST_SENS; i++) {
    sprintf(name, "ps%d", i);
    ps[i] = wb_robot_get_device(name); /* proximity sensors */
    wb_distance_sensor_enable(ps[i], TIME_STEP);
  }
  for (i = 0; i < NB_GROUND_SENS; i++) {
    sprintf(name, "gs%d", i);
    gs[i] = wb_robot_get_device(name); /* ground sensors */
    wb_distance_sensor_enable(gs[i], TIME_STEP);
  }
  // motors
  left_motor = wb_robot_get_device("left wheel motor");
  right_motor = wb_robot_get_device("right wheel motor");
  wb_motor_set_position(left_motor, INFINITY);
  wb_motor_set_position(right_motor, INFINITY);
  wb_motor_set_velocity(left_motor, 0.0);
  wb_motor_set_velocity(right_motor, 0.0);

  wb_keyboard_enable(10); // read keyboud inputs every 10 ms

  printf("Robot has been initialized by Webots.\n");
  fd = create_socket_server(SOCKET_PORT);
  FD_ZERO(&rfds);
    FD_SET(fd, &rfds);

  run();
  
  wb_keyboard_disable();
  
  #ifdef _WIN32
    closesocket(fd);
  #else
    close(fd);
  #endif

  wb_robot_cleanup();
  //never returns
  return 0;
}
