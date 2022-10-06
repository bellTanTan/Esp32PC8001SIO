/*
  Created by tan (trinity09181718@gmail.com)
  Copyright (c) 2022 tan
  All rights reserved.

* Please contact trinity09181718@gmail.com if you need a commercial license.
* This software is available under GPL v3.
 */

#include "Esp32PC8001SIO.h"

extern  WiFiClient  telnetClient;
extern  int         telnetSeqNo;
extern  SIOCMD      sioSendCmd;
extern  int         sioSendBufPos;
extern  int         sioSendBufByte;
extern  char        sioSendBuf[128+16];


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
