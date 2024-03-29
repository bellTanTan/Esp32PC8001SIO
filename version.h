/*
  Created by tan (trinity09181718@gmail.com)
  Copyright (c) 2022 tan
  All rights reserved.

* Please contact trinity09181718@gmail.com if you need a commercial license.
* This software is available under GPL v3.
 */

// 更新履歴
// 2022/12/10 v1.0.3 cmd sntp or mat sntp で月が正しく定義出来ない不具合改修(確認不足)
// 2022/10/10 v1.0.2 PC-8001mkIIにてRS-232C受信割込テーブル位置(8000H,8001H)を書換え
//                   られるタイプのバイナリ受信処理対応(確認不足)
//                   (cmt Planet Taizer:8000H~E7FFHが顕著)
//                   多段ロード形式cmtファイル対応
// 2022/10/01 v1.0.1 spiffs関連実装
//                   PC-8001とPC-8001mkIIのboot判定とフックコマンドの切り替え
//                   PC-8001mkII RS-232C 受信割込9600bps実装
//                   cmd ftpget or mat ftpget or cmd spiget or mat spigetにて
//                   PC-8001時EA00H or PC-8001mkII E600H 以上に入りこむメモリー
//                   オーバー判定と受信不良の不具合改修
//                   (cmt Scramble:C010H~E9FFHが顕著)
// 2022/09/17 v1.0.0 リリース
// 2022/08/07 v1.0.0 GitHub 公開
//                   

#pragma once

#define ESP32_PC8001SIO_VERSION_MAJOR     1
#define ESP32_PC8001SIO_VERSION_MINOR     0
#define ESP32_PC8001SIO_VERSION_REVISION  3
