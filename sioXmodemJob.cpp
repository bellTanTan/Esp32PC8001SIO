/*
  Created by tan (trinity09181718@gmail.com)
  Copyright (c) 2022 tan
  All rights reserved.

* Please contact trinity09181718@gmail.com if you need a commercial license.
* This software is available under GPL v3.
 */

#include "Esp32PC8001SIO.h"

extern  int         selectDivisionNo;
extern  int         diviListCount;
extern  PDIVILIST   pDiviList;
extern  int         binBufSize;
extern  int         binBufOffset;
extern  uint8_t *   binBuf;
extern  time_t      timeNow;
extern  int         xmodemSeqNo;
extern  uint8_t     xmodemBlockNo;
extern  int         xmodemSendBytes;
extern  time_t      xmodemTimer;
extern  SIOCMD      sioSendCmd;
extern  SIOCMD      sioRecvCmd;
extern  int         sioSendBufByte;
extern  char        sioSendBuf[128+16];


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
        xmodemSendBytes = pDiviList[selectDivisionNo].areaSize;
        binBufOffset    = pDiviList[selectDivisionNo].startAdrs;
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
