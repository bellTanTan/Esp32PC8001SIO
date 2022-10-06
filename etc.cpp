/*
  Created by tan (trinity09181718@gmail.com)
  Copyright (c) 2022 tan
  All rights reserved.

* Please contact trinity09181718@gmail.com if you need a commercial license.
* This software is available under GPL v3.
 */

#include "Esp32PC8001SIO.h"

extern  WiFiClient  telnetClient;
extern  int         fileListCount;
extern  PFILELIST   pFileList;
extern  int         ftpFileBufSize;
extern  uint8_t *   ftpFileBuf;
extern  int         binBufSize;
extern  int         binBufOffset;
extern  uint8_t *   binBuf;
extern  time_t      timeNow;
extern  struct tm * localTime;
extern  int         termWidth;
extern  int         termHeigh;


void getLocalTime( void )
{
  timeNow   = time( NULL );
  localTime = localtime( &timeNow );
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
