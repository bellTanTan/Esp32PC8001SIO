/*
  Created by tan (trinity09181718@gmail.com)
  Copyright (c) 2022 tan
  All rights reserved.

* Please contact trinity09181718@gmail.com if you need a commercial license.
* This software is available under GPL v3.
 */

#include "Esp32PC8001SIO.h"

extern  Adafruit_BME280 bme;
extern  Adafruit_Sensor * bmeTemp;
extern  Adafruit_Sensor * bmePressure;
extern  Adafruit_Sensor * bmeHumidity;
extern  struct tm * localTime;
extern  BME280DATA  bme280SampleData[60];
extern  BME280DATA  bme280Data;
extern  int         bmeGetOldSec;


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
