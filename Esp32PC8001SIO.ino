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

Generating file date and time update information for spiffs files
--------------------------------------------------------------------------------
UNIX & *BSD & linux & Macintosh(Mac OS X later)
$ ls -lan --time-style="+%Y-%m-%d %H:%M:%S" > fileDateTimeList.txt

Windows
C:>forfiles /c "cmd /c echo @fsize @fdate @ftime @file" > fileDateTimeList.txt
--------------------------------------------------------------------------------

* Please contact trinity09181718@gmail.com if you need a commercial license.
* This software is available under GPL v3.
 */

#include "Esp32PC8001SIO.h"
#include "const.h"

Adafruit_BME280 bme;
Adafruit_Sensor * bmeTemp;
Adafruit_Sensor * bmePressure;
Adafruit_Sensor * bmeHumidity;

ESP32_FTPClient ftp( (char *)ftpServer, (char *)ftpUser, (char *)ftpPass );
String  ftpList[128];

WiFiClient  telnetClient;
int         selectFileListNo;
bool        fileListFtpFlag;
int         fileListCount;
PFILELIST   pFileList;
int         spiffsDirListCount;
PDIRLIST    pSpiffsDirList;
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
  Serial2.begin( SIO_BPS, SERIAL_8N1, SIO_RXD, SIO_TXD );
  if ( SIO_RTS != -1 && SIO_CTS != -1 )
  {
    uint8_t threshold = ( SOC_UART_FIFO_LEN / 3 ) * 2;
    Serial2.setHwFlowCtrlMode( HW_FLOWCTRL_CTS_RTS, threshold );
    Serial2.setPins( SIO_RXD, SIO_TXD, SIO_CTS, SIO_RTS );
  }
  while ( !Serial2 && !Serial2.available() );
  Serial.printf( "\r\nboot\r\nSDK %s\r\n", ESP.getSdkVersion() );
  Serial.printf( "serial2 GPIO TXD(%d) RXD(%d) RTS(%d) CTS(%d) %dbps 8N1(8bit/non-parity/stop bit1)\r\n",
                 SIO_TXD, SIO_RXD, SIO_RTS, SIO_CTS, SIO_BPS );

  spiffsDirListCount = 0;
  pSpiffsDirList     = NULL;
  binBuf             = NULL;
  if ( !getSpiffsFileList() )
  {
    Serial.printf( "spiffs file datetime update failed\r\n" );
    HLT;
  }

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

  getLocalTime();
  dumpSpiffsFileList();

  selectFileListNo   = 0;
  fileListFtpFlag    = false;
  fileListCount      = 0;
  pFileList          = NULL;
  ftpFileBufSize     = 0;
  ftpFileBuf         = NULL;
  binBufSize         = 0;
  binBufOffset       = 0;
  bmeGetOldSec       = -1;
  xmodemSeqNo        = 0;
  xmodemBlockNo      = 0;
  telnetSeqNo        = 0;
  sioSendCmd         = cmdNon;
  sioRecvCmd         = cmdNon;
  sioSendBufPos      = 0;
  sioSendBufByte     = 0;
  sioRecvBufByte     = 0;
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
