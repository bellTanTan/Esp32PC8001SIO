/*
  Created by tan (trinity09181718@gmail.com)
  Copyright (c) 2022 tan
  All rights reserved.

* Please contact trinity09181718@gmail.com if you need a commercial license.
* This software is available under GPL v3.
 */

#pragma once

const char * ssid     = "test001";
const char * password = "password001";

extern const long gmtOffsetSec;

const char * ntpServer       = "192.168.1.250";
const long gmtOffsetSec      = 3600 * 9;
const int  daylightOffsetSec = 0;
                                            // 192.168.1.101 esp32-pc8001-sio
                                            // 192.168.1.102 esp32-pc8001mk2-sio
const IPAddress ip( 192, 168, 1, 101 );     // for fixed IP Address
const IPAddress gateway( 192, 168, 1, 1 );  // gateway
const IPAddress subnet( 255, 255, 255, 0 ); // subnet mask
const IPAddress DNS( 192, 168, 1, 1 );      // DNS

extern const char * ftpDir;

const char * ftpServer = "192.168.1.240";
const char * ftpUser   = "pi";
const char * ftpPass   = "pi";
const char * ftpDir    = "work/pc-8001/media";

extern const char * telnetServer;
extern const int telnetPort;

const char * telnetServer = "192.168.1.240";
const int telnetPort      = 23;
