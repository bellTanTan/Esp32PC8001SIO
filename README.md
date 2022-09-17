# Esp32PC8001SIO

## 1.概要
NEC/PC-8001 SIO(DIP16 socket)に挿すゲタのハードとソフトです。ESP32とBME280を活用してSNTP簡易日時合わせ/BME280情報取得/FTPリスト取得/FTP Download GETを行うことが出来ます。

![PC-8001装着状態](/img/009.jpg)

![拡張コマンド実行1](/img/010.jpg)

![拡張コマンド実行2](/img/011.jpg)

![拡張コマンド実行3](/img/012.jpg)

## 2.はじめに

2022年6月の「父の日」のプレゼントと称して息子夫婦/娘夫婦よりPC-8031-2W基板がプレゼントされて来ました。お父さんならこれを何かに活用できるだろうと言う目論見があったようです(草) 簡単に取り外すことが出来るICは死蔵保管とし基板にあったインバータロジックIC(SN74LS04)を2つ取り外して遥か昔に自作したNEC/PC-8001 SIO(DIP16 socket)ゲタでもちまちま作ってみるかと始めた結果です。

![PC-8031-2W基板](/img/004.jpg)

ここに来るまでに以下の形態をとって来ました。

第一形態はRS-232C D-SUB9([極小RS232-TTLコンバータモジュール](https://www.amazon.co.jp/gp/product/B00OPU2QJ4/ref=ppx_yo_dt_b_asin_title_o04_s00?ie=UTF8&psc=1))

![第一形態](/img/005.jpg)

第二形態はRS-232C D-SUB25(上記の[極小RS232-TTLコンバータモジュール](https://www.amazon.co.jp/gp/product/B00OPU2QJ4/ref=ppx_yo_dt_b_asin_title_o04_s00?ie=UTF8&psc=1)x2使用したD-SUB25シェル内2階建て配線物)
![第二形態](/img/006.jpg)

第三形態はフリスク基板 & ESP32-WROOM-32 bluetoothを活用したSerial←→bluetoothなブリッジ物
![第三形態](/img/007.jpg)

このリポジトリに記載するのは第四形態物です。

![第四形態部品面](/img/013.jpg)

![第四形態はんだ面](/img/014.jpg)

## 3.出来ない事

出来る事より出来ない事を優先します。このリポジトリを参考にして製作したあとで「あぁぁ、そうなんだ。それならイラね」「無駄な作業をさせやがって。ったく」と成らない為です(笑)

PC-8001本体のリセットスイッチでESP32-WROOM-32のリセット不可。不便なのは承知の上です。基板上の赤タクトスイッチを押して下さい。

PCG 8100との共存不可。SIO(DIP16 socket)とIC13(ユーザーROM/拡張ROMを挿すソケット)が干渉するためここで製作するSIOゲタと2764ROMゲタは利用不可。
![PCG8100装着状態](/img/008.jpg)

[PSA2.8a](http://fami-lan.net/parts/pcb.html)との共存不明。PSA2.8aは所有していない為、共存できるかわかりません。2022/09/10時点で見ると基板はまだ販売されているようなので近いうちに購入して確認してみたいところです。

その他PC-8001 CPUゲタ化装着する基板との共存不明。

その他外部化機器との共存不明。

小生の利用環境において根本的に外部バスと接続する機器で剥き出しな機器だと遊びに来てた小さい子が走り回って蹴ったり素手/濡手(自由に飲食するためｗ)で触ったり床/畳置きの場合につまづいて転倒したりした場合事故/怪我が想定されます。子供は電子機器に対しての基礎知識無いので自由人です(草) 明らかに素手/濡手で触っても感電/機器動作不良等を引き起こさないがっちりした筐体品なら外部化機器利用もありなのですがどうしても事故る/怪我する事を想定してしまうと設置に躊躇してしまいます。

またPC-8001外部バスの50ピンフラットケーブルは長いとノイズに弱い。ツイストペアでFGシールドなケーブルなら良いのですが無いものねだってもどうしようも無いです。PCG 8100以外の外部化機器はPC-8033しか所有していません。PC-8033があるのでPC-80S31経由でDisk利用可な環境ですが何せ物が40年超え品。磁気ヘッド補修なんて経験値ゼロ。5.25inch磁気ヘッドクリーニングキットも15年程前に使い切りました。5.25inch2Dメディアは今となっては新品購入不可。2Dメディア保管作業失敗するとメディア表面にカビが生えます。除去作業に失敗してメディア破損やら磁気ヘッド破損やら多々見て来ました(笑) いつ壊れても文句言えない製品のためDisk機器は特別な場合しか利用しないようにしています(笑)

SIO 4800bps のダウンロードでも遅い。1000BASE-T/100BASE-Tのネット速度に慣れてしまった為です(笑) CMT ロード(600ボー)よりは早いですが慣れは怖い物です(笑) xmodem sum(128byte単位) プロトコルでESP32→PC-8001バイナリ受信を行います。128バイト受信中(ポーリング受信)に息継ぎ(RTSを落とす事)する形式にはしていません。計測した範囲で実効速度は450〜460byte/secでした。

セキュアftpを利用出来ない。基礎的なftpプロトコルを利用しています。暗号化されていない平文でユーザー名/パスワードがネットワークに流れます。広域ネットのftpサーバー機を利用する事は可能ですがセキュリティリスク高です。広域ネット側のftpサーバー機を利用する場合には十分にそのリスクを負って下さい。

PC-8001本体よりセーブ(csave/mom W等)の代替として利用出来ない。そこまで実機運用にこだわる必要ないと思ってるため実装していません。ftpサーバーが使えるのでscpでファイル転送等いくらでも出来るためと言うのが本音です(笑)

## 4.最重要項目

元々公開する事を前提にしていませんでした。大切な過去資産/中古資産が作業内容によっては復旧不可能な破損状態になるかも知れません。このリポジトリを参考にして損害が発生しても一切保証出来ません。ご了承願います。

SIO Socket の端子図を示します

![SIOSocket端子図](/img/001.jpg)

+5/+12V/-12Vが出てきています。PC-8001通電中に短絡させると一発で機器破損する可能性あります。十分に注意して下さい。

関連するPC-8001の公開されている回路図を示します

![PC8001SIOCMT回路図](/img/000.jpg)

この回路図は工学社 I/O 1980年12月号または工学社 I/O別冊 PC-8001活用研究にて掲載された回路になります。インターネットアーカイブで公開されている[工学社 I/O別冊 PC-8001活用研究](https://archive.org/details/pc-8001_202108)より無断転載しました。手持ちPC-8001のSIO回路が断線無く繋がっている事をテスター等で十分に徹底確認して下さい。この時点でPC-8001側の回路導通不良があった場合は自ら補修するか別ハードを手に入れるか作業自体を諦めるかして下さい。

## 5.製作するゲタ回路図

SIOゲタの回路図を示します

![SIOゲタ回路図](/img/002.jpg)

74LS04 5A/6A がGND落ちてないのは気持ち悪いと思われる方はGNDへ落として下さい。パスコン入ってないのは気持ち悪いと思われる方は追加して下さい。手作業での手はんだ回路実装になるため配線不良(断線/短絡/はんだボイド等)でPC-8001側にダメージを与える事も予測されます。テスター等で十分に配線間違いが無いか導通確認を徹底して下さい。

細ピンヘッダは気持ち「ハの字」になるように斜めにブレッドボード等に挿してはんだ付します。気持ち「ハの字」にするのはPC-8001本体をキーボード下にして本体ネジ締めのときゲタ落下防止の為です。

2764ROMゲタの回路図を示します

![2764ROMゲタ回路図](/img/003.jpg)

パスコン入ってないのは気持ち悪いと思われる方は追加して下さい。手作業での手はんだ回路実装になるため配線不良(断線/短絡/はんだボイド等)でPC-8001側にダメージを与える事も予測されます。十分にテスター等で配線間違いが無いか導通確認を徹底して下さい。

ピンヘッダは気持ち「ハの字」になるように斜めにブレッドボード等に差してはんだ付します。気持ち「ハの字」にするのはPC-8001本体をキーボード下にして本体ネジ締めのときゲタ落下防止の為です。ピンヘッダには分割ロングピンソケットを挿します。

![2764ROMゲタハの字](/img/032.jpg)

1990年代に秋葉原のジャンクBOXで購入したFC-80と言う手持ち2716ROMゲタを示します。

![FC80ゲタ実装面](/img/022.jpg)

![FC80ゲタはんだ面](/img/023.jpg)

遥か昔に自作したROMゲタ品は既に無いため今回はこの製品をお手本としました。IC13に挿すピン部品はJAE/PICD-12PB-T1と読めます。しかしこのピン部品は現在(2022/07/17時点)入手不可だった為ピンヘッダ(元々手持ち在庫資材)と分割ロングピンソケット(元々手持ち在庫資材)を繋ぎ合わせて2764ROMゲタ足としました。もっと適切な方法があればその方法で実装して下さい。PC-8001のキーボード裏基板と接触干渉しない。ROMゲタ装着時に他のICと接触干渉しない。これが目標になるROMゲタの製作と言う事です。

![PC8001キーボード裏](/img/021.jpg)

以下関連する実測寸法です。

FC-80ピン長 5.6mm

![FC80ゲタピン1](/img/024.jpg)

![FC80ゲタピン2](/img/025.jpg)

FC-80ピン全体長 10.7mm

![FC80ゲタ全体ピン1](/img/026.jpg)

![FC80ゲタ全体ピン2](/img/027.jpg)

2764ROMゲタピン長 3.0mm

![2764ROMゲタピン1](/img/030.jpg)

![2764ROMゲタピン2](/img/031.jpg)

2764ROMゲタピン全体長 11.6mm

![2764ROMゲタ全体ピン1](/img/028.jpg)

![2764ROMゲタ全体ピン2](/img/029.jpg)

## 6.部品表
公開する事を前提に部品表を元々まとめていなかったため手持ち資材で購入元/品番が不明のものがあります。ご了承願います。

|部品番号|部品名|URL|数量|備考|
|----|----|----|----|----|
|CPU1|ESP32-WROOM-32|https://akizukidenshi.com/catalog/g/gM-11647/|1|新規に購入する場合は各種不具合改修されたD版以降が良いと思います|
|IC1|SN74LS04||1|PC-8031-2W基板から取り外して利用しました。中古購入だとヤフオク/各種電子部品取り扱いショップで探して下さい|
|IC2|2764 UV-EPROM||1|手持ち品(NEC/uPD2764D)を使用しました。中古購入だとヤフオク/各種電子部品取り扱いショップで探して下さい|
|U1|AMS1117-3.3V降圧型モジュール|https://www.amazon.co.jp/KKHMF-AMS1117-3-3-%E3%83%91%E3%83%AF%E3%83%BC%E3%83%A2%E3%82%B8%E3%83%A5%E3%83%BC%E3%83%AB-AMS1117-3-3V-%E9%99%8D%E5%9C%A7%E5%9E%8B%E3%83%A2%E3%82%B8%E3%83%A5%E3%83%BC%E3%83%AB/dp/B07FZ17B7D/ref=sr_1_6?__mk_ja_JP=%E3%82%AB%E3%82%BF%E3%82%AB%E3%83%8A&keywords=AMS1117&qid=1663228485&sr=8-6|1|10セット品より動作確認して良さそうなのを選別して利用します。L字ピンは取り外して3ピンヘッダを取り付けて利用します|
|U2|BME280|https://www.amazon.co.jp/KKHMF-BME280%E6%B8%A9%E5%BA%A6%E3%82%BB%E3%83%B3%E3%82%B5-%E3%83%87%E3%82%B8%E3%82%BF%E3%83%AB%E3%83%96%E3%83%AC%E3%82%A4%E3%82%AF%E3%82%A2%E3%82%A6%E3%83%88IIC-5V%E6%B8%A9%E5%BA%A6%E3%82%BB%E3%83%B3%E3%82%B5-Arduino%E3%81%AB%E5%AF%BE%E5%BF%9C/dp/B088FLGGT8/ref=sr_1_7?__mk_ja_JP=%E3%82%AB%E3%82%BF%E3%82%AB%E3%83%8A&keywords=BME280&linkCode=qs&qid=1663227828&sourceid=Mozilla-search&sr=8-7|1|BMP280(温度/気圧)を引き当てたらハズレと思って下さい。本来ならセンサ配置面のシルク印刷BMEの下にマークが入るはずです。マーク記載無し品として安くしているのかも知れません。BME280(温度/湿度/気圧)品販売なのにBMP280(温度/気圧)品混入が記載したURL以外のメーカー品であったような気がします|
|U3|AE-LCNV4-MOSFET|https://akizukidenshi.com/catalog/g/gK-13837/|1|ESP32側(3.3V)とPC-8001側(5V)とのTTLレベル変換に使用します|
|C1|小形アルミニウム電解コンデンサ 16V 100μF||1|
|C2|セラミックコンデンサ 50V 0.1uF||1|
|R1|1/6W 10kΩ||1|
|J1|細ピンヘッダ 1×40 (黒)|https://akizukidenshi.com/catalog/g/gC-06631/|1|8ピンx2としてSIOへ差すゲタで利用します|
|J2|ピンヘッダ 1x40|https://akizukidenshi.com/catalog/g/gC-00167/|1|12ピンx2としてIC13へ差すゲタで利用します。3ピンx1として5V降圧3.3Vモジュールで使用します|
|J3|分割ロングピンソケット 1x42|https://akizukidenshi.com/catalog/g/gC-05779/|1|12ピンx2としてIC13へ差すゲタで利用します|
|J4|ピンヘッダ (オスL型) 1x40|https://akizukidenshi.com/catalog/g/gC-01627/|1|1ピン、2ピンとしてESP32-WROOM-32のGND/TXD0/RXD0で利用します|
|S1|タクトスイッチ (赤色)|https://akizukidenshi.com/catalog/g/gP-03646/|1|ESP32-WROOM-32のRESET(EN)に利用します|
|S2|タクトスイッチ (黒色)|https://akizukidenshi.com/catalog/g/gP-03647/|1|ESP32-WROOM-32のFLASH(GPIO0)に利用します|
| |ICソケット (16P) (10個入)|https://akizukidenshi.com/catalog/g/gP-00007/|1|SIOゲタ上で1つ74LS04装着に利用します|
| |ICソケット (28P) 600mil (10個入)|https://akizukidenshi.com/catalog/g/gP-00012/|1|2764ROMゲタ上で1つ2764ROM装着に利用します|
| |ミンティア基板 for ESP-WROOM-32|https://www.amazon.co.jp/gp/product/B07SZLG6KL/ref=ppx_yo_dt_b_asin_title_o06_s00?ie=UTF8&psc=1|1|SIOゲタとして利用します|
| |両面スルーホールガラスコンポジット・ユニバーサル基板 Cタイプ めっき仕上げ 72×47mm|https://akizukidenshi.com/catalog/g/gP-03231/|1|2764ROMゲタに利用します|
| |プラスチックナット+連結(6角ジョイント) スペーサー (10mm) セット|https://akizukidenshi.com/catalog/g/gP-01864/|1|

## 7.ESP32-WROOM-32へのファーム書き込み

資料整備時点(2022/09/15)で[Arduino IDE](https://www.arduino.cc/en/software)は2.0.0がリリースされています。ここでは1.8.19で記載します。Arduino IDE環境定義、esp32環境定義は他サイトを参考にして下さい。[DEKO様サイト](https://ht-deko.com/arduino/esp-wroom-32.html)は情報の網羅レベルが半端ないです。一読されるのをお勧めします。

必要になるライブラリは以下2点です。

    ESP32 FTPClient v0.1.4
    Adafruit BME280 v2.2.2

ツール→ライブラリ管理よりダウンロードします。関連するライブラリもあると自動判断されたら全てダウンロードします。

ESP32 FTPClient v0.1.4はパッチを入れます。

    ESP32 FTPClient v0.1.4 patch

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

具体的には ESP32_FTPClient.cpp を探して308行目をコメント化。新規に同じ行へ

    list[_b] = tmp;

を入れます。行番号表記付きで記述すると以下のようになります。

    307 String tmp = dclient.readStringUntil('\n');
    308 list[_b] = tmp;
    309 //list[_b] = tmp.substring(tmp.lastIndexOf(" ") + 1, tmp.length());
    310 //FTPdbgn(String(_b) + ":" + tmp);

この作業を怠るとファイル名しか取得出来ない状態になるため実利用で誤作動します。

ご自身のネットワーク環境に合わせて定義を行います。const.hの定義を書き換えます。この手法はファーム書き込み済みESP32-WROOM-32チップ破棄の時にゴミ拾いされて解析されWiFiネットワークを踏み台にされるセキュリティリスクを伴います。企業等で大量(1万個とか10万個とか)生産/破棄する場合はたしかにヤバいと思います。しかしどこの誰とも知れない一般家庭のWiFiネットワーク侵入(踏み台化)をゴミ拾いから行うヤツ居るのか(笑) エロサイト閲覧でbot感染してbot組み込まれる方がよっぽど自然な流れなセキュリティリスクと個人的には思います。どうしても気になる場合は廃棄の時、金槌等で文字通り破片になるまでESP32-WROOM-32を粉々に砕いて廃棄して下さい。セキュリティガチガチな実装じゃないとイヤだ星人な方はご自身が納得行く形式に組み直して下さい。

ネットワーク定義の利便性を高めるにはesp32のpreferencesを活用してcmd wifisetup/cmd ifconfig/cmd ntpsetup/cmd ftpsetup等が作れそうです。

以下書き換え対象のconst.hの内容です。

    26 #define FTP_DIR           "work/pc-8001/media"
    33 const char * ssid     = "test001";
    34 const char * password = "password001";
    36 const char * ntpServer       = "192.168.1.250";
    40 const IPAddress ip( 192, 168, 1, 101 );     // for fixed IP Address
    41 const IPAddress gateway( 192, 168, 1, 1 );  // gateway
    42 const IPAddress subnet( 255, 255, 255, 0 ); // subnet mask
    43 const IPAddress DNS( 192, 168, 1, 1 );      // DNS
    45 const char * ftpServer = "192.168.1.240";
    46 const char * ftpUser   = "pi";
    47 const char * ftpPass   = "pi";
    48 const char * telnetServer = "192.168.1.240";
    49 const int telnetPort      = 23;

26行目はftpサーバーの読み出し対象のディレクトリです。アクセス可能なディレクトリ名を定義して下さい。  
33行目はWiFi 2.4GHz 11a/11b/11g/11nのSSIDです。  
34行目は接続先SSIDのパスワードです。  
36行目は利用するntpサーバーです。ローカルネットに自前のntpサーバーが無い場合は普段利用定義してるntpサーバーを記述します。以下から1つ選んでも良いと思います。選択の基準はネットワーク的距離(応答時間)と思います。昔、桜時計で...(草)  

    ntp1.jst.mfeed.ad.jp
    ntp2.jst.mfeed.ad.jp
    ntp3.jst.mfeed.ad.jp

40行目は、このSIOゲタのESP32-WROOM-32で利用する固定IPアドレス値です。  
41行目は、このSIOゲタのESP32-WROOM-32で利用するゲートウェイIPアドレス値です。  
42行目は、このSIOゲタのESP32-WROOM-32で利用するサブネットマスク値です。  
43行目は、このSIOゲタのESP32-WROOM-32で利用するDNS IPアドレス値です。  
dhcpじゃないとイヤだ星人の方は40行目〜43行目定義は放置してEsp32PC8001SIO.inoの157行目をコメントにして下さい。  

元

    156 WiFi.mode( WIFI_STA );
    157 WiFi.config( ip, gateway, subnet, DNS );
    158 delay( 10 );

dhcp化

    156 WiFi.mode( WIFI_STA );
    157 //WiFi.config( ip, gateway, subnet, DNS );
    158 delay( 10 );

45行目はftpサーバーのIPアドレス値です。DNSで名前解決できる場合は適切な文字列を定義して下さい。  
46行目はftpサーバーログインユーザー名です。  
47行目はftpサーバーログインユーザーのパスワードです。  
48行目は現時点(2022/09/15)では利用出来ません。定義としてはtelnetサーバーのIPアドレス値です。  
49行目は現時点(2022/09/15)では利用出来ません。定義としてはtelnetサーバーのTCPポート番号値です。  

ボード定義(Arduino IDE board/target/flash size/partition scheme/PSRAMの選択)が終わったら「検証」をクリックしてコンパイルがとおるか確認して下さい。現時点(2022/09/15)では利用出来ませんがcmd spiffslist/cmd spiffsgetの実装のためにpartition schemeはNo OTA (1MB APP/3MB SPIFFS)として下さい。[ESP32 Sketch Data Upload](https://github.com/lorol/arduino-esp32fs-plugin)を使用する事になりますので環境定義して頂いたら幸いです。

SIOゲタ、電源ユニット、TTLレベル変換USBシリアル変換ユニットをブレッドボードに挿した状態を示します。TTLレベル変換USBシリアル変換ユニットはTTLレベル3.3Vで使用します。

![ESP32単体開発環境1](/img/042.jpg)

TTLレベル変換USBシリアル変換ユニットの5V/3.3VよりESP32-WROOM-32の電源をとる形式で解説しているページも多々あります。USB1ポートあたり500mAが限度です。このSIOゲタのファームの場合、即時WiFi使用開始しますので瞬間的に500mA保証要なので電力供給が下回りリセットを繰り返す事になりかねません。面倒でも別途用意する電源ユニットより5V供給してAMS1117-3.3V降圧型モジュールより3.3VをESP32-WROOM-32へ供給します。

![ESP32電流](/img/056.jpg)

ESP32-WROOM-32よりL字ピンにてTXD0とRXD0の繋ぎを示します。極小シルク印刷で「ミンティア基板 for ESP-WROOM-32」にTXDとRXDが記載されています。「ミンティア基板 for ESP-WROOM-32」の端子情報も示します。

![ESP32単体開発環境2](/img/057.jpg)

![ESP32単体開発環境3](/img/040.jpg)

![ESP32単体開発環境4](/img/041.jpg)

電源ユニットの電源を入れてAMS1117-3.3V降圧型モジュールのLEDが点灯するのを確認します。LEDが点灯しない。焦げ臭い。煙が出る。等の異常がある時は即座に電源を切って火災発生案件に成らないように注意して下さい。

正常に電源投入が出来ていれば赤タクトスイッチを「押して離す」にてリセットがかかります。元々購入時に書き込まれていたファームが起動する場合もあると思います。ユーザーサイドファームが何も書き込まれていない場合もあると思います。TTLレベル変換USBシリアル変換ユニットの対応するシリアルポートをArduino IDEで開いて確認して下さい。異常がなければ黒タクトスイッチを押しながら赤タクトスイッチを押して離し黒タクトスイッチを押すのを止めます。Arduino IDEで開いているシリアルモニタに以下のようにメッセージが受信されると配線等成功です。

![ESP32開発1](/img/050.jpg)

この状態でファーム書き込み出来ます。Arduino IDEにて「マイコンボードに書き込む」クリックして書き込み開始します。

![ESP32開発2](/img/051.jpg)

![ESP32開発3](/img/052.jpg)

![ESP32開発4](/img/053.jpg)

![ESP32開発4](/img/054.jpg)

この状態でファーム書き込み完了です。市販されているesp32-devkitのように自動書込&自動リセット回路はこのSIOゲタでは実装していません。赤タクトスイッチを押下してリセットをかけます。

書き込んだファームが動作開始すると以下の状態が受信されます。黒塗りしてる箇所には定義したSSIDと定義したESP32-WROOM-32のIPアドレス値が示されます。何度もリセットを押下して動作開始するか、電源ユニットの電源をOFF→ONにて書き込んだファームが動作開始するか確認して下さい。

![ESP32開発5](/img/055.jpg)

## 8.2764ROM書き込み

このリポジトリのz80/esp32pc8001sio_8krom.binをご使用のROMライターでロード出来る形式(?HEX形式等)に変換して2764UV-EPROMへ書き込んで下さい。

小生の普段使いOSはubuntu 22.04 LTSです。*BSD/SUN-3/SUN-4/HP-UX/Solaris/CentOS/等も利用して来ました。CP/M/MS-DOS/Windowsも利用してきました。Macは初心者レベルです(笑) FreeBSDの流れのMacは使用可能です。MSDNは1993年頃から加入して加入10年ぶんのCD/DVDも鬼のように社/自宅にあります(笑) Windowsは個人的に7でもう見切りつけました。脱Micro$oft派です(爆) どうしてもWindowsが必要な場合は、もうVM WindowsXPでいいやんと社/自宅で活動/運用しています(草) そのためZ80アセンブル作業/Z80バイナリ逆アセンブル作業/ROMライター転送等の作業もLinux上で行っています。

最近だとTL866II-PLUSと言う商品が網羅デバイスが多く便利のようです。2716/2732/2764/27128の25V/21Vには対応出来て無いようです。boothの筆選び工房様の[TL866II Plus用 21V/25V対応 Vppコンバータ](https://booth.pm/ja/items/4134951)を活用するのも良いなと心動いています。小生の手持ちADVANTEST R4945Aはもう耐用年数遥かに超えてる物を騙し騙し使っています。そろそろマジヤバい(爆)

2764がどうしても入手不可の場合は27256とか27512の後半8Kに入れて上位アドレスピンはVPP/VCCに繋ぐ形式でつったら良いと思います。その場合ROMゲタはこのリポジトリで明示した物では不可です。ご自身でPC-8001 IC13(2364 Mask ROM Socket)に挿せるROMゲタ回路を準備して製作して下さい。

新品UV-EPROMイレーサーは入手困難な状態です。手持ち品は今年3月頃確認したら既に利用不可でした。小生の場合は[東芝 殺菌ランプ 直管 グロースタータ形 4W GL4](https://www.amazon.co.jp/gp/product/B00IWN0VYC/ref=ppx_od_dt_b_asin_title_s00?ie=UTF8&psc=1)を[ブラックライト懐中電灯](https://www.amazon.co.jp/gp/product/B003G1EXFS/ref=ppx_od_dt_b_asin_title_s00?ie=UTF8&psc=1)に取り付けてACアダプタ6V入力端子取付改造し[コンセント タイマースイッチ](https://www.amazon.co.jp/gp/product/B08BR6M6NP/ref=ppx_yo_dt_b_asin_title_o02_s00?ie=UTF8&psc=1)にて15分PasocomMini mz-80cの外箱に入れてROM消ししています(笑)

## 9.SIOゲタ装着

PC-8001電源切状態で行います。SIO Socketに装着してみるとESP32-WROOM-32側の自重でぽとっと落ちそうでした。とても危険ですのでスペーサーを取り付けてから装着して下さい。

![SIOゲタ装着1](/img/020.jpg)

装着時にピンズレ防止のため側面からLEDライト等を照らして明るくして装着作業するのが良いと思います。

![SIOゲタ装着2](/img/018.jpg)

これは「ピンズレ」した状態での装着結果です。GND/+5V/+12V/-12Vの接続がズレます。これでPC-8001本体電源入れると一発で機器破損の恐れあります。ピンズレ/列ズレには注意して下さい。

![SIOゲタ装着3](/img/019.jpg)

## 10.2764ROMゲタ装着

PC-8001電源切状態で行います。手前側をIC13 Socketに挿します。

![ROMゲタ装着1](/img/033.jpg)

そのまま手前側を押し下げながら手前に引っ張りる感じで奥側を挿します。

![ROMゲタ装着2](/img/034.jpg)

![ROMゲタ装着3](/img/035.jpg)

## 11.PC-8001 SIO 通信速度設定

PC-8001電源切状態で行います。CN8は、お持ちのPC-8001で製造から40数年後に初めて動かすロック機構になるかも知れません。硬めのロックです。ロック解除は上へ引き上げます。

![速度設定1](/img/015.jpg)

元々1-6短絡設定(300bps)してあるジャンパー線を1-2短絡設定(4800bps)に変えます。設定後ロック(ロック機構を下へ押し下げます)します。

![速度設定2](/img/016.jpg)

![速度設定3](/img/017.jpg)

CN8設定内容

    1-2: x16モード 4800 , x64モード 1200
    1-3: x16モード 2400 , x64モード  600
    1-4: x16モード 1200 , x64モード  300
    1-5: x16モード  600 , x64モード  150
    1-6: x16モード  300 , x64モード   75

x16モード/x64モードはuPD8251のレジスタのx16モード/x64モードを示します。CMTロード/セーブの速度600ボーとは独立設定です。

## 12.動作確認

キーボードユニットを装着無しでモニタ装着で確認します。PC-8001本体の電源を入れてAMS1117-3.3V降圧型モジュールのLEDが点灯するのを確認します。モニタにも初期状態表示されるのを確認します。点灯しない。焦げ臭い。煙が出る。等の異常がある時は即座に電源を切って火災発生案件に成らないように注意して下さい。

![動作確認1](/img/058.jpg)

![動作確認2](/img/059.jpg)

AMS1117-3.3V降圧型モジュールのLEDが点灯し臭い発煙/発火等なければいったんPC-8001本体の電源を切ってキーボードユニットを装着しネジ締めしない状態で電源入れます。

mon<RETURN>と入力してD6000とD7FF0を入力し2764ROM領域をダンプします。BASICプロンプトへ復帰するにはCTRL+Bです。2764ROMが正常に書き込まれているか確認します。600DH,600EH,600FHはバージョン値を示すため今後の更新内容によって変化します。

![動作確認3](/img/060.jpg)

cmd ver<RETURN>と入力しバージョン表記されるか確認します。

![動作確認4](/img/061.jpg)

ここで示されるv1.0.0の数値は今後の更新内容によって変化します。SIOゲタ上の赤タクトスイッチを押してリセットをかけたのちにcmd ver<RETURN>と入力してバージョン表記されるか確認します。初回応答時間が3秒〜5秒程度無いのは正常です。ESP32側の初回NTPクライアント定義/動作開始/初回受信/自己RTC初期化に要する時間です。PC-8001本体の電源を切って最低5秒は待ってから電源を入れます。BASICプロンプトが出たら再度cmd ver<RETURN>と入力してバージョン表記されるか確認します。

お使いのPC-8001本体ROMがVer 1.0の場合はPC-8001本体電源投入にて拡張コマンドcmdが使えません。本体ROMプログラムのバグの為です。mon<RETURN> CTRL+Bで拡張コマンドcmdが使えるようにしています。お手数ですがPC-8001本体ROMがVer 1.0の場合は初回電源投入後mon<RETURN> CTRL+Bを実施して下さい。

## 13.PC-8001側拡張コマンド操作

利用可能な拡張コマンドと動作を示します。

cmd ver  
SIOゲタ上ESP32-WROOM-32内ファームと2764ROM内ファームのバージョン表示を行います。

cmd sntp  
PC-8001側の日時設定を行います。

cmd bme  
SIOゲタ上BME280より情報取得し表示します。温度/湿度/気圧です。BME280配置位置がCRTCの上近くのため温度(気温)として高めの計測になります。部品配置のレイアウト(ミンティア基板 for ESP-WROOM-32の配置向き、PC-8001電源ユニットとの接触干渉なども考慮要)を変えると良いかもしれません。ESP32-WROOM-32のGPIOの空きはまだあるので熱電対を複数追加もアリかもです。ペンレコ実装か(笑) BASIC言語変数への代入のための処理等は実装していません。BASICプログラムよりコマンド実行する事は出来ます。

cmd ftplist  
SIOゲタ上ESP32-WROOM-32のWiFi機能を使って定義されたftpサーバーの定義されたディレクトリ内容を取得し表示します。0基点通番付きで表示します。表示中ESCキー押しっぱで表示一時停止します。表示中STOPキー押下で表示停止します。画面サイズが広い場合ftpサーバーから取得したファイルパーミッションよりアクセス権/ファイルサイズ(byte単位)/最終更新日時(UNIX表示形式)/ファイル名を表示します。画面サイズが狭い場合はftpサーバーから取得したファイルパーミッションよりファイル名を表示します。漢字表示(JIS/EUC/ShiftJIS/UTF-8/等)は不可です。ftpサーバー側のファイル名定義には注意して下さい。

cmd ftpget,NNN,XXXX  
ftplistで0基点通番の番号を指定してftpダウンロードGETを行いxmodem sum(128byte単位) プロトコルでバイナリ受信します。メモリロード中の確定した範囲表示を行います。STOPキー押下にてメモリロードを中止します。ロード対象がcmtファイルでBASIC言語と判定される場合適切なメモリへロードします。ロード対象がcmtファイルでマシン語と判定される場合適切なメモリへロードします。多段ロード形式のcmtは現時点(2022/09/17)では対応していません。多段ロード形式でキーバッファを活用する形式の場合いったんBASIC側へ移行してしまい継続フックの手段が無いのです(泣ｗ) 多段ロード形式のcmtは現時点(2022/09/17)での実装は最終ロード対象がロードされます。

以下、コマンド実行例です。  

対象がBASIC言語cmtの場合

    cmd ftpget,000<RETURN>

対象がマシン言語cmtの場合

    cmd ftpget,001<RETURN>

対象がマシン言語cmtで実行開始アドレスがE3CCHの場合

    cmd ftpget,002,&He3cc<RETURN>

対象が不特定(任意のバイナリをとにかく特定のメモリへ入れたい)でロード開始アドレスをC000Hとした場合

    cmd ftpget,003,&Hc000<RETURN>

## 14.問題点

使えるコマンドリストを忘れそう。  
使っててそのように思いました。cmd help<RETURN>で利用できるコマンドリスト表示があったほうが良い気がします。

BASIC言語のcmtをcmd ftpgetで連続すると暴走する。  
NEW<RETURN>して下さい。cmd ftpgetの処理シーケンスの最初でNEWを実装しようかどうか悩みました。基礎的操作はユーザー任せが良いと判断して暴走するを選択しました(笑)

マシン語のcmtでScrambleがロード出来ない。  
現時点(2022/09/17)の対策はScrambleをC000H〜E9FFHで保存したcmtにして下さい。問題はxmodem sum(128byte単位) プロトコル受信からのメモリ転送にあります。オリジナルScrambleはC010H〜E9FFHです。128byte単位のパケットにすると最終パケットがE990H〜EA0FHになってEA00Hに入り込もうとするためメモリオーバー判定でメモリロードを停止するためです。同様な動作になってロード出来ないcmtあると思います。つたないファームで申し訳ないです。改修項目としてリストに上げています。

## 15.最後に

PC-8001 SIOゲタも第四形態で終了かと思いきや旧友からは「俺のPC-8001mkIIで使えるようにしてくれ。D-SUB25にさガチャと装着でよろ〜」と軽く言ってくれてPC-8001mkII本体の補修までお願いされてしまいました。20年近く押入れで寝かしてたらしいです(笑) そのPC-8001mkII機補修作業で資料整備が遅れました。

CMTロードよりは早いですが4800bpsはやっぱり遅いです。速度優先で永続利用を考えるとSDカードよりロードできるリポジトリが他にありますのでそちらを利用するのが良いと思います。

ただ面白かったのは近所の子供/孫たち入れた夏季休暇中レトロゲーム大会開催でロード中の画面がとても不思議らしく見入ってました。しかし慣れてくると「早く、早く、早く」と祭りばやし状態で踊りまくってワロタでした(^◇^;)
