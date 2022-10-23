/*
  Created by tan (trinity09181718@gmail.com)
  Copyright (c) 2022 tan
  All rights reserved.

* Please contact trinity09181718@gmail.com if you need a commercial license.
* This software is available under GPL v3.
 */

#pragma once

#pragma GCC optimize ("O2")

#include <Arduino.h>
#include <stdarg.h>
#include <time.h>
#include <utime.h>
#include <sys/time.h>
#include <sys/utime.h>
#include <FS.h>
#include <SPIFFS.h>
#include <Wire.h>
#include <WiFi.h>
#include <WiFiClient.h>
#include <Adafruit_BME280.h>
#include <ESP32_FTPClient.h>
#include "version.h"

#define SIO_TXD           17    // TXD(SD) OUT : GPIO17
#define SIO_RXD           16    // RXD(RD) IN  : GPIO16
#define SIO_RTS           4     // RTS(RS) OUT : GPIO4
#define SIO_CTS           5     // CTS(CS) IN  : GPIO5
#define SIO_BPS           4800  // PC-8001
//#define SIO_BPS           9600  // PC-8001mkII
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

//#define _DEBUG

#define SPIFFS_BASE_PATH                  "/spiffs"
#define SPIFFS_FILE_DATETIME_LIST         "/fileDateTimeList.txt"

#define ARRAY_SIZE( array )     ( (int)( sizeof( array ) / sizeof( (array)[0] ) ) )
#define HLT                     { while ( 1 ) { delay( 500 ); } }

#ifdef _DEBUG
  extern  void _DEBUG_PRINT( const char * format, ... );
#else
  #define _DEBUG_PRINT( format, ... ) { }
#endif // _DEBUG

enum SIOCMD {
  cmdNon = 0,
  cmdVer,
  cmdSntp,
  cmdBme,
  cmdFtpList,
  cmdList,
  cmdFtpGet,
  cmdTelnet,
  cmdSpiffsList,
  cmdSpiffsGet,
  cmdGet,
  cmdEot,
  cmdAck,
  cmdNak,
  cmdCan,
  cmdPacket,
};

typedef struct {
  double  temp;
  double  hum;
  double  press;
} BME280DATA, * PBME280DATA;

typedef struct {
  char  szPermission[16];
  char  szSize[16];
  char  szDateTime[16];
  char  szName[64];
} FILELIST, * PFILELIST;

typedef struct {
  size_t  fileSize;
  time_t  tLastWrite;
  char    szSize[16];
  char    szDateTime[16];
  char *  pszPath;
} DIRLIST , *PDIRLIST;

typedef struct {
  int       dataType;
  uint16_t  startAdrs;
  uint16_t  endAdrs;
  size_t    areaSize;
  uint16_t  execAdrs;
} DIVILIST, *PDIVILIST;

// bme280Job.cpp
extern  void bme280Main( void );

// sioJob.cpp
extern  void sioCmdVer( void );
extern  void sioCmdSntp( void );
extern  void sioCmdBme( void );
extern  void sioCmdFtpList( void );
extern  void sioCmdFtpGet( void );
extern  void sioCmdList( void );
extern  void sioCmdTelnet( void );
extern  void sioCmdSpiffsList( void );
extern  void sioCmdSpiffsGet( void );
extern  void sioCmdGet( void );
extern  void sioSendMain( void );
extern  void sioRecvMain( void );

// sioTelnetJob.cpp
extern  void sioTelnetMain( void );

// sioXmodemJob.cpp
extern  void sioXmodemSendMain( void );

// spiffsJob.cpp
extern  bool getSpiffsFileList( void );
extern  void dumpSpiffsFileList( void );

// etc.cpp
extern  void getLocalTime( void );
extern  void addFileList( const char * pFtpFileList );
extern  bool cmt2bin( void );
extern  bool telnetNegotiation( void );
