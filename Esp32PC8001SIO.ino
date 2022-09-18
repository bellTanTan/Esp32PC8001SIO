/*
  Created by tan (trinity09181718@gmail.com)
  Copyright (c) 2022 tan
  All rights reserved.

  Arduino IDE board : Arduino ESP32 v2.0.5
  library           : ESP32 FTPClient v0.1.4
                    : Adafruit BME280 v2.2.2
  target            : ESP32 DEV Module
  flash size        : 4MB(32Mb)
  partition scheme  : No OTA (1MB APP/3MB SPIFFS)
  PSRAM             : Disabled

ESP32 FTPClient v0.1.4 patch
--------------------------------------------------------------------------------
--- ESP32_FTPClient.cpp.org  2021-04-03 19:13:14.998750540 +0900
+++ ESP32_FTPClient.cpp 2021-04-03 19:15:46.931344537 +0900
@@ -305,7 +305,8 @@
     if( _b < 128 )
     {
       String tmp = dclient.readStringUntil('\n');
-      list[_b] = tmp.substring(tmp.lastIndexOf(" ") + 1, tmp.length());
+      list[_b] = tmp;
+      //list[_b] = tmp.substring(tmp.lastIndexOf(" ") + 1, tmp.length());
       //FTPdbgn(String(_b) + ":" + tmp);
       _b++;
     }
--------------------------------------------------------------------------------

* Please contact trinity09181718@gmail.com if you need a commercial license.
* This software is available under GPL v3.
 */

#include <Arduino.h>
#include <sys/time.h>
#include <Wire.h>
#include <WiFi.h>
#include <WiFiClient.h>
#include <Adafruit_BME280.h>
#include <ESP32_FTPClient.h>
#include "const.h"

#define ARRAY_SIZE( array )     ( (int)( sizeof( array ) / sizeof( (array)[0] ) ) )
#define HLT                     { while ( 1 ) { delay( 500 ); } }

enum SIOCMD {
  cmdNon = 0,
  cmdVer,
  cmdSntp,
  cmdBme,
  cmdFtpList,
  cmdList,
  cmdFtpGet,
  cmdTelnet,
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

Adafruit_BME280 bme;
Adafruit_Sensor * bmeTemp;
Adafruit_Sensor * bmePressure;
Adafruit_Sensor * bmeHumidity;

ESP32_FTPClient ftp( (char *)ftpServer, (char *)ftpUser, (char *)ftpPass );
String  ftpList[128];

WiFiClient  telnetClient;
int         selectFileListNo;
int         fileListCount;
PFILELIST   pFileList;
int         ftpFileBufSize;
uint8_t *   ftpFileBuf;
int         binBufSize;
int         binBufOffset;
uint8_t *   binBuf;
time_t      timeNow;
struct tm * localTime;
BME280DATA  bme280SampleData[60];
BME280DATA  bme280Data;
int         bmeGetOldSec;
int         xmodemSeqNo;
uint8_t     xmodemBlockNo;
int         xmodemSendBytes;
time_t      xmodemTimer;
int         telnetSeqNo;
int         termWidth;
int         termHeigh;
SIOCMD      sioSendCmd;
SIOCMD      sioRecvCmd;
int         sioSendBufPos;
int         sioSendBufByte;
int         sioRecvBufByte;
int         sioRecvRingBufReadPos;
int         sioRecvRingBufWritePos;
char        sioSendBuf[128+16];
char        sioRecvBuf[128+16];
char        sioRecvRingBuf[128+16];


void initApp( void )
{
  Serial.begin( 115200 );
  while (!Serial && !Serial.available());
  Serial2.begin( 4800, SERIAL_8N1, SIO_RXD, SIO_TXD );
  uint8_t threshold = ( SOC_UART_FIFO_LEN / 3 ) * 2;
  Serial2.setHwFlowCtrlMode( HW_FLOWCTRL_CTS_RTS, threshold );
  Serial2.setPins( SIO_RXD, SIO_TXD, SIO_CTS, SIO_RTS );
  while ( !Serial2 && !Serial2.available() );
  Serial.printf( "\r\nboot\r\nSDK %s\r\n", ESP.getSdkVersion() );

  Serial.printf( "init bme280\r\n" );
  if ( !bme.begin( BME280_I2C_ADRS ) )
  {
    Serial.printf( "bme280 not found\r\n" );
    HLT;
  }
  bmeTemp     = bme.getTemperatureSensor();
  bmePressure = bme.getPressureSensor();
  bmeHumidity = bme.getHumiditySensor();
  bmeTemp->printSensorDetails();
  bmePressure->printSensorDetails();
  bmeHumidity->printSensorDetails();
  sensors_event_t tempEvent, pressureEvent, humidityEvent;
  bmeTemp->getEvent( &tempEvent );
  bmePressure->getEvent( &pressureEvent );
  bmeHumidity->getEvent( &humidityEvent );
  BME280DATA bme280;
  bme280.temp  = tempEvent.temperature;
  bme280.hum   = humidityEvent.relative_humidity;
  bme280.press = pressureEvent.pressure;
  for ( int i = 0; i < ARRAY_SIZE( bme280SampleData ); i++ )
  {
    bme280SampleData[i].temp  = bme280.temp;
    bme280SampleData[i].hum   = bme280.hum;
    bme280SampleData[i].press = bme280.press;
  }

  WiFi.disconnect();
  WiFi.softAPdisconnect( true );
  WiFi.mode( WIFI_STA );
  WiFi.config( ip, gateway, subnet, DNS );
  delay( 10 );
  Serial.printf( "connecting %s ", ssid );
  WiFi.begin( ssid, password );
  int count = 0;
  while ( WiFi.status() != WL_CONNECTED )
  {
    if ( count > 10 )
    {
      Serial.printf( "connection failed\r\n" );
      HLT;
    }
    delay( 500 );
    Serial.print( "." );
    count++;
  }
  Serial.printf( "connected\r\n" );
  Serial.printf( "ip address: %s\r\n",WiFi.localIP().toString().c_str() );

  Serial.printf( "contacting time server\r\n" );
  configTime( gmtOffsetSec, daylightOffsetSec, ntpServer );
  struct tm tm;
  memset( &tm, 0, sizeof( tm ) );
  getLocalTime( &tm, 10 * 1000 );
  Serial.printf( "date: %d/%02d/%02d %02d:%02d:%02d\r\n",
                 tm.tm_year+1900, tm.tm_mon+1, tm.tm_mday,
                 tm.tm_hour, tm.tm_min, tm.tm_sec );

  selectFileListNo = 0;
  fileListCount    = 0;
  pFileList        = NULL;
  ftpFileBufSize   = 0;
  ftpFileBuf       = NULL;
  binBufSize       = 0;
  binBufOffset     = 0;
  binBuf           = NULL;
  bmeGetOldSec     = -1;
  xmodemSeqNo      = 0;
  xmodemBlockNo    = 0;
  telnetSeqNo      = 0;
  sioSendCmd       = cmdNon;
  sioRecvCmd       = cmdNon;
  sioSendBufPos    = 0;
  sioSendBufByte   = 0;
  sioRecvBufByte   = 0;
  sioRecvRingBufReadPos  = 0;
  sioRecvRingBufWritePos = 0;
  memset( sioSendBuf,     0, sizeof( sioSendBuf ) );
  memset( sioRecvBuf,     0, sizeof( sioRecvBuf ) );
  memset( sioRecvRingBuf, 0, sizeof( sioRecvRingBuf ) );
  Serial.printf( "pc8001sio v%d.%d.%d ready\r\n",
                 ESP32_PC8001SIO_VERSION_MAJOR,
                 ESP32_PC8001SIO_VERSION_MINOR,
                 ESP32_PC8001SIO_VERSION_REVISION );
}

void getLocalTime( void )
{
  timeNow   = time( NULL );
  localTime = localtime( &timeNow );
}

void bme280Main( void )
{
  if ( bmeGetOldSec == localTime->tm_sec )
    return;
  bmeGetOldSec = localTime->tm_sec;
  sensors_event_t tempEvent;
  sensors_event_t pressureEvent;
  sensors_event_t humidityEvent;
  bmeTemp->getEvent( &tempEvent );
  bmePressure->getEvent( &pressureEvent );
  bmeHumidity->getEvent( &humidityEvent );
  int pos = ( localTime->tm_sec % ARRAY_SIZE( bme280SampleData ) );
  bme280SampleData[pos].temp  = tempEvent.temperature;
  bme280SampleData[pos].hum   = humidityEvent.relative_humidity;
  bme280SampleData[pos].press = pressureEvent.pressure;
  bme280Data.temp  = 0;
  bme280Data.hum   = 0;
  bme280Data.press = 0;
  for ( int i = 0; i < ARRAY_SIZE( bme280SampleData ); i++ )
  {
    bme280Data.temp  += bme280SampleData[i].temp;
    bme280Data.hum   += bme280SampleData[i].hum;
    bme280Data.press += bme280SampleData[i].press;
  }
  bme280Data.temp  /= ARRAY_SIZE( bme280SampleData );
  bme280Data.hum   /= ARRAY_SIZE( bme280SampleData );
  bme280Data.press /= ARRAY_SIZE( bme280SampleData );
}

void sioXmodemSendMain( void )
{
  switch ( xmodemSeqNo )
  {
    case 0:
      if ( sioRecvCmd == cmdNak )
      {
        sioRecvCmd      = cmdNon;
        xmodemSeqNo     = 10;
        xmodemBlockNo   = 1;
        xmodemSendBytes = binBufSize;
        binBufOffset    = 0;
      }
      break;
    case 10:
      xmodemTimer = timeNow;
      if ( xmodemSendBytes == 0 )
      {
        sioSendCmd = cmdEot;
        sioSendBuf[0] = EOT;
      }
      else
      {
        sioSendCmd = cmdPacket;
        memset( sioSendBuf, 0x1A, 4 + 128 );
        sioSendBuf[0] = SOH;
        sioSendBuf[1] = xmodemBlockNo;
        sioSendBuf[2] = ~sioSendBuf[1];
        sioSendBufByte = 128;
        if ( xmodemSendBytes < 128 )
          sioSendBufByte = xmodemSendBytes;
        memcpy( &sioSendBuf[3], &binBuf[binBufOffset], sioSendBufByte );
        uint8_t checkSum = 0;
        for ( int i = 0; i < ( 3 + 128 ); i++ )
          checkSum += sioSendBuf[i];
        sioSendBuf[3+128] = checkSum;
      }
      xmodemSeqNo = 20;
      break;
    case 20:
      if ( ( timeNow - xmodemTimer ) >= 60 )
        xmodemSeqNo = 0;
      else
      {
        if ( sioRecvCmd == cmdAck )
        {
          sioRecvCmd = cmdNon;
          if ( xmodemSendBytes == 0 )
            xmodemSeqNo = 0;
          else
          {
            xmodemSendBytes -= sioSendBufByte;
            binBufOffset    += sioSendBufByte;
            xmodemBlockNo++;
            xmodemSeqNo = 10;
          }
        }
        if ( sioRecvCmd == cmdNak )
        {
          sioRecvCmd = cmdNon;
          sioSendCmd = cmdPacket;
        }
        if ( sioRecvCmd == cmdCan )
        {
          sioRecvCmd = cmdNon;
          xmodemSeqNo = 0;
        }
      }
      break;
    default:
      break;
  }
}

void sioTelnetMain( void )
{
  switch ( telnetSeqNo )
  {
    case 0:
      // idle
      break;
    case 10:
      if ( sioSendCmd != cmdNon )
        break;
      if ( !telnetClient.connected() )
      {
        sprintf( sioSendBuf,"\r\nConnection closed by foreign host.\r\n%c%c", ESC, 0xFF );
        sioSendBufPos  = 0;
        sioSendBufByte = strlen( sioSendBuf );
        telnetSeqNo = 20;
        break;
      }
      while ( true )
      {
        if ( !telnetClient.available() )
          break;
        uint8_t recvData = telnetClient.read();
        Serial2.write( recvData );
      }
      break;
    case 20:
      while ( true )
      {
        if ( sioSendBufPos >= sioSendBufByte )
        {
          telnetSeqNo = 0;
          break;
        }
        uint8_t sendData = sioSendBuf[sioSendBufPos];
        Serial2.write( sendData );
        sioSendBufPos++;
      }
      break;
    default:
      break;
  }
}

void sioSendMain( void )
{
  if ( sioSendCmd == cmdNon )
    return;
  int pos = 0;
  while ( true )
  {
    uint8_t sendData = sioSendBuf[pos];
    pos++;
    if ( sioSendCmd == cmdEot )
    {
      if ( pos > 1 )
        break;
    }
    if ( sioSendCmd == cmdPacket )
    {
      if ( pos > ( 4 + 128 ) )
        break;   
    }
    else
    {
      if ( sendData == 0 )
        break;
    }
    Serial2.write( sendData );
  }
  sioSendCmd = cmdNon;
}

void addFileList( const char * pFtpFileList )
{
  if ( !pFileList )
  {
    size_t memsize = sizeof( *pFileList );
    pFileList = (PFILELIST)malloc( memsize );
  }
  else
  {
    size_t memsize = sizeof( *pFileList ) * ( fileListCount + 1 );
    pFileList = (PFILELIST)realloc( (void *)pFileList, memsize );
  }
  if ( !pFileList )
    return;
  //           1         2         3         4         5         9
  // 01234567890123456789012345678901234567890123456789012345678901234567890
  // -rw-rw-r--    1 1000     1000         1372 Jul 17 17:48 3BY4BAS.bin
  // -rw-r--r--    1 1000     1000         4413 Jan 27  1991 PCG Space Mouse Part2 {mon L}.cmt
  char szDelimiter[16];
  sprintf( szDelimiter, " %c%c", CR, LF );
  char * p = strtok( (char *)pFtpFileList, szDelimiter );
  size_t n = 0;
  int item = 0;
  while( p )
  {
    switch ( item )
    {
      case 0:
        n = sizeof( pFileList[0].szPermission ) - 1;
        strncpy( pFileList[fileListCount].szPermission, p, n );
        break;
      case 4:
        n = sizeof( pFileList[0].szSize ) - 1;
        strncpy( pFileList[fileListCount].szSize, p, n );
        break;
      case 5:
        n = sizeof( pFileList[0].szDateTime ) - 1;
        strncpy( pFileList[fileListCount].szDateTime, p, n );
        break;
      case 6:
      case 7:
        {
          n = sizeof( pFileList[0].szDateTime );
          int srcLen = 1 + strlen( p );
          int desLen = n - ( 1 + strlen( pFileList[fileListCount].szDateTime ) );
          if ( desLen > srcLen )
          {
            if ( item == 6 || ( item == 7 && strchr( p, ':' ) ) )
            {
              strcat( pFileList[fileListCount].szDateTime, " " );
              strcat( pFileList[fileListCount].szDateTime, p );
            }
            else
            {
              strcat( pFileList[fileListCount].szDateTime, "  " );
              strcat( pFileList[fileListCount].szDateTime, p );
            }
          }
        }
        break;
      case 8:
        n = sizeof( pFileList[0].szName ) - 1;
        strncpy( pFileList[fileListCount].szName, p, n );
        break;        
      default:
        if ( item > 8 )
        {
          n = sizeof( pFileList[0].szName );
          int srcLen = 1 + strlen( p );
          int desLen = n - ( 1 + strlen( pFileList[fileListCount].szName ) );
          if ( desLen > srcLen )
          {
            strcat( pFileList[fileListCount].szName, " " );
            strcat( pFileList[fileListCount].szName, p );
          }
        }
        break;
    }
    p = strtok( NULL, szDelimiter );
    item++;
  }
  fileListCount++;
}

void sioCmdVer( void )
{
  sioSendCmd = sioRecvCmd;
  sioRecvCmd = cmdNon;
  memset( sioSendBuf, 0, sizeof( sioSendBuf ) );
  sprintf( sioSendBuf, "VER:%d,%d,%d%c%c",
           ESP32_PC8001SIO_VERSION_MAJOR,
           ESP32_PC8001SIO_VERSION_MINOR,
           ESP32_PC8001SIO_VERSION_REVISION,
           CR, LF );
}

void sioCmdSntp( void )
{
  struct timeval t0;
  const int baseTimingMsec = 800;

  gettimeofday( &t0, NULL );
  if ( t0.tv_usec >= ( baseTimingMsec * 1000 )
    && t0.tv_usec <  ( ( baseTimingMsec + 10 ) * 1000 ) )
  {
    t0.tv_sec += 1;
    localTime = localtime( &t0.tv_sec );
    sioSendCmd = sioRecvCmd;
    sioRecvCmd = cmdNon;
    memset( sioSendBuf, 0, sizeof( sioSendBuf ) );
    sprintf( sioSendBuf, "SNTP:%d,%02d,%02d,%02d,%02d,%02d%c%c",
             localTime->tm_year + 1900,
             localTime->tm_mon + 1,
             localTime->tm_mday,
             localTime->tm_hour,
             localTime->tm_min,
             localTime->tm_sec,
             CR, LF );
  }
}

void sioCmdBme( void )
{
  sioSendCmd = sioRecvCmd;
  sioRecvCmd = cmdNon;
  memset( sioSendBuf, 0, sizeof( sioSendBuf ) );
  sprintf( sioSendBuf, "BME:%.1f,%.1f,%.0f%c%c",
           bme280Data.temp,
           bme280Data.hum,
           bme280Data.press,
           CR, LF );
}

void sioCmdFtpList( void )
{
  sioSendCmd = sioRecvCmd;
  sioRecvCmd = cmdNon;
  for ( int i = 0; i < ARRAY_SIZE( ftpList ); i++ )
    ftpList[i] = "";
  ftp.OpenConnection();
  if ( ftp.isConnected() )
  {
    ftp.ChangeWorkDir( FTP_DIR );
    ftp.InitFile( "Type A" );
    ftp.ContentListWithListCommand( "", ftpList );
    ftp.CloseConnection();
  }
  fileListCount = 0;
  int iMaxszSize = 0;
  for ( int i = 0; i < ARRAY_SIZE( ftpList ); i++ )
  {
    if ( ftpList[i].length() > 0 )
    {
      const char *p = ftpList[i].c_str();
      addFileList( p );
      if ( pFileList )
      {
        int len = strlen( pFileList[fileListCount-1].szSize );
        if ( len > iMaxszSize )
        {
          iMaxszSize = len;
        }
      }
    }
  }
  char szFormat[16];
  char szBuf[16];
  sprintf( szFormat, "%%%ds", iMaxszSize );
  for ( int i = 0; i < fileListCount; i++ )
  {
    sprintf( szBuf, szFormat, pFileList[i].szSize );
    strcpy( pFileList[i].szSize, szBuf );
  }
  memset( sioSendBuf, 0, sizeof( sioSendBuf ) );
  sprintf( sioSendBuf, "FTPLIST:%03d%c%c",
           fileListCount,
           CR, LF );
}

void sioCmdList( void )
{
  sioSendCmd = sioRecvCmd;
  sioRecvCmd = cmdNon;
  memset( sioSendBuf, 0, sizeof( sioSendBuf ) );
  sprintf( sioSendBuf, "LIST:%03d,,,,%c%c",
           selectFileListNo,
           CR, LF );
  if ( pFileList && selectFileListNo >= 0 && selectFileListNo < fileListCount )
  {
    memset( sioSendBuf, 0, sizeof( sioSendBuf ) );
    sprintf( sioSendBuf, "LIST:%03d,%s,%s,%s,%s%c%c",
             selectFileListNo,
             pFileList[selectFileListNo].szPermission,
             pFileList[selectFileListNo].szSize,
             pFileList[selectFileListNo].szDateTime,
             pFileList[selectFileListNo].szName,
             CR, LF );
  }
}

uint16_t cmt2bin( int * pDataType )
{
  uint16_t loadAdrs = 0;
  bool fBasCmt = ( ( ftpFileBuf[0] == 0xD3 ) ? true : false );
  bool fMonCmt = ( ( ftpFileBuf[0] == 0x3A ) ? true : false );
  if ( fBasCmt )
  {
    bool fHead = false;
    bool fEnd = false;
    if ( ftpFileBufSize > ( 10 + 6 + 9 ) )
    {
      uint8_t buf[16];
      memset( buf, 0xD3, 10 );
      fHead = ( memcmp( ftpFileBuf, buf, 10 ) == 0 ? true : false );
      memset( buf, 0x00, 9 );
      int p = ftpFileBufSize - 9;
      fEnd = ( memcmp( &ftpFileBuf[p], buf, 9 ) == 0 ? true : false );
    }
    if ( fHead && fEnd )
    {
      binBufSize = ftpFileBufSize - ( 10 + 6 + 8 );
      memcpy( binBuf, &ftpFileBuf[16], binBufSize );
      *pDataType = 2;
    }
  }
  if ( fMonCmt )
  {
    int binBufOffset = 0;
    int ftpFileBufOffset = 0;
    while ( true )
    {
      if ( ftpFileBufOffset >= ftpFileBufSize )
        break;
      if ( ftpFileBuf[ftpFileBufOffset+0] == 0x3A )
        binBufOffset = 0;  
      loadAdrs  = (uint16_t)ftpFileBuf[ftpFileBufOffset+1] << 8;
      loadAdrs |= (uint16_t)ftpFileBuf[ftpFileBufOffset+2];
      ftpFileBufOffset += 4;
      while ( true )
      {
        if ( ftpFileBuf[ftpFileBufOffset+0] == 0x3A
          && ftpFileBuf[ftpFileBufOffset+1] == 0x00
          && ftpFileBuf[ftpFileBufOffset+2] == 0x00 )
        {
          ftpFileBufOffset += 3;
          *pDataType = 3;
          break;
        }
        if ( ftpFileBuf[ftpFileBufOffset+0] == 0x3A )
        {
          uint8_t dataSize = ftpFileBuf[ftpFileBufOffset+1];
          memcpy( &binBuf[binBufOffset], &ftpFileBuf[ftpFileBufOffset+2], dataSize );
          binBufOffset += dataSize;
          ftpFileBufOffset += ( 3 + dataSize );
        }
        else
        {
          ftpFileBufOffset = ftpFileBufSize;
          break;
        }
      }
    }
    if ( *pDataType == 3 )
      binBufSize = binBufOffset;
  }
  return loadAdrs;
}

void sioCmdFtpGet( void )
{
  SIOCMD saveSioRecvCmd = sioRecvCmd;
  if ( !pFileList )
  {
    sioCmdFtpList();
    sioRecvCmd = saveSioRecvCmd;
  }
  sioSendCmd = sioRecvCmd;
  sioRecvCmd = cmdNon;
  memset( sioSendBuf, 0, sizeof( sioSendBuf ) );
  sprintf( sioSendBuf, "FTPGET:%03d,%d,%04X,%04X%c%c",
           selectFileListNo,
           0,
           0,
           0,
           CR, LF );
  if ( pFileList && selectFileListNo >= 0 && selectFileListNo < fileListCount )
  {
    size_t fileSize = atol( pFileList[selectFileListNo].szSize );
    if ( fileSize > 0 )
    {
      if ( !ftpFileBuf )
        ftpFileBuf = (uint8_t *)malloc( fileSize );
      else
        ftpFileBuf = (uint8_t *)realloc( ftpFileBuf, fileSize );
      if ( ftpFileBuf )
      {
        char * fileName = pFileList[selectFileListNo].szName;
        memset( ftpFileBuf, 0, fileSize );
        int result = 0;
        uint16_t loadAdrs = 0;
        ftp.OpenConnection();
        if ( ftp.isConnected() )
        {
          ftp.ChangeWorkDir( FTP_DIR );
          ftp.InitFile( "Type I" );
          ftp.DownloadFile( fileName, ftpFileBuf, fileSize, false );
          ftp.CloseConnection();
          ftpFileBufSize = fileSize;
          binBufSize     = fileSize;
          if ( !binBuf )
            binBuf = (uint8_t *)malloc( binBufSize );
          else
            binBuf = (uint8_t *)realloc( binBuf, binBufSize );
          char * p = strrchr( fileName, '.' );
          if ( binBuf && p )
          {
            binBufOffset = 0;
            result = 1;
            memcpy( binBuf, ftpFileBuf, ftpFileBufSize );
            if ( strcasecmp( p, ".CMT" ) == 0 )
              loadAdrs = cmt2bin( &result );
          }
        }
        memset( sioSendBuf, 0, sizeof( sioSendBuf ) );
        sprintf( sioSendBuf, "FTPGET:%03d,%d,%04X,%04X%c%c",
                 selectFileListNo,
                 result,
                 loadAdrs,
                 loadAdrs + binBufSize - 1,
                 CR, LF );
      }
    }
  }
}

bool telnetNegotiation( void )
{
  uint8_t sendDataByte;
  uint8_t recvDataByte;
  uint8_t sendData[128];
  uint8_t recvData[128];
  bool result = false;

  sendData[0]  = 0xFF;  // IAC
  sendData[1]  = 0xFB;  // WILL
  sendData[2]  = 0x18;  // OPT_TTYPE
  sendData[3]  = 0xFF;  // IAC
  sendData[4]  = 0xFD;  // DO
  sendData[5]  = 0x03;  // OPT_SGA
  sendData[6]  = 0xFF;  // IAC
  sendData[7]  = 0xFB;  // WILL
  sendData[8]  = 0x03;  // OPT_SGA
  sendData[9]  = 0xFF;  // IAC
  sendData[10] = 0xFD;  // DO
  sendData[11] = 0x01;  // OPT_ECHO
  sendData[12] = 0xFF;  // IAC
  sendData[13] = 0xFB;  // WILL
  sendData[14] = 0x1F;  // OPT_NAWS
  sendData[15] = 0xFF;  // IAC
  sendData[16] = 0xFB;  // WILL
  sendData[17] = 0x20;  // OPT_TSPEED
  sendDataByte = 18;
  telnetClient.write( sendData, sendDataByte );

  while ( true )
  {
    time_t timeTimer = time( NULL );
    bool timeup = false;
    while ( true )
    {
      time_t timeNow = time( NULL );
      if ( ( timeNow - timeTimer ) > 60 )
      {
        timeup = true;
        break;
      }
      if ( telnetClient.available() )
        break;
    }
    if ( timeup )
      break;
    recvDataByte = 3;
    telnetClient.read( recvData, recvDataByte );
    if ( recvData[0] != 0xFF )
      break;
    sendDataByte = 0;
    switch ( recvData[1] )
    {
      case 0xFA:  // SB
        switch ( recvData[2] )
        {
          case 0x18:  // OPT_TTYPE
            recvDataByte = 3;
            telnetClient.read( &recvData[3], recvDataByte );
            sendData[0]  = recvData[0];
            sendData[1]  = recvData[1];
            sendData[2]  = recvData[2];
            sendData[3]  = 0x00;
            sendData[4]  = 'V';
            sendData[5]  = 'T';
            sendData[6]  = '1';
            sendData[7]  = '0';
            sendData[8]  = '0';
            sendData[9]  = 0xFF;  // IAC
            sendData[10] = 0xF0;  // SE
            sendDataByte = 11;
            break;
          case 0x20:  // OPT_TSPEED
            recvDataByte = 3;
            telnetClient.read( &recvData[3], recvDataByte );
            sendData[0]  = recvData[0];
            sendData[1]  = recvData[1];
            sendData[2]  = recvData[2];
            sendData[3]  = 0x00;
            sendData[4]  = '1';
            sendData[5]  = '9';
            sendData[6]  = '2';
            sendData[7]  = '0';
            sendData[8]  = '0';
            sendData[9]  = ',';
            sendData[10] = '1';
            sendData[11] = '9';
            sendData[12] = '2';
            sendData[13] = '0';
            sendData[14] = '0';
            sendData[15] = 0xFF;  // IAC
            sendData[16] = 0xF0;  // SE
            sendDataByte = 17;
            break;
        }
        break;
      case 0xFB:  // WILL
        switch ( recvData[2] )
        {
          case 0x05:  // OPT_STATUS
            sendData[0]  = recvData[0];
            sendData[1]  = recvData[1] + 3;  // 0xFE  DONT
            sendData[2]  = recvData[2];
            sendDataByte = 3;
            break;
        }
        break;
      case 0xFD:  // DO
        switch ( recvData[2] )
        {
          case 0x1F:  // OPT_NAWS
            sendData[0]  = recvData[0];
            sendData[1]  = recvData[1] - 3;  // 0xFA  SB
            sendData[2]  = recvData[2];
            sendData[3]  = 0x00;
            sendData[4]  = termWidth;
            sendData[5]  = 0x00;
            sendData[6]  = termHeigh;
            sendData[7]  = 0xFF;  // IAC
            sendData[8]  = 0xF0;  // SE
            sendDataByte = 9;
            break;
          case 0x01:  // OPT_ECHO
          case 0x21:  // OPT_LFLOW
          case 0x23:  // OPT_XDISPLOC
          case 0x27:  // OPT_NEW_ENVIRON
            sendData[0]  = recvData[0];
            sendData[1]  = recvData[1] - 1; // 0xFC   WONT
            sendData[2]  = recvData[2];
            sendDataByte = 3;
            break;
        }
        break;
    }
    if ( sendDataByte > 0 )
    {
      telnetClient.write( sendData, sendDataByte );
      if ( sendData[0] == 0xFF
        && sendData[1] == 0xFC
        && sendData[2] == 0x21 )
      {
        result = true;
        break;
      }
    }
  }
  return result;
}

void sioCmdTelnet( void )
{
  sioSendCmd = sioRecvCmd;
  sioRecvCmd = cmdNon;
  bool result = false;
  if ( telnetClient.connect( telnetServer, telnetPort, 10 * 1000 ) )
    result = telnetNegotiation();
  if ( result )
    telnetSeqNo = 10;
  else
    telnetSeqNo = 0;
  memset( sioSendBuf, 0, sizeof( sioSendBuf ) );
  sprintf( sioSendBuf, "TELNET:%d%c%c",
           result,
           CR, LF );
}

void sioRecvCommand( void )
{
  switch ( (int)sioRecvCmd )
  {
    case cmdVer:
      sioCmdVer();
      break;
    case cmdSntp:
      sioCmdSntp();
      break;
    case cmdBme:
      sioCmdBme();
      break;
    case cmdFtpList:
      sioCmdFtpList();
      break;
    case cmdList:
      sioCmdList();
      break;
    case cmdFtpGet:
      sioCmdFtpGet();
      break;
    case cmdTelnet:
      sioCmdTelnet();
      break;
  }
}

void sioRecvParser( void )
{
  if ( sioRecvRingBufReadPos == sioRecvRingBufWritePos )
    return;
  int pos = sioRecvRingBufReadPos;
  while ( true )
  {
    if ( pos == sioRecvRingBufWritePos )
      break;
    sioRecvBuf[sioRecvBufByte] = sioRecvRingBuf[pos];
    sioRecvBufByte++;
    pos++;
    if ( pos >= ARRAY_SIZE( sioRecvRingBuf ) )
      pos = 0;
  }
  sioRecvRingBufReadPos = pos;
  if ( sioRecvBufByte == 1 )
  {
    switch ( sioRecvBuf[0] )
    {
      case ACK:
        sioRecvCmd = cmdAck;
        break;
      case NAK:
        sioRecvCmd = cmdNak;
        break;
      case CAN:
        sioRecvCmd = cmdCan;
        break;
    }
    sioRecvBufByte = 0;
  }
  if ( xmodemSeqNo == 0 && sioRecvBufByte >= 2 )
  {
    if ( sioRecvBuf[sioRecvBufByte-2] == CR
      && sioRecvBuf[sioRecvBufByte-1] == LF )
    {
      sioRecvBuf[sioRecvBufByte-2] = 0x00;
      char *psioRecvBuf = &sioRecvBuf[0];
      // uPD8251電源ON時のゴミ送出除外
      for ( int i = 0; i < sioRecvBufByte; i++ )
      {
        if ( i != (sioRecvBufByte - 2)
          && sioRecvBuf[i+0] == CR
          && sioRecvBuf[i+1] == LF )
        {
          psioRecvBuf = &sioRecvBuf[i+2];
          break;
        }
      }
      sioRecvCmd = cmdNon;
      if ( strcmp( psioRecvBuf, "VER" ) == 0 )
        sioRecvCmd = cmdVer;
      if ( strcmp( psioRecvBuf, "SNTP" ) == 0 )
        sioRecvCmd = cmdSntp;
      if ( strcmp( psioRecvBuf, "BME" ) == 0 )
        sioRecvCmd = cmdBme;
      if ( strcmp( psioRecvBuf, "FTPLIST" ) == 0 )
        sioRecvCmd = cmdFtpList;
      if ( strncmp( psioRecvBuf, "LIST:", 5 ) == 0 )
      {
        // 01234567 8   9
        // LIST:nnn<CR><LF>
        selectFileListNo = atoi( &psioRecvBuf[5] );
        sioRecvCmd = cmdList;
      }
      if ( strncmp( sioRecvBuf, "FTPGET:", 7 ) == 0 )
      {
        //            1
        // 0123456789 0   1
        // FTPGET:nnn<CR><LF>
        selectFileListNo = atoi( &psioRecvBuf[7] );
        sioRecvCmd = cmdFtpGet;
      }
      if ( strncmp( sioRecvBuf, "TELNET:", 7 ) == 0 )
      {
        //           1
        // 012345678901 2   3
        // TELNET:xx,yy<CR><LF>
        sioRecvBuf[9] = 0x00;
        termWidth = atoi( &psioRecvBuf[7] );
        termHeigh = atoi( &psioRecvBuf[10] );
        sioRecvCmd = cmdTelnet;
      }
      sioRecvBufByte = 0;
    }
  }
}

void sioRecvMain( void )
{
  while ( true )
  {
    if ( !Serial2.available() )
      break;
    uint8_t recvData = Serial2.read();
    if ( telnetSeqNo == 0 )
    {
      sioRecvRingBuf[sioRecvRingBufWritePos] = recvData;
      sioRecvRingBufWritePos++;
      if ( sioRecvRingBufWritePos >= ARRAY_SIZE( sioRecvRingBuf ) )
        sioRecvRingBufWritePos = 0;
    }
    else
    {
      if ( telnetClient.connected() )
        telnetClient.write( recvData );
    }
  }
  sioRecvParser();
  sioRecvCommand();
}

void setup()
{
  initApp();
}

void loop()
{
  getLocalTime();
  bme280Main();
  sioXmodemSendMain();
  sioTelnetMain();
  sioSendMain();
  sioRecvMain();
}
