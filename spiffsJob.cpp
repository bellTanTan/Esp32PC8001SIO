/*
  Created by tan (trinity09181718@gmail.com)
  Copyright (c) 2022 tan
  All rights reserved.

* Please contact trinity09181718@gmail.com if you need a commercial license.
* This software is available under GPL v3.
 */

#include "Esp32PC8001SIO.h"

extern  const long gmtOffsetSec;

extern  int         spiffsDirListCount;
extern  PDIRLIST    pSpiffsDirList;
extern  uint8_t *   binBuf;
extern  time_t      timeNow;


static bool listDir( fs::FS &fs, const char * dirname, uint8_t levels, PDIRLIST *ppDirList, int *piDirListCnt )
{
  char  szPath[512];
  char  szFullName[512];

  File root = fs.open( dirname );
  if ( !root )
    return false;
  if ( !root.isDirectory() )
    return false;

  memset( szPath, 0, sizeof( szPath ) );
  if ( dirname != NULL )
  {
    strcpy( szPath, dirname );
    if ( strcmp( szPath, "/" ) != 0 )
      strcat( szPath, "/" );
  }

  File file = root.openNextFile();
  while ( file )
  {
    if ( file.isDirectory() )
    {
      if ( levels )
      {
        strcpy( szFullName, szPath );
        strcat( szFullName, file.name() );
        listDir( fs, szFullName, levels - 1, ppDirList, piDirListCnt );
      }
    }
    else
    {
      const char *pszName = file.name();
      size_t fileSize     = file.size();
      time_t tLastWrite   = file.getLastWrite();
      if ( *ppDirList == NULL )
        *ppDirList = (PDIRLIST)malloc( sizeof( DIRLIST ) );
      else
        *ppDirList = (PDIRLIST)realloc( (void *)*ppDirList, sizeof( DIRLIST ) * ( *piDirListCnt + 1 ) );
      if ( *ppDirList != NULL )
      {
        strcpy( szFullName, szPath );
        strcat( szFullName, pszName );
        PDIRLIST pDirList = *ppDirList;
        int pos = *piDirListCnt;
        pDirList[pos].pszPath    = strdup( szFullName );
        pDirList[pos].fileSize   = fileSize;
        pDirList[pos].tLastWrite = tLastWrite;
        memset( pDirList[pos].szDateTime, 0, sizeof( pDirList[0].szDateTime ) );
        pos++;
        *piDirListCnt = pos;
      }
    }
    file = root.openNextFile();
  }
  return true;
}

static int qsortComp( const void * p0, const void * p1 )
{
  PDIRLIST d0 = (PDIRLIST)p0;
  PDIRLIST d1 = (PDIRLIST)p1;
  return strcmp( d0->pszPath, d1->pszPath );
}

static time_t getFileDateTime( const char * pszPath )
{
  // UNIX & *BSD & linux & Macintosh(Mac OS X以降)
  // ls -lan --time-style="+%Y-%m-%d %H:%M:%S" > fileDateTimeList.txt
  // -rw-r--r-- 1 1000 1000  4154 1991-01-27 08:25:20 3BY4 Part2 {mon L}.cmt
  //
  // Windowsコマンドプロンプトのdirはファイル日時の秒値を表示させる機能がオプション指定込みで無い。
  // そのためforfiles(Windows Vista以降)を活用
  // forfiles /c "cmd /c echo @fsize @fdate @ftime @file" > fileDateTimeList.txt
  // 4154 1991/01/27 08:25:20 3BY4 Part2 {mon L}.cmt
  time_t result = 0;
  char * p = strstr( (const char *)binBuf, pszPath );
  if ( p == NULL )
    return result;
  char * pszDateTop = p - 20;
  char szDateTime[32];
  memset( szDateTime, 0, sizeof( szDateTime ) );
  strncpy( szDateTime, pszDateTop, 19 );
  struct tm tm;
  memset( &tm, 0, sizeof( tm ) );
  //           1
  // 0123456789012345678
  // 1991-01-27 08:25:20
  // 1991/01/27 08:25:20
  szDateTime[4]  = '\0';
  szDateTime[7]  = '\0';
  szDateTime[10] = '\0';
  szDateTime[13] = '\0';
  szDateTime[16] = '\0';
  tm.tm_year = atoi( &szDateTime[0] ) - 1900;
  tm.tm_mon  = atoi( &szDateTime[5] ) - 1;
  tm.tm_mday = atoi( &szDateTime[8] );
  tm.tm_hour = atoi( &szDateTime[11] );
  tm.tm_min  = atoi( &szDateTime[14] );
  tm.tm_sec  = atoi( &szDateTime[17] );
  result = mktime( &tm );

  return result;  
}

bool getSpiffsFileList( void )
{
  if ( !SPIFFS.begin( true, SPIFFS_BASE_PATH ) )
  {
    Serial.printf( "spiffs not found\r\n" );
    return true;
  }
  Serial.printf( "spiffs found\r\n" );

  // spiffs イメージ生成の日時補完用のファイル日時情報メモリロード
  bool fFileDateTimeListLoadFailed = true;
  char szPath[512];
  sprintf( szPath, "%s%s", SPIFFS_BASE_PATH, SPIFFS_FILE_DATETIME_LIST );
  auto fp = fopen( szPath, "r" );
  if ( fp )
  {
    fseek( fp, 0, SEEK_END );
    size_t fileSize = ftell( fp );
    fseek( fp, 0, SEEK_SET );
    if ( fileSize > 0 )
    {
      binBuf = (uint8_t *)malloc( fileSize );
      if ( binBuf != NULL )
      {
        size_t result = fread( binBuf, 1, fileSize, fp );
        if ( result == fileSize )
        {
          Serial.printf( "'%s' spiffs file datetime info load\r\n", szPath );
          fFileDateTimeListLoadFailed = false;
        }
      }
    }
    fclose( fp );
  }
  else
    fFileDateTimeListLoadFailed = false;
  if ( fFileDateTimeListLoadFailed )
    return false;
  if ( binBuf != NULL )
  {
    Serial.printf( "delete '%s'\r\n", szPath );
    unlink( szPath );
  }

  Serial.printf( "spiffs get file list start\r\n" );
  listDir( SPIFFS, "/", 0, &pSpiffsDirList, &spiffsDirListCount );
  qsort( pSpiffsDirList, spiffsDirListCount, sizeof( *pSpiffsDirList ), qsortComp );
  Serial.printf( "spiffs get file list end\r\nspiffs file count: %d\r\n", spiffsDirListCount );
  if ( binBuf != NULL && spiffsDirListCount > 0 )
    Serial.printf( "spiffs file datetime update start\r\n" );
  for ( int i = 0; i < spiffsDirListCount; i++ )
  {
    time_t tLastWrite = pSpiffsDirList[i].tLastWrite;
    if ( binBuf != NULL && tLastWrite == -1 )
    {
      // spiffs イメージ生成の日時補完
      tLastWrite = getFileDateTime( &pSpiffsDirList[i].pszPath[1] );
      char szFullPath[512];
      sprintf( szFullPath, "%s%s", SPIFFS_BASE_PATH, pSpiffsDirList[i].pszPath );
      struct utimbuf ut;
      memset( &ut, 0, sizeof( ut ) );
      ut.actime  = tLastWrite;
      ut.modtime = tLastWrite;
      int result = utime( szFullPath, &ut );
      if ( result == 0 )
        pSpiffsDirList[i].tLastWrite = tLastWrite;
    }
    memset( pSpiffsDirList[i].szDateTime, 0, sizeof( pSpiffsDirList[0].szDateTime ) );
    sprintf( pSpiffsDirList[i].szSize, "%5d", pSpiffsDirList[i].fileSize );
  }
  if ( binBuf != NULL && spiffsDirListCount > 0 )
    Serial.printf( "spiffs file datetime update end\r\n" );
  return true;
}

void dumpSpiffsFileList( void )
{
  if ( spiffsDirListCount == 0 && pSpiffsDirList == NULL )
    return;
  Serial.printf( "spiffs file count: %d\r\n", spiffsDirListCount );
  for ( int i = 0; i < spiffsDirListCount; i++ )
  {
    time_t tLastWrite = pSpiffsDirList[i].tLastWrite - gmtOffsetSec;
    time_t tDiffSec   = timeNow - tLastWrite;
    struct tm * tm    = localtime( &tLastWrite );
    char szDateTime[32];
    int n = sizeof( szDateTime ) - 1;
    memset( szDateTime, 0, sizeof( szDateTime ) );
    if ( tDiffSec >= ( 182 * 86400 ) || tDiffSec < 0 )
    {
      // ls -l 等の日時書式化(現在日より182日(約6ヶ月)以上古い or 未来は時分の箇所は年)
      //            1
      // 012345678901
      // Jun 30  1993
      strftime( szDateTime, n, "%b %d  %Y", tm );
    }
    else
    {
      //            1
      // 012345678901
      // Jun 30 21:49
      strftime( szDateTime, n, "%b %d %H:%M", tm );
    }
    strcpy( pSpiffsDirList[i].szDateTime, szDateTime );
    Serial.printf( "%03d: %s %s %s\r\n",
                   i,
                   pSpiffsDirList[i].szSize,
                   pSpiffsDirList[i].szDateTime,
                   pSpiffsDirList[i].pszPath );
  }
  size_t tTotalBytes = SPIFFS.totalBytes();
  size_t tUsedBytes  = SPIFFS.usedBytes();
  Serial.printf( "spiffs total byte: %8d\r\n", tTotalBytes );
  Serial.printf( "spiffs used  byte: %8d\r\n", tUsedBytes );
  Serial.printf( "spiffs free  byte: %8d\r\n", tTotalBytes - tUsedBytes );
}
