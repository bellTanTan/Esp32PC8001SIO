/*
  Created by tan (trinity09181718@gmail.com)
  Copyright (c) 2022 tan
  All rights reserved.

* Please contact trinity09181718@gmail.com if you need a commercial license.
* This software is available under GPL v3.
 */

#include "Esp32PC8001SIO.h"

extern  const char * ftpDir;
extern  const char * telnetServer;
extern  const int telnetPort;

extern  ESP32_FTPClient ftp;
extern  String  ftpList[128];
extern  WiFiClient  telnetClient;
extern  int         selectFileListNo;
extern  bool        fileListFtpFlag;
extern  int         fileListCount;
extern  PFILELIST   pFileList;
extern  int         spiffsDirListCount;
extern  PDIRLIST    pSpiffsDirList;
extern  int         ftpFileBufSize;
extern  uint8_t *   ftpFileBuf;
extern  int         binBufSize;
extern  int         binBufOffset;
extern  uint8_t *   binBuf;
extern  struct tm * localTime;
extern  BME280DATA  bme280Data;
extern  int         xmodemSeqNo;
extern  int         telnetSeqNo;
extern  int         termWidth;
extern  int         termHeigh;
extern  SIOCMD      sioSendCmd;
extern  SIOCMD      sioRecvCmd;
extern  int         sioSendBufPos;
extern  int         sioSendBufByte;
extern  int         sioRecvBufByte;
extern  int         sioRecvRingBufReadPos;
extern  int         sioRecvRingBufWritePos;
extern  char        sioSendBuf[128+16];
extern  char        sioRecvBuf[128+16];
extern  char        sioRecvRingBuf[128+16];


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
    ftp.ChangeWorkDir( ftpDir );
    ftp.InitFile( "Type A" );
    ftp.ContentListWithListCommand( "", ftpList );
    ftp.CloseConnection();
  }
  fileListFtpFlag = true;
  fileListCount   = 0;
  int iMaxszSize  = 0;
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

void sioCmdFtpGet( void )
{
  SIOCMD saveSioRecvCmd = sioRecvCmd;
  if ( !pFileList || fileListFtpFlag == false )
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
          ftp.ChangeWorkDir( ftpDir );
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

void sioCmdSpiffsList( void )
{
  sioSendCmd = sioRecvCmd;
  sioRecvCmd = cmdNon;
  fileListFtpFlag = false;
  fileListCount   = 0;
  int iMaxszSize  = 0;
  for ( int i = 0; i < spiffsDirListCount; i++ )
  {
    char fileInfo[512];
    //           1         2         3         4         5         6
    // 01234567890123456789012345678901234567890123456789012345678901234567890
    // -rw-rw-r--    1 1000     1000         1372 Jul 17 17:48 3BY4BAS.bin
    sprintf( fileInfo,"-rw-rw-rw- 1 1000 1000 %s %s %s",
             pSpiffsDirList[i].szSize,
             pSpiffsDirList[i].szDateTime,
             &pSpiffsDirList[i].pszPath[1] );
    addFileList( fileInfo );
    if ( pFileList )
    {
      int len = strlen( pFileList[fileListCount-1].szSize );
      if ( len > iMaxszSize )
      {
        iMaxszSize = len;
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
  sprintf( sioSendBuf, "SPIFFSLIST:%03d%c%c",
           fileListCount,
           CR, LF );
}

void sioCmdSpiffsGet( void )
{
  SIOCMD saveSioRecvCmd = sioRecvCmd;
  if ( !pFileList || fileListFtpFlag == true )
  {
    sioCmdSpiffsList();
    sioRecvCmd = saveSioRecvCmd;
  }
  sioSendCmd = sioRecvCmd;
  sioRecvCmd = cmdNon;
  memset( sioSendBuf, 0, sizeof( sioSendBuf ) );
  sprintf( sioSendBuf, "SPIFFSGET:%03d,%d,%04X,%04X%c%c",
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
        char szPath[512];
        sprintf( szPath, "%s/%s", SPIFFS_BASE_PATH, fileName );
        auto fp = fopen( szPath, "r" );
        if ( fp )
        {
          size_t fsize = fread( ftpFileBuf, 1, fileSize, fp );
          fclose( fp );
          if ( fsize == fileSize )
          {
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
        }
        memset( sioSendBuf, 0, sizeof( sioSendBuf ) );
        sprintf( sioSendBuf, "SPIFFSGET:%03d,%d,%04X,%04X%c%c",
                 selectFileListNo,
                 result,
                 loadAdrs,
                 loadAdrs + binBufSize - 1,
                 CR, LF );
      }
    }
  }
}

static void sioRecvCommand( void )
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
    case cmdSpiffsList:
      sioCmdSpiffsList();
      break;
    case cmdSpiffsGet:
      sioCmdSpiffsGet();
      break;
  }
}

static void sioRecvParser( void )
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
        sioRecvBufByte = 0;
        break;
      case NAK:
        sioRecvCmd = cmdNak;
        sioRecvBufByte = 0;
        break;
      case CAN:
        sioRecvCmd = cmdCan;
        sioRecvBufByte = 0;
        break;
    }
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
        selectFileListNo     = atoi( &psioRecvBuf[5] );
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
      if ( strcmp( psioRecvBuf, "SPIFFSLIST" ) == 0 )
        sioRecvCmd = cmdSpiffsList;
      if ( strncmp( sioRecvBuf, "SPIFFSGET:", 10 ) == 0 )
      {
        //           1
        // 0123456789012 0   1
        // SPIFFSGET:nnn<CR><LF>
        selectFileListNo = atoi( &psioRecvBuf[10] );
        sioRecvCmd = cmdSpiffsGet;
      }
      sioRecvBufByte = 0;
    }
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
