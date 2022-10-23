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
extern  int         diviListCount;
extern  PDIVILIST   pDiviList;
extern  int         ftpFileBufSize;
extern  uint8_t *   ftpFileBuf;
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
  while ( p )
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

bool cmt2bin( void )
{
  int ftpBufOffset = 0;
  uint16_t loadAdrs = 0;
  uint16_t endAdrs = 0;
  diviListCount = 0;
  while ( true )
  {
    int dataType = 0;
    if ( ftpBufOffset >= ftpFileBufSize )
      break;
    bool fBasCmt = ( ( ftpFileBuf[ftpBufOffset] == 0xD3 ) ? true : false );
    bool fMonCmt = ( ( ftpFileBuf[ftpBufOffset] == 0x3A ) ? true : false );
    if ( fBasCmt == false && fMonCmt == false )
    {
      if ( ftpBufOffset == 0 )
      {
        dataType = 1;
        loadAdrs = 0;
        endAdrs  = ftpFileBufSize;
        size_t dataSize = endAdrs - loadAdrs;
        memcpy( &binBuf[loadAdrs], &ftpFileBuf[ftpBufOffset], dataSize );
        ftpBufOffset += ( endAdrs + 1 );
      }
      else
      {
        ftpBufOffset++;
      }
    }
    if ( fBasCmt )
    {
      if ( ftpFileBufSize > ( 10 + 6 + 9 ) )
      {
        int startOffset = 0;
        uint8_t buf[16];
        loadAdrs = 0;
        memset( buf, 0xD3, 10 );
        bool fHead = ( memcmp( &ftpFileBuf[ftpBufOffset], buf, 10 ) == 0 ? true : false );
        if ( fHead )
        {
          ftpBufOffset += ( 10 + 6 );
          startOffset = ftpBufOffset;
        }
        while ( fHead )
        {
          if ( ftpBufOffset >= ftpFileBufSize )
          {
            fHead = false;
            break;
          }
          if ( ftpFileBuf[ftpBufOffset+0] == 0x00
            && ftpFileBuf[ftpBufOffset+1] == 0x00
            && ftpFileBuf[ftpBufOffset+2] == 0x00 )
          {
            ftpBufOffset += 3;
            break;
          }
          ftpBufOffset++;
        }
        if ( fHead )
        {
          memset( buf, 0x00, 9 );
          bool fEnd = ( memcmp( &ftpFileBuf[ftpBufOffset], buf, 9 ) == 0 ? true : false );
          if ( fEnd )
          {
            dataType = 2;
            loadAdrs = 0x21 | ( ftpFileBuf[startOffset+1] << 8 );
            endAdrs  = loadAdrs + ( ftpBufOffset - startOffset );
            size_t dataSize = endAdrs - loadAdrs;
            memcpy( &binBuf[loadAdrs], &ftpFileBuf[startOffset], dataSize );
            ftpBufOffset += 9;
          }
        }
      }
    }
    if ( fMonCmt )
    {
      loadAdrs  = (uint16_t)ftpFileBuf[ftpBufOffset+1] << 8;
      loadAdrs |= (uint16_t)ftpFileBuf[ftpBufOffset+2];
      endAdrs   = loadAdrs;
      ftpBufOffset += 4;
      while ( true )
      {
        if ( ftpFileBuf[ftpBufOffset+0] == 0x3A
          && ftpFileBuf[ftpBufOffset+1] == 0x00
          && ftpFileBuf[ftpBufOffset+2] == 0x00 )
        {
          ftpBufOffset += 3;
          dataType = 3;
          break;
        }
        if ( ftpFileBuf[ftpBufOffset+0] == 0x3A )
        {
          uint8_t dataSize = ftpFileBuf[ftpBufOffset+1];
          memcpy( &binBuf[endAdrs], &ftpFileBuf[ftpBufOffset+2], dataSize );
          endAdrs += dataSize;
          ftpBufOffset += ( 3 + dataSize );
        }
        else
        {
          break;
        }
      }
    }
    if ( dataType != 0 )
    {
      size_t dataSize = sizeof( *pDiviList ) * ( diviListCount + 1 );
      if ( !pDiviList )
        pDiviList = (PDIVILIST)malloc( dataSize );
      else
        pDiviList = (PDIVILIST)realloc( pDiviList, dataSize );
      if ( !pDiviList )
        return false;
      pDiviList[diviListCount].dataType  = dataType;
      pDiviList[diviListCount].startAdrs = loadAdrs;
      pDiviList[diviListCount].endAdrs   = endAdrs - 1;
      pDiviList[diviListCount].areaSize  = pDiviList[diviListCount].endAdrs - pDiviList[diviListCount].startAdrs + 1;
      pDiviList[diviListCount].execAdrs  = 0;
      diviListCount++;
    }
  }

  if ( diviListCount > 0 )
  {
    // Adrs : +0 +1 +2 +3 +4 +5 +6 +7 +8 +9 +A +B +C +D +E +F
    // 0000 : 01 00 00 40 00 00 00 00 00 00 00 00 00 00 00 00
    // 0010 : 00 01 01 79 09 00 00 00 00 00 00 00 00 00 00 00
    // 0020 : 00 00 00 00 61 75 74 6F 20 00 00 00 00 00 00 00
    // 0030 : 00 00 00 00 67 6F 20 74 6F 20 00 00 00 00 00 00
    // 0040 : 00 00 00 00 6C 69 73 74 20 00 00 00 00 00 00 00
    // 0050 : 00 00 00 00 72 75 6E 0D 4C 0D 4C 0D 67 38 30 34
    // 0060 : 30 0D 00
    if ( pDiviList[0].dataType == 3 && pDiviList[0].startAdrs == 0xEA68 )
    {
      uint16_t checkAdrs = pDiviList[0].startAdrs + 0x57;
      if ( binBuf[checkAdrs] == 0x0D )
      {
        checkAdrs++;
        size_t dataSize = pDiviList[0].endAdrs - checkAdrs + 1;
        if ( dataSize > 0 )
        {
          char * fkey5Buf = (char *)malloc( dataSize );
          if ( fkey5Buf )
          {
            memset( fkey5Buf, 0, dataSize );
            memcpy( fkey5Buf, &binBuf[checkAdrs], dataSize );
            char szDelimiter[16];
            sprintf( szDelimiter, "%c", CR );
            char * p = strtok( fkey5Buf, szDelimiter );
            int item = 0;
            while ( p )
            {
              if ( p[0] == 'g' || p[0] == 'G' )
              {
                int execAdrs;
                sscanf( &p[1], "%x", &execAdrs );
                if ( item >= 0 && item < diviListCount )
                  pDiviList[item].execAdrs = execAdrs;
              }
              if ( strcasecmp( p, "RUN" ) == 0 )
              {
                if ( item >= 0 && item < diviListCount )
                  pDiviList[item].execAdrs = pDiviList[item].startAdrs;
              }
              p = strtok( NULL, szDelimiter );
              item++;
            }
            free( fkey5Buf );
          }
        }
      }
    }
  }

  _DEBUG_PRINT( "%s(%d) diviListCount %d\r\n", __func__, __LINE__, diviListCount );
  for ( int i = 0; i < diviListCount; i++ )
  {
    _DEBUG_PRINT( "%s(%d) pDiviList[%d].dataType  %d\r\n",     __func__, __LINE__, i, pDiviList[i].dataType );
    _DEBUG_PRINT( "%s(%d) pDiviList[%d].startAdrs 0x%04X\r\n", __func__, __LINE__, i, pDiviList[i].startAdrs );
    _DEBUG_PRINT( "%s(%d) pDiviList[%d].endAdrs   0x%04X\r\n", __func__, __LINE__, i, pDiviList[i].endAdrs );
    _DEBUG_PRINT( "%s(%d) pDiviList[%d].areaSize  %d\r\n",     __func__, __LINE__, i, pDiviList[i].areaSize );
    _DEBUG_PRINT( "%s(%d) pDiviList[%d].execAdrs  0x%04X\r\n", __func__, __LINE__, i, pDiviList[i].execAdrs );
  }

  return true;
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

#ifdef _DEBUG
void _DEBUG_PRINT( const char * format, ... )
{
  va_list ap;
  va_start( ap, format );
  int size = vsnprintf( NULL, 0, format, ap ) + 1;
  if ( size > 0 )
  {
    va_end( ap );
    va_start( ap, format );
    char buf[size + 1];
    vsnprintf( buf, size, format, ap );
    Serial.printf( "%s", buf );
  }
  va_end( ap );
}
#endif // _DEBUG
