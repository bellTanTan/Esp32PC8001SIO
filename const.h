/*
  Created by tan (trinity09181718@gmail.com)
  Copyright (c) 2022 tan
  All rights reserved.

* Please contact trinity09181718@gmail.com if you need a commercial license.
* This software is available under GPL v3.
 */

#define SIO_TXD           17    // TXD(SD) OUT : GPIO17
#define SIO_RXD           16    // RXD(RD) IN  : GPIO16
#define SIO_RTS           4     // RTS(RS) OUT : GPIO4
#define SIO_CTS           5     // CTS(CS) IN  : GPIO5
#define BME280_I2C_ADRS   0x76

#define SOH               0x01
#define STX               0x02
#define EOT               0x04
#define ACK               0x06
#define LF                0x0A
#define CR                0x0D
#define NAK               0x15
#define CAN               0x18
#define ESC               0x1B

#define FTP_DIR           "work/pc-8001/media"
//#define DEBUG

#define ESP32_PC8001SIO_VERSION_MAJOR     1
#define ESP32_PC8001SIO_VERSION_MINOR     0
#define ESP32_PC8001SIO_VERSION_REVISION  0

const char * ssid     = "test001";
const char * password = "password001";

const char * ntpServer       = "192.168.1.250";
const long gmtOffsetSec      = 3600 * 9;
const int  daylightOffsetSec = 0;

const IPAddress ip( 192, 168, 1, 101 );     // for fixed IP Address
const IPAddress gateway( 192, 168, 1, 1 );  // gateway
const IPAddress subnet( 255, 255, 255, 0 ); // subnet mask
const IPAddress DNS( 192, 168, 1, 1 );      // DNS

const char * ftpServer = "192.168.1.240";
const char * ftpUser   = "pi";
const char * ftpPass   = "pi";

const char * telnetServer = "192.168.1.240";
const int telnetPort      = 23;
