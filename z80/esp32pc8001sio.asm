;********************************************************************************
;
; Created by tan (trinity09181718@gmail.com)
; Copyright (c) 2022 tan
; All rights reserved.
;
; Please contact trinity09181718@gmail.com if you need a commercial license.
; This software is available under GPL v3.
;
;********************************************************************************
;
; Implementation contents as N-BASIC command extension
;
; CMD BME
; CMD FTPLIST
; CMD FTPGET,nnn
; CMD FTPGET,nnn,&hXXXX
; CMD SNTP
; CMD SPILIST
; CMD SPIGET,nnn
; CMD SPIGET,nnn,&hXXXX
; CMD VER
;
; Implementation contents as N80-BASIC command extension
;
; MAT BME
; MAT FTPLIST
; MAT FTPGET,nnn
; MAT FTPGET,nnn,&hXXXX
; MAT SNTP
; MAT SPILIST
; MAT SPIGET,nnn
; MAT SPIGET,nnn,&hXXXX
; MAT VER
;
;********************************************************************************
; 更新履歴
; 2022/10/10 v1.0.2 PC-8001mkIIにてRS-232C受信割込テーブル位置(8000H,8001H)を書換え
;                   られるタイプのバイナリ受信処理対応(確認不足)
;                   (cmt Planet Taizer:8000H~E7FFHが顕著)
;                   多段ロード形式cmtファイル対応
; 2022/10/01 v1.0.1 spiffs関連実装
;                   PC-8001とPC-8001mkIIのboot判定とフックコマンドの切り替え
;                   PC-8001mkII RS-232C 受信割込9600bps実装
;                   cmd ftpget or mat ftpget or cmd spiget or mat spigetにて
;                   PC-8001時EA00H or PC-8001mkII E600H 以上に入りこむメモリー
;                   オーバー判定と受信不良の不具合改修
;                   (cmt Scramble:C010H~E9FFHが顕著)
;                   cmd sntp or mat sntp で月がBCDとして設定されてしまう不具合改修
; 2022/09/17 v1.0.0 リリース
; 2022/08/07 v1.0.0 GitHub 公開
;********************************************************************************
;
; CONSTANT CONTROL CODE
;
NUL:            EQU     00H
SOH:            EQU     01H
STX:            EQU     02H
EOT:            EQU     04H
ACK:            EQU     06H
BS:             EQU     08H
LF:             EQU     0AH
CR:             EQU     0DH
NAK:            EQU     15H
CAN:            EQU     18H
ESC:            EQU     1BH
;
; CONSTANT I/O PORT
;
KEYBRD9:        EQU     09H
USARTDW:        EQU     20H
USARTCW:        EQU     21H             ; MODE SETUP
                                        ; 76543210
                                        ; ||||||++--- BAUD RATE FACTOR
                                        ; ||||||      00 : SYNC MODE
                                        ; ||||||      01 : 1X
                                        ; ||||||      10 : 16X
                                        ; ||||||      11 : 64X
                                        ; ||||++----- CHARACTER LENGTH
                                        ; ||||        00 : 5BITS
                                        ; ||||        01 : 6BITS
                                        ; ||||        10 : 7BITS
                                        ; ||||        11 : 8BITS
                                        ; |||+------- PARITY ENABLE
                                        ; |||         1 : ENABLE
                                        ; |||         0 : DISABLE
                                        ; ||+-------- EVEN PARITY GENARATION/CHECK
                                        ; ||          1 : EVEN
                                        ; ||          0 : ODD
                                        ; ++--------- NUMBER OF STOP BITS
                                        ;             00 : INVALID
                                        ;             01 : 1 BIT
                                        ;             10 : 1.5 BITS
                                        ;             11 : 2 BITS
                                        ;
                                        ; COMMAND SETUP
                                        ; 76543210
                                        ; |||||||+--- TRANSMIT ENABLE
                                        ; |||||||     1 : ENABLE
                                        ; |||||||     0 : DISABLE
                                        ; ||||||+---- DATA TERMINAL READY
                                        ; ||||||      "high" will force ~DTR output zero
                                        ; |||||+----- RECEIVE ENABLE
                                        ; |||||       1 : ENABLE
                                        ; |||||       0 : DISABLE
                                        ; ||||+------ SEND BREAK CHARACTER
                                        ; ||||        1 : forces TxD "low"
                                        ; ||||        0 : normal operation
                                        ; |||+------- ERROR RESET
                                        ; |||         1 : reset all error flags PE,OE,FE
                                        ; ||+-------- REQUEST TO SEND
                                        ; ||          "high" will force ~RTS output zero
                                        ; |+--------- INTERNAL RESET
                                        ; |           "high" returns USART to Mode Instruction Format
                                        ; +---------- ENTER HUNT MODE
                                        ;             1 = enable search for Sync Characters
                                        ;
                                        ; STATUS READ
                                        ; 76543210
                                        ; |||||||+--- TxRDY
                                        ; ||||||+---- RxRDY
                                        ; |||||+----- TxEMPTY
                                        ; ||||+------ PE(PARITY ERROR)
                                        ; |||+------- OE(OVERRUN ERROR)
                                        ; ||+-------- FE(FRAMING ERROR)
                                        ; |+--------- SYNDET
                                        ; +---------- DSR
CONTROL1:       EQU     30H
INTLEVEL:       EQU     0E4H
INTMASK:        EQU     0E6H
;
; CONSTANT PC-8001mkII ROM BASIC CMD ENTRY
;
PC8001MK2_NMODE:        EQU     1875H
PC8001MK2_N80MODE:      EQU     0E730H
;
; CONSTANT ROM BASIC ROUTINE
;
ROM_BASPROMPT:  EQU     0081H
ROM_DSPCHR:     EQU     0257H
ROM_MOVECURSOR: EQU     03A9H
ROM_DSPCURSOR:  EQU     0BE2H
ROM_BEEP:       EQU     0D43H
ROM_KEYWAIT:    EQU     0F75H
ROM_KEYSCAN:    EQU     0FACH
ROM_TIMEREAD:   EQU     1602H
ROM_TIMEWRITE:  EQU     1663H
ROM_PC8001CHK:  EQU     175FH
ROM_BIN2DECASC: EQU     309FH
ROM_SYNERR:     EQU     3BDFH
ROM_MSGOUT:     EQU     52EDH
ROM_MON_UNEXT:  EQU     5C35H
ROM_HEXASC2BIN: EQU     5E4BH
ROM_DSPHEX4:    EQU     5EC0H
ROM_CMPHLDE:    EQU     5ED3H
ROM_DSP1CHR:    EQU     5FB0H
ROM_DSPCRLF:    EQU     5FCAH
;
; CONSTANT ROM BASIC WORK AREA
;
PC8001RAM_TOP:  EQU     8000H
VECTOR_TBL_SIO: EQU     8000H
N80ROM_WORKTOP: EQU     0E600H
NROM_WORKTOP:   EQU     0EA00H
LAST_INTLEVEL:  EQU     0EA55H
FLG_INTEXEC:    EQU     0EA56H
FUNKEY_DISPSTS: EQU     0EA60H
CRT_TEXT_ROWS:  EQU     0EA62H
CURSOR_YPOS:    EQU     0EA63H
CURSOR_XPOS:    EQU     0EA64H
CRT_TEXT_COLS:  EQU     0EA65H
CTL1_OUTDATA:   EQU     0EA66H
FUNCKEY_FLAG:   EQU     0EA68H
BCD_TIME_SEC:   EQU     0EA76H
BCD_TIME_YEAR:  EQU     0EA7BH
FUNCKEY_DATA:   EQU     0EAC0H
OUTPUT_DEVICE:  EQU     0EB49H
BASAREA_TOP:    EQU     0EB54H
FUNCKEY_PTR:    EQU     0EDC0H
RS232C_CH1BUF:  EQU     0EDCEH                  ; AREA DS 128
RS232C_CH2BUF:  EQU     0EE4EH                  ; AREA DS 128
VARAREA_TOP:    EQU     0EFA0H
ARRAYAREA_TOP:  EQU     0EFA2H
FREEAREA_TOP:   EQU     0EFA4H
BIN_ACC:        EQU     0F0A8H
CMD_ENTRY:      EQU     0F0FCH
MAT_ENTRY:      EQU     0F111H
;
; N-BASIC ROM FREE AREA1 : F216~F2FF
; N-BASIC ROM FREE AREA2 : FF3D~FFFF
; CONSTANT ESP32PC8001SIO WORK AREA
;
SAVESP:         EQU     0F216H                  ; WORD DW
LISTCNT:        EQU     0F218H                  ; WORD DW
SELLISTNO:      EQU     0F21AH                  ; WORD DW
LOADADRS:       EQU     0F21CH                  ; WORD DW
EXECADRS:       EQU     0F21EH                  ; WORD DW
LOAD_ENDADRS:   EQU     0F220H                  ; WORD DW   
LOADSIZE:       EQU     0F222H                  ; WORD DW
SAVESIOIRQ:     EQU     0F224H                  ; WORD DW
ROM_WORKTOP:    EQU     0F226H                  ; WORD DW
EXT_ENTRY:      EQU     0F228H                  ; WORD DW
DIVICOUNT:      EQU     0F22AH                  ; WORD DW
SELDIVINO:      EQU     0F22CH                  ; WORD DW
EXECADRS2:      EQU     0F22EH                  ; WORD DW
MODEWORD:       EQU     0F230H                  ; BYTE DB
CTLWORD:        EQU     0F231H                  ; BYTE DB
EXTNO:          EQU     0F232H                  ; BYTE DB
CHKBLKNO:       EQU     0F233H                  ; BYTE DB
LFRECVCOUNT:    EQU     0F234H                  ; BYTE DB
RCVBUF_RPOS:    EQU     0F235H                  ; BYTE DB
RCVBUF_WPOS:    EQU     0F236H                  ; BYTE DB
SAVE_ENTRY:     EQU     0F237H                  ; AREA DS 3
DISPBUF_TOP:    EQU     0F240H                  ; AREA DS
FLGDATA:        EQU     0F2FFH                  ; BYTE DB       76543210
                                                ;               |||||||+--- <CR><LF> first send
                                                ;               ||||||+---- load basic cmt type       
                                                ;               |||||+----- sio recv time out (5sec)
                                                ;               ||||+------ sio recv cancel (keyboard STOP key)
                                                ;               |||+------- enable keyboard STOP key check
                                                ;               ||+-------- exec machine PC-8001
                                                ;               |+--------- reserve
                                                ;               +---------- reserve
FLG_FIRSTSEND:  EQU     00000001B
FLG_LOADBAS:    EQU     00000010B
FLG_RCVTIMEOUT: EQU     00000100B
FLG_RCVCANCEL:  EQU     00001000B
FLG_ENABLESTOP: EQU     00010000B
FLG_EXECPC8001: EQU     00100000B
;
SNDBUF_TOP:     EQU     RS232C_CH1BUF           ; AREA DS
RCVBUF_TOP:     EQU     RS232C_CH1BUF           ; AREA DS
RCVBUF_HEADER:  EQU     RS232C_CH1BUF           ; BYTE DB
RCVBUF_BLKNO:   EQU     RS232C_CH1BUF +1        ; BYTE DB
RCVBUF_CBLKNO:  EQU     RS232C_CH1BUF +2        ; BYTE DB
RCVBUF_DATA:    EQU     RS232C_CH1BUF +3        ; AREA DS
RCVBUF_CHKSUM:  EQU     RCVBUF_DATA +128        ; BYTE DB
RCVBUF_BOTTOM:  EQU     RCVBUF_CHKSUM           ; BYTE DB
;
; CONSTANT ESP32PC8001SIO VERSION DATA
;
VER_MAJOR:      EQU     1
VER_MINOR:      EQU     0
VER_REVISION:   EQU     2
;
                ;ORG    0H
;
;
;
EXT_START:                                      ; SP RETURN ADRS
                PUSH    BC
                PUSH    DE
                CALL    PARSER_EXTPARAM
                POP     DE
                POP     BC
                JR      C,EXT_NON
                DI
                LD      (SAVESP),SP
                EX      DE,HL
                LD      HL,0FFFFH
                LD      SP,HL
                EX      DE,HL
                EI
                JP      (IY)
EXT_NON:
                LD      IX,(SAVE_ENTRY + 1)     ; IX -> ORIGINAL ENTRY
                                                ; STACK DATA RETURN ADRS HOLD
                JP      (IX)                    ; JUMP ORIGINAL ENTRY
EXT_EXIT:
                XOR     A
                JR      EXT_010
EXT_MYERR_EXIT:
                LD      A,1
                LD      IX,ROM_BASPROMPT        ; IX -> (SP) RETURN ADRS
                JR      EXT_010
EXT_DLEXEC_EXIT:
                LD      A,2
                LD      IX,(EXECADRS)           ; IX -> (SP) RETURN ADRS
EXT_010:
                DI
                EX      DE,HL
                LD      HL,(SAVESP)
                LD      SP,HL
                EX      DE,HL
                EI
                CP      0
                RET     Z
                DI
                EX      (SP),IX                 ; STACK DATA RETURN ADRS CHANGE        
                EI
                RET
;
;
;
ENTRY_SETUP:
                PUSH    BC
                PUSH    DE
                PUSH    HL
                XOR     A
                LD      (FLGDATA),A
                LD      HL,0
                LD      (EXT_ENTRY),HL
                LD      A,(ROM_PC8001CHK)
                CP      80H             ; N-BASIC IMPLEMENTED IN PC-8001
                JR      Z,ENTRY_SETUP_020
                CP      0AFH            ; N-BASIC IMPLEMENTED IN PC-8001mkII
                JR      Z,ENTRY_SETUP_010
                JR      ENTRY_SETUP_080
ENTRY_SETUP_010:
                LD      HL,(CMD_ENTRY + 1)
                LD      DE,PC8001MK2_N80MODE
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                JR      Z,ENTRY_SETUP_030
ENTRY_SETUP_020:
                LD      HL,CMD_ENTRY
                LD      (EXT_ENTRY),HL
                JR      ENTRY_SETUP_040
ENTRY_SETUP_030:
                LD      HL,MAT_ENTRY
                LD      (EXT_ENTRY),HL
ENTRY_SETUP_040:
                LD      HL,(EXT_ENTRY)
                LD      DE,NEWJPTBL
                LD      B,3
ENTRY_SETUP_L010:
                LD      C,(HL)
                LD      A,(DE)
                CP      C
                JR      NZ,ENTRY_SETUP_050
                INC     HL
                INC     DE
                DJNZ    ENTRY_SETUP_L010
                JR      ENTRY_SETUP_080
ENTRY_SETUP_050:
                LD      HL,(EXT_ENTRY)
                LD      DE,SAVE_ENTRY
                LD      B,3
ENTRY_SETUP_L020:
                LD      C,(HL)
                LD      A,(DE)
                CP      C
                JR      NZ,ENTRY_SETUP_060
                INC     HL
                INC     DE
                DJNZ    ENTRY_SETUP_L020
                JR      ENTRY_SETUP_070
ENTRY_SETUP_060:
                LD      HL,(EXT_ENTRY)
                LD      DE,SAVE_ENTRY
                LD      BC,3
                LDIR
ENTRY_SETUP_070:
                LD      HL,NEWJPTBL
                LD      DE,(EXT_ENTRY)
                LD      BC,3
                LDIR
ENTRY_SETUP_080:
                POP     HL
                POP     DE
                POP     BC
                RET
;
;
;
EXT_BME:
                PUSH    HL
                CALL    INIT_SIO
                JP      C,EXT_ERR5
                LD      HL,TBL_EXT_BME
                LD      DE,SNDBUF_TOP
                LD      BC,3
                LDIR
                LD      HL,TBL_CRLF
                LD      BC,2
                LDIR
                LD      B,5
                CALL    SENDBUF_OUT
                LD      B,1
                CALL    RECVBUF_IN
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                JP      NZ,EXT_ERR1
                LD      DE,TBL_EXT_BME
                LD      B,3
                CALL    RECVBUF_CHK
                JP      C,EXT_ERR2
                LD      B,0
                CALL    EXT_BME_MSG
                LD      B,1
                CALL    EXT_BME_MSG
                LD      B,2
                CALL    EXT_BME_MSG
                JP      EXT_END
EXT_BME_MSG:
                PUSH    HL
                LD      A,B
                CP      1
                JR      Z,EXT_BME_000
                CP      2
                JR      Z,EXT_BME_010
                LD      HL,TBL_TEMP_MSG0
                JR      EXT_BME_020
EXT_BME_000:
                LD      HL,TBL_HUMI_MSG0
                JR      EXT_BME_020
EXT_BME_010:
                LD      HL,TBL_PRESS_MSG0
EXT_BME_020:
                LD      DE,DISPBUF_TOP
EXT_BME_L010:
                LD      A,(HL)
                LD      (DE),A
                INC     HL
                INC     DE
                CP      0
                JR      NZ,EXT_BME_L010
                POP     HL
                DEC     DE
EXT_BME_L020:
                LD      A,(HL)
                CP      ','
                JR      Z,EXT_BME_050
                CP      CR
                JR      Z,EXT_BME_050
                LD      (DE),A
                INC     HL
                INC     DE
                JR      EXT_BME_L020
EXT_BME_050:
                INC     HL
                PUSH    HL
                LD      A,B
                CP      1
                JR      Z,EXT_BME_060
                CP      2
                JR      Z,EXT_BME_070
                LD      HL,TBL_TEMP_MSG1
                JR      EXT_BME_L030
EXT_BME_060:
                LD      HL,TBL_HUMI_MSG1
                JR      EXT_BME_L030
EXT_BME_070:
                LD      HL,TBL_PRESS_MSG1
EXT_BME_L030:
                LD      A,(HL)
                LD      (DE),A
                INC     HL
                INC     DE
                CP      0
                JR      NZ,EXT_BME_L030
                POP     HL
                DEC     DE
                PUSH    BC
                PUSH    DE
                PUSH    HL
                CALL    MSG_DISP
                POP     HL
                POP     DE
                POP     BC
                RET
;
;
;
EXT_FTPLIST:
                PUSH    HL
                CALL    INIT_SIO
                JP      C,EXT_ERR5
                LD      HL,TBL_EXT_FTPLIST2
                LD      DE,SNDBUF_TOP
                LD      BC,7
                LDIR
                LD      HL,TBL_CRLF
                LD      BC,2
                LDIR
                LD      B,9
                CALL    SENDBUF_OUT
                LD      B,1
                CALL    RECVBUF_IN
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                JP      NZ,EXT_ERR1
                LD      DE,TBL_EXT_FTPLIST2
                LD      B,7
                CALL    RECVBUF_CHK
                JP      C,EXT_ERR2
EXT_FTPLIST_000:
                PUSH    HL
                LD      HL,TBL_COUNT_MSG0
                LD      DE,DISPBUF_TOP
EXT_FTPLIST_L000:
                LD      A,(HL)
                LD      (DE),A
                INC     HL
                INC     DE
                CP      0
                JR      NZ,EXT_FTPLIST_L000
                DEC     DE
                POP     HL
                PUSH    HL
                LD      BC,3
                LDIR
                CALL    MSG_DISP
                POP     HL
;
                LD      A,(HL)
                AND     0FH
                LD      E,A
                LD      A,100
                PUSH    HL
                CALL    MUL_88_2_16
                LD      (LISTCNT),HL
                POP     HL
                INC     HL
                LD      A,(HL)
                AND     0FH
                LD      E,A
                LD      A,10
                PUSH    HL
                CALL    MUL_88_2_16
                EX      DE,HL
                LD      HL,(LISTCNT)
                ADD     HL,DE
                LD      (LISTCNT),HL
                POP     HL
                INC     HL
                LD      A,(HL)
                AND     0FH
                LD      E,A
                LD      A,1
                PUSH    HL
                CALL    MUL_88_2_16
                EX      DE,HL
                LD      HL,(LISTCNT)
                ADD     HL,DE
                LD      (LISTCNT),HL
                POP     HL
                LD      HL,(LISTCNT)
                LD      DE,0
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                JP      Z,EXT_END
                LD      (SELLISTNO),DE
EXT_FTPLIST_L010:
                XOR     A
                LD      (RCVBUF_RPOS),A
                LD      (RCVBUF_WPOS),A
                LD      HL,DISPBUF_TOP
                LD      DE,(SELLISTNO)
                LD      (BIN_ACC),DE
                LD      BC,0
                CALL    ROM_BIN2DECASC
                LD      HL,TBL_EXT_LIST
                LD      DE,SNDBUF_TOP
                LD      BC,5
                LDIR
                LD      HL,DISPBUF_TOP + 2
                LD      BC,3
                LDIR
                LD      HL,TBL_CRLF
                LD      BC,2
                LDIR
                LD      B,10
                CALL    SENDBUF_OUT
                LD      B,1
                CALL    RECVBUF_IN
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                JP      NZ,EXT_ERR1
                LD      DE,TBL_EXT_LIST
                LD      B,4
                CALL    RECVBUF_CHK
                JP      C,EXT_ERR2
                LD      DE,DISPBUF_TOP
                LD      BC,3
                LDIR
                LD      A,':'
                LD      (DE),A
                INC     DE
                LD      A,(CRT_TEXT_COLS)
                CP      72
                JR      Z,EXT_FTPLIST_040
                CP      80
                JR      Z,EXT_FTPLIST_040
                LD      B,4
EXT_FTPLIST_010:
                LD      A,(HL)
                INC     HL
                CP      ','
                JR      Z,EXT_FTPLIST_020
                JR      EXT_FTPLIST_010
EXT_FTPLIST_020:
                DJNZ    EXT_FTPLIST_010
EXT_FTPLIST_030:
                LD      A,(HL)
                LD      (DE),A
                INC     HL
                INC     DE
                CP      CR
                JR      Z,EXT_FTPLIST_070
                JR      EXT_FTPLIST_030
EXT_FTPLIST_040:
                INC     HL
EXT_FTPLIST_L020:
                LD      A,(HL)
                CP      ','
                JR      Z,EXT_FTPLIST_050
                CP      CR
                JR      Z,EXT_FTPLIST_070
                JR      EXT_FTPLIST_060
EXT_FTPLIST_050:
                LD      A,' '
EXT_FTPLIST_060:
                LD      (DE),A
                INC     HL
                INC     DE
                JR      EXT_FTPLIST_L020
EXT_FTPLIST_070:
                CALL    MSG_DISP
                IN      A,(KEYBRD9)
                LD      D,A
                AND     00000001B
                JP      Z,EXT_END
                LD      A,D
                AND     10000000B
                JR      NZ,EXT_FTPLIST_090
EXT_FTPLIST_080:
                IN      A,(KEYBRD9)
                LD      D,A
                AND     00000001B
                JP      Z,EXT_END
                LD      A,D
                AND     10000000B
                JR      Z,EXT_FTPLIST_080
EXT_FTPLIST_090:
                LD      HL,(LISTCNT)
                LD      DE,(SELLISTNO)
                INC     DE
                LD      (SELLISTNO),DE
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                JP      NZ,EXT_FTPLIST_L010
                JP      EXT_END
;
;
;
EXT_FTPGET:
                PUSH    HL
                CALL    INIT_SIO
                JP      C,EXT_ERR5
                LD      HL,DISPBUF_TOP
                LD      DE,(SELLISTNO)
                LD      (BIN_ACC),DE
                LD      BC,0
                CALL    ROM_BIN2DECASC
                LD      HL,TBL_EXT_FTPGET2
                LD      DE,SNDBUF_TOP
                LD      BC,7
                LDIR
                LD      HL,DISPBUF_TOP + 2
                LD      BC,3
                LDIR
                LD      HL,TBL_CRLF
                LD      BC,2
                LDIR
                LD      B,12
                CALL    SENDBUF_OUT
                LD      B,1
                CALL    RECVBUF_IN
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                JP      NZ,EXT_ERR1
                LD      DE,TBL_EXT_FTPGET2
                LD      B,6
                CALL    RECVBUF_CHK
                JP      C,EXT_ERR2
EXT_FTPGET_000:
                INC     HL
                INC     HL
                INC     HL
                INC     HL
                LD      A,(HL)
                AND     0FH
                CP      0               ; ERROR
                JP      Z,EXT_ERR3
                CP      1               ; OK
                JP      Z,EXT_FTPGET_010
                JP      EXT_ERR2
EXT_FTPGET_010:
                INC     HL
                INC     HL
                LD      B,3
                LD      DE,0
EXT_FTPGET_020:
                LD      A,(HL)
                PUSH    HL
                EX      DE,HL
                CALL    ROM_HEXASC2BIN
                EX      DE,HL
                POP     HL
                INC     HL
                DJNZ    EXT_FTPGET_020
                LD      (DIVICOUNT),DE
                LD      HL,0
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                JP      Z,EXT_ERR2
                INC     HL
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                JR      Z,EXT_FTPGET_030
                LD      DE,1
                JR      EXT_FTPGET_040
EXT_FTPGET_030:
                LD      DE,0
EXT_FTPGET_040:
                LD      (SELDIVINO),DE
EXT_FTPGET_050:
                LD      HL,DISPBUF_TOP
                LD      DE,(SELLISTNO)
                LD      (BIN_ACC),DE
                LD      BC,0
                CALL    ROM_BIN2DECASC
                LD      HL,DISPBUF_TOP + 5
                LD      DE,(SELDIVINO)
                LD      (BIN_ACC),DE
                LD      BC,0
                CALL    ROM_BIN2DECASC
                LD      HL,TBL_EXT_GET
                LD      DE,SNDBUF_TOP
                LD      BC,4
                LDIR
                LD      HL,DISPBUF_TOP + 2
                LD      BC,3
                LDIR
                LD      A,','
                LD      (DE),A
                INC     DE
                LD      HL,DISPBUF_TOP + 7
                LD      BC,3
                LDIR
                LD      HL,TBL_CRLF
                LD      BC,2
                LDIR
                LD      B,13
                CALL    SENDBUF_OUT
                LD      B,1
                CALL    RECVBUF_IN
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                JP      NZ,EXT_ERR1
                LD      DE,TBL_EXT_GET
                LD      B,3
                CALL    RECVBUF_CHK
                JP      C,EXT_ERR2
                INC     HL
                INC     HL
                INC     HL
                INC     HL
                INC     HL
                INC     HL
                INC     HL
                INC     HL
                LD      A,(HL)          ; RESULT
                AND     0FH
                CP      0               ; ERROR
                JP      Z,EXT_ERR3
                CP      1               ; OK
                JP      Z,EXT_FTPGET_060
                JP      EXT_ERR2
EXT_FTPGET_060:
                INC     HL
                INC     HL
                LD      A,(HL)          ; DATA TYPE
;
                PUSH    AF
                INC     HL
                INC     HL
                LD      B,4
                LD      DE,0
EXT_FTPGET_L010:
                LD      A,(HL)
                PUSH    HL
                EX      DE,HL
                CALL    ROM_HEXASC2BIN
                EX      DE,HL
                POP     HL
                INC     HL
                DJNZ    EXT_FTPGET_L010
                LD      (LOADADRS),DE
                INC     HL
                LD      B,4
                LD      DE,0
EXT_FTPGET_L020:
                LD      A,(HL)
                PUSH    HL
                EX      DE,HL
                CALL    ROM_HEXASC2BIN
                EX      DE,HL
                POP     HL
                INC     HL
                DJNZ    EXT_FTPGET_L020
                LD      (LOAD_ENDADRS),DE
                INC     HL
                LD      B,4
                LD      DE,0
EXT_FTPGET_L030:
                LD      A,(HL)
                PUSH    HL
                EX      DE,HL
                CALL    ROM_HEXASC2BIN
                EX      DE,HL
                POP     HL
                INC     HL
                DJNZ    EXT_FTPGET_L030
                LD      (EXECADRS2),DE
                PUSH    HL
                LD      HL,(LOAD_ENDADRS)
                LD      DE,(LOADADRS)
                CALL    CLRCFRET
                SBC     HL,DE
                INC     HL        
                LD      (LOADSIZE),HL
                POP     HL
                POP     AF
;
                AND     0FH
                CP      0               ; ERROR
                JP      Z,EXT_ERR3
                CP      1               ; ANY BIN
                JP      Z,EXT_FTPGET_100
                CP      2               ; BASIC BIN
                JR      Z,EXT_FTPGET_110
                CP      3               ; Z80 BIN
                JR      Z,EXT_FTPGET_200
                JP      EXT_ERR2
EXT_FTPGET_100:
                LD      DE,(EXECADRS)
                PUSH    HL
                LD      HL,0
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                POP     HL
                JP      Z,EXT_ERR4
                LD      (LOADADRS),DE
                PUSH    DE
                LD      DE,0
                LD      (EXECADRS),DE
                POP     DE
                JR      EXT_FTPGET_200
EXT_FTPGET_110:
                LD      A,(FLGDATA)
                OR      FLG_LOADBAS
                LD      (FLGDATA),A
                LD      DE,(BASAREA_TOP)
                LD      (LOADADRS),DE
EXT_FTPGET_200:
                LD      A,(FLGDATA)
                OR      FLG_ENABLESTOP
                LD      (FLGDATA),A
                LD      A,1
                LD      (CHKBLKNO),A
EXT_FTPGET_L040:
                XOR     A
                LD      (RCVBUF_RPOS),A
                LD      (RCVBUF_WPOS),A
                LD      A,NAK
                CALL    OUT_SIO
EXT_FTPGET_L050:
                CALL    IN_SIO
                CP      EOT
                JP      Z,EXT_FTPGET_310
                CP      SOH
                JR      Z,EXT_FTPGET_210
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                JR      NZ,EXT_FTPGET_L040
                LD      A,(FLGDATA)
                AND     FLG_RCVCANCEL
                JP      NZ,EXT_FTPGET_CANCEL
                JR      EXT_FTPGET_L050
EXT_FTPGET_L060:
                CALL    IN_SIO
                CP      EOT
                JP      Z,EXT_FTPGET_310
                CP      SOH
                JR      Z,EXT_FTPGET_210
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                JP      NZ,EXT_FTPGET_CANCEL
                LD      A,(FLGDATA)
                AND     FLG_RCVCANCEL
                JP      NZ,EXT_FTPGET_CANCEL
                JR      EXT_FTPGET_L060
EXT_FTPGET_210:
                CALL    CLR_RCVBUF
                LD      (HL),A
                INC     HL
                LD      B,131
EXT_FTPGET_L070:
                CALL    IN_SIO
                LD      C,A
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                JP      NZ,EXT_FTPGET_CANCEL
                LD      A,(FLGDATA)
                AND     FLG_RCVCANCEL
                JP      NZ,EXT_FTPGET_CANCEL
                LD      A,C
                LD      (HL),A
                INC     HL
                DJNZ    EXT_FTPGET_L070
;
                XOR     A
                LD      (RCVBUF_RPOS),A
                LD      (RCVBUF_WPOS),A
                CALL    DISABLE_RTS
                CALL    CHK_RCVDATA
                JR      C,EXT_FTPGET_300
                PUSH    DE
                LD      HL,(LOADSIZE)
                LD      DE,128
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                JR      C,EXT_FTPGET_220
                PUSH    DE
                POP     HL
EXT_FTPGET_220:
                PUSH    HL
                POP     BC
                POP     DE
                CALL    CHK_MEMOVER
                JP      C,EXT_FTPGET_CANCEL
                PUSH    BC
                LD      HL,RCVBUF_DATA
                DI
                LDIR
                LD      A,(FLGDATA)
                AND     FLG_EXECPC8001
                JR      NZ,EXT_FTPGET_240
                PUSH    DE
                PUSH    HL
                LD      HL,SIOIRQ_ENTRY
                LD      DE,(VECTOR_TBL_SIO)
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                JR      Z,EXT_FTPGET_230
                LD      (SAVESIOIRQ),DE
                LD      (VECTOR_TBL_SIO),HL
EXT_FTPGET_230:
                POP     HL
                POP     DE
EXT_FTPGET_240:
                EI
                POP     BC
                CALL    DISP_PROGRESS
                LD      HL,(LOADSIZE)
                SBC     HL,BC
                LD      (LOADSIZE),HL
                CALL    ENABLE_RTS
;
                LD      A,ACK
                CALL    OUT_SIO        
                LD      HL,CHKBLKNO
                INC     (HL)
                JP      EXT_FTPGET_L060
EXT_FTPGET_300:
                CALL    ENABLE_RTS
                LD      A,NAK
                CALL    OUT_SIO        
                JP      EXT_FTPGET_L060
EXT_FTPGET_310:
                LD      A,ACK
                CALL    OUT_SIO
                LD      A,(FLGDATA)
                AND     FLG_LOADBAS
                JR      Z,EXT_FTPGET_320
EXT_FTPGET_FIXBAS:
                PUSH    DE
                LD      HL,(LOADADRS)
                EX      DE,HL
                SBC     HL,DE
                PUSH    HL
                POP     BC
                POP     HL
                XOR     A
                CPDR
                INC     HL
                LD      (HL),A
                INC     HL
                LD      (HL),A
                LD      (VARAREA_TOP),  HL
                LD      (ARRAYAREA_TOP),HL
                LD      (FREEAREA_TOP), HL
EXT_FTPGET_320:
                LD      HL,(SELDIVINO)
                INC     HL
                LD      (SELDIVINO),HL
                LD      DE,(DIVICOUNT)
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                JR      Z,EXT_FTPGET_340
                CALL    ROM_DSPCRLF
                CALL    ROM_TIMEREAD
                LD      A,(BCD_TIME_SEC)
                LD      D,A
EXT_FTPGET_330:
                PUSH    DE
                CALL    ROM_TIMEREAD
                POP     DE
                LD      A,(BCD_TIME_SEC)
                CP      D
                JR      Z,EXT_FTPGET_330
                JP      EXT_FTPGET_050
EXT_FTPGET_340:
                LD      A,1
                CALL    TERM_SIO
                POP     HL
                PUSH    HL
                LD      HL,0
                LD      DE,(EXECADRS)
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                POP     HL
                JR      Z,EXT_FTPGET_350
                JP      EXT_DLEXEC_EXIT
EXT_FTPGET_350:
                PUSH    HL
                LD      HL,0
                LD      DE,(EXECADRS2)
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                POP     HL
                JP      Z,EXT_EXIT
                LD      A,(FLGDATA)
                AND     FLG_LOADBAS
                JP      NZ,EXT_FTPGET_360
                LD      (EXECADRS),DE
                JP      EXT_DLEXEC_EXIT
EXT_FTPGET_360:
                PUSH    HL
                LD      HL,TBL_RUN
                LD      DE,FUNCKEY_DATA
                LD      BC,5
                LDIR
                LD      HL,FUNCKEY_DATA
                LD      (FUNCKEY_PTR),HL
                LD      HL,FUNCKEY_FLAG
                LD      (HL),1
                POP     HL
                JP      EXT_EXIT
EXT_FTPGET_CANCEL:
                CALL    ENABLE_RTS
                LD      A,CAN
                CALL    OUT_SIO
                CALL    ROM_DSPCRLF
                XOR     A
                LD      (OUTPUT_DEVICE),A
                INC     A
                LD      (CURSOR_XPOS),A
                LD      HL,ERR_MSG_000
                CALL    ROM_MSGOUT
                CALL    ROM_BEEP
                XOR     A
                CALL    TERM_SIO
                POP     HL
                JP      EXT_MYERR_EXIT
;
;
;
EXT_SNTP:
                PUSH    HL
                CALL    INIT_SIO
                JP      C,EXT_ERR5
                LD      HL,TBL_EXT_SNTP
                LD      DE,SNDBUF_TOP
                LD      BC,4
                LDIR
                LD      HL,TBL_CRLF
                LD      BC,2
                LDIR
                LD      B,6
                CALL    SENDBUF_OUT
                LD      B,1
                CALL    RECVBUF_IN
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                JP      NZ,EXT_ERR1
                LD      DE,TBL_EXT_SNTP
                LD      B,4
                CALL    RECVBUF_CHK
                JP      C,EXT_ERR2
                LD      DE,BCD_TIME_YEAR
                LD      C,0
                INC     HL
                INC     HL
EXT_SNTP_L000:
                LD      A,(HL)          ; ASCII DECIMAL -> BCD
                AND     0FH
                SLA     A
                SLA     A
                SLA     A
                SLA     A
                LD      B,A
                INC     HL
                LD      A,(HL)
                AND     0FH
                OR      B
                LD      B,A
                LD      A,C
                CP      1               ; MONTH NOT BCD        
                JR      NZ,EXT_SNTP_000
                PUSH    DE              ; BCD -> BIN
                PUSH    HL
                LD      A,B
                AND     0F0H
                SRA     A
                SRA     A
                SRA     A
                SRA     A
                LD      E,10                
                CALL    MUL_88_2_16
                LD      A,B
                AND     0FH
                ADD     A,L
                LD      B,A
                POP     HL
                POP     DE
EXT_SNTP_000:
                LD      A,B
                LD      (DE),A
                INC     HL
                DEC     DE
                LD      A,(HL)
                CP      CR
                JR      Z,EXT_SNTP_010
                INC     HL
                INC     C
                JR      EXT_SNTP_L000
EXT_SNTP_010:
                CALL    ROM_TIMEWRITE
                JP      EXT_END
;
;
;
EXT_SPIFFSLIST:
                PUSH    HL
                CALL    INIT_SIO
                JP      C,EXT_ERR5
                LD      HL,TBL_EXT_SPIFFSLIST2
                LD      DE,SNDBUF_TOP
                LD      BC,10
                LDIR
                LD      HL,TBL_CRLF
                LD      BC,2
                LDIR
                LD      B,12
                CALL    SENDBUF_OUT
                LD      B,1
                CALL    RECVBUF_IN
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                JP      NZ,EXT_ERR1
                LD      DE,TBL_EXT_SPIFFSLIST2
                LD      B,10
                CALL    RECVBUF_CHK
                JP      C,EXT_ERR2
                JP      EXT_FTPLIST_000
;
;
;
EXT_SPIFFSGET:
                PUSH    HL
                CALL    INIT_SIO
                JP      C,EXT_ERR5
                LD      HL,DISPBUF_TOP
                LD      DE,(SELLISTNO)
                LD      (BIN_ACC),DE
                LD      BC,0
                CALL    ROM_BIN2DECASC
                LD      HL,TBL_EXT_SPIFFSGET2
                LD      DE,SNDBUF_TOP
                LD      BC,10
                LDIR
                LD      HL,DISPBUF_TOP + 2
                LD      BC,3
                LDIR
                LD      HL,TBL_CRLF
                LD      BC,2
                LDIR
                LD      B,15
                CALL    SENDBUF_OUT
                LD      B,1
                CALL    RECVBUF_IN
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                JP      NZ,EXT_ERR1
                LD      DE,TBL_EXT_SPIFFSGET2
                LD      B,9
                CALL    RECVBUF_CHK
                JP      C,EXT_ERR2
                JP      EXT_FTPGET_000
;
;
;
EXT_VER:
                PUSH    HL
                CALL    INIT_SIO
                JP      C,EXT_ERR5
                LD      HL,TBL_EXT_VER
                LD      DE,SNDBUF_TOP
                LD      BC,3
                LDIR
                LD      HL,TBL_CRLF
                LD      BC,2
                LDIR
                LD      B,5
                CALL    SENDBUF_OUT
                LD      B,1
                CALL    RECVBUF_IN
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                JR      NZ,EXT_ERR1
                LD      DE,TBL_EXT_VER
                LD      B,3
                CALL    RECVBUF_CHK
                JR      C,EXT_ERR2
                PUSH    HL
                LD      HL,TBL_ESP32_VER
                LD      DE,DISPBUF_TOP
EXT_VER_L010:
                LD      A,(HL)
                LD      (DE),A
                INC     HL
                INC     DE
                CP      0
                JR      NZ,EXT_VER_L010
                POP     HL
                DEC     DE
EXT_VER_L020:
                LD      A,(HL)
                CP      ','
                JR      Z,EXT_VER_010
                CP      CR
                JR      Z,EXT_VER_030
                JR      EXT_VER_020
EXT_VER_010:
                LD      A,'.'
EXT_VER_020:
                LD      (DE),A
                INC     HL
                INC     DE
                JR      EXT_VER_L020
EXT_VER_030:
                CALL    MSG_DISP
                LD      HL,TBL_SIO_VER
                LD      DE,DISPBUF_TOP
EXT_VER_L030:
                LD      A,(HL)
                LD      (DE),A
                INC     HL
                INC     DE
                CP      0
                JR      NZ,EXT_VER_L030
                CALL    MSG_DISP
                JR      EXT_END
;
;
;
EXT_ERR0:
                LD      HL,ERR_MSG_000
                JR      EXT_ERR
EXT_ERR1:
                LD      HL,ERR_MSG_001
                JR      EXT_ERR
EXT_ERR2:
                LD      HL,ERR_MSG_002
                JR      EXT_ERR
EXT_ERR3:
                LD      HL,ERR_MSG_003
                JR      EXT_ERR
EXT_ERR4:
                LD      HL,ERR_MSG_004
                JR      EXT_ERR
EXT_ERR5:
                LD      HL,ERR_MSG_005
EXT_ERR:
                XOR     A
                LD      (OUTPUT_DEVICE),A
                INC     A
                LD      (CURSOR_XPOS),A
                CALL    ROM_MSGOUT
                CALL    ROM_DSPCRLF
                CALL    ROM_BEEP
                XOR     A
                CALL    TERM_SIO
                POP     HL
                JP      EXT_MYERR_EXIT
EXT_END:
                XOR     A
                CALL    TERM_SIO
                POP     HL
                JP      EXT_EXIT
;
;
;
PARSER_EXTPARAM:
                PUSH    HL
                LD      HL,0
                LD      (LOADADRS),    HL
                LD      (EXECADRS),    HL
                LD      (LOAD_ENDADRS),HL
                LD      (LOADSIZE),    HL
                XOR     A
                LD      (EXTNO),A
                LD      A,(FLGDATA)
                AND     ~FLG_LOADBAS
                AND     ~FLG_RCVTIMEOUT
                LD      (FLGDATA),A
                POP     HL
                LD      DE,TBL_EXT
PARSER_EXTPARAM_000:
                LD      A,(DE)
                CP      0
                JP      Z,SETCFRET
                PUSH    HL
PARSER_EXTPARAM_010:
                CP      (HL)
                JR      NZ,PARSER_EXTPARAM_020
                INC     HL
                INC     DE
                LD      A,(DE)
                CP      0
                JR      Z,PARSER_EXTPARAM_040
                JR      PARSER_EXTPARAM_010
PARSER_EXTPARAM_020:
                POP     HL
PARSER_EXTPARAM_030:
                INC     DE
                LD      A,(DE)
                CP      0
                JR      NZ,PARSER_EXTPARAM_030
                INC     DE
                INC     DE
                INC     DE
                INC     DE
                INC     DE
                INC     DE
                JR      PARSER_EXTPARAM_000
PARSER_EXTPARAM_040:
                DEC     HL
                INC     DE
                LD      A,(DE)
                LD      (EXTNO),A
                INC     DE
                PUSH    HL
                LD      A,(DE)
                LD      L,A
                INC     DE
                LD      A,(DE)
                LD      H,A
                PUSH    HL
                POP     IX
                INC     DE
                LD      A,(DE)
                LD      L,A
                INC     DE
                LD      A,(DE)
                LD      H,A
                PUSH    HL
                POP     IY
                POP     HL
                POP     DE
                JP      (IX)
PARSER_EXT_BME:
PARSER_EXT_FTPLIST:
PARSER_EXT_SNTP:
PARSER_EXT_SPIFFSLIST:
PARSER_EXT_VER:
                INC     HL
                LD      A,(HL)
                CP      0
                JR      Z,CLRCFRET
                CP      ':'
                JR      Z,CLRCFRET
                JR      SETCFRET
PARSER_EXT_FTPGET:
PARSER_EXT_SPIFFSGET:
                CALL    PARSER_SKIP
                CP      0FH             ; ID CODE 0FH : 1 byte hex
                JR      Z,PARSER_EXT_FTPGET_210
                CP      11H             ; ID CODE 11H -> 0, 12H -> 1, ... 19H -> 8, 1AH -> 9
                JR      Z,PARSER_EXT_FTPGET_000
                CP      1AH
                JR      C,PARSER_EXT_FTPGET_000
                JR      Z,PARSER_EXT_FTPGET_000
                CP      1CH             ; ID CODE 0CH : 2 byte hex
                JR      Z,PARSER_EXT_FTPGET_300
                JR      SETCFRET
PARSER_EXT_FTPGET_000:
                SUB     A,11H
                LD      E,A
                XOR     A
                LD      D,A
                JR      PARSER_EXT_FTPGET_310
PARSER_EXT_FTPGET_210:
                INC     HL
                LD      E,(HL)
                XOR     A
                LD      D,A
                JR      PARSER_EXT_FTPGET_310
PARSER_EXT_FTPGET_300:
                INC     HL
                LD      E,(HL)
                INC     HL
                LD      D,(HL)
PARSER_EXT_FTPGET_310:
                LD      (SELLISTNO),DE
                INC     HL
                LD      A,(HL)
                CP      0
                JR      Z,CLRCFRET
                CP      ':'
                JR      Z,CLRCFRET
                DEC     HL
                CALL    PARSER_SKIP
                CP      0CH             ; ID CODE "&H"
                JR      NZ,SETCFRET
                INC     HL
                LD      E,(HL)
                INC     HL
                LD      D,(HL)
                LD      (EXECADRS),DE
                INC     HL
                LD      A,(HL)
                CP      0
                JR      Z,CLRCFRET
                CP      ':'
                JR      Z,CLRCFRET
                JR      SETCFRET
PARSER_SKIP:
                INC     HL
                LD      A,(HL)
                CP      ' '
                JR      Z,PARSER_SKIP
                CP      ','
                JR      Z,PARSER_SKIP_010
                POP     DE
                JR      SETCFRET
PARSER_SKIP_010:
                INC     HL
                LD      A,(HL)
                CP      ' '
                JR      Z,PARSER_SKIP_010
                RET
CLRCFRET:
                SCF
                CCF
                RET
SETCFRET:
                SCF
                RET
;
;
;
CLR_RCVBUF:
                LD      HL,RCVBUF_TOP
                PUSH    AF
                PUSH    HL
                LD      B,RCVBUF_BOTTOM - RCVBUF_TOP + 1
                XOR     A
CLR_RCVBUF_L010:
                LD      (HL),A
                INC     HL
                DJNZ    CLR_RCVBUF_L010
                POP     HL
                POP     AF
                RET
;
;
;
CHK_MEMOVER:
                PUSH    DE
                LD      HL,_PROG_TOP
                LD      DE,PC8001RAM_TOP
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                POP     DE
                JR      C,CHK_MEMOVER_010
                PUSH    DE
                EX      DE,HL
                ADD     HL,BC
                LD      DE,_PROG_TOP
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                POP     DE
                JR      C,CHK_MEMOVER_010
                PUSH    DE
                EX      DE,HL
                ADD     HL,BC
                LD      DE,_PROG_END
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                POP     DE
                RET     C
CHK_MEMOVER_010:
                PUSH    DE
                EX      DE,HL
                ADD     HL,BC
                EX      DE,HL
                LD      HL,(ROM_WORKTOP)
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                POP     DE
                RET
;
;
;
CHK_RCVDATA:
                LD      HL,RCVBUF_TOP
                LD      A,(HL)
                CP      SOH
                JR      NZ,SETCFRET
                LD      C,A
                INC     HL
                LD      A,(CHKBLKNO)
                CP      (HL)
                JR      NZ,SETCFRET
                ADD     A,C
                LD      C,A
                INC     HL
                LD      A,(CHKBLKNO)
                CPL
                CP      (HL)
                JR      NZ,SETCFRET
                ADD     A,C
                LD      C,A
                INC     HL
                LD      B,128
CHK_RCVDATA_L010:
                LD      A,(HL)
                ADD     A,C
                LD      C,A
                INC     HL
                DJNZ    CHK_RCVDATA_L010
                LD      A,C
                CP      (HL)
                JP      NZ,SETCFRET
                JP      CLRCFRET
;
;
;
DISP_PROGRESS:
                PUSH    BC
                PUSH    DE
                PUSH    HL
                LD      A,1
                LD      (CURSOR_XPOS),A
                LD      A,'['
                CALL    ROM_DSPCHR
                LD      HL,(LOADADRS)
                CALL    ROM_DSPHEX4
                LD      A,'-'
                CALL    ROM_DSPCHR
                EX      DE,HL
                DEC     HL
                CALL    ROM_DSPHEX4
                LD      A,']'
                CALL    ROM_DSPCHR
                POP     HL
                POP     DE
                POP     BC
                RET
;
;
;
INIT_SIO:
                CALL    ENABLE_SIO
                XOR     A               ; DUMMY OUT
                OUT     (USARTCW),A
                OUT     (USARTCW),A
                OUT     (USARTCW),A
                LD      A,01000000B     ; SOFT RESET
                OUT     (USARTCW),A
                LD      A,01001110B     ; MODE SETUP                    : 8N11
                                        ; BAUD RATE FACTOR              : 16X
                                        ; CHARACTER LENGTH              : 8BITS
                                        ; PARITY ENABLE                 : DISABLE
                                        ; EVEN PARITY GENARATION/CHECK  : ODD
                                        ; NUMBER OF STOP BITS           : 1 BIT
                OUT     (USARTCW),A
                LD      (MODEWORD),A
                LD      A,00000101B     ; COMMAND SETUP  TRANSMIT ENABLE
                                        ;                DATA TERMINAL READY : FALSE
                                        ;                RECEIVE ENABLE
                                        ;                ERROR RESET         : FALSE
                                        ;                REQUEST TO SEND     : FALSE
                OUT     (USARTCW),A
                LD      (CTLWORD),A
                CALL    ENABLE_DTR
                CALL    ENABLE_RTS
INIT_SIO_000:
                IN      A,(USARTCW)     ; ESP32-WROOM-32 -> 8251 power-on receive dust removal support
                LD      D,A
                AND     00111000B
                JR      NZ,INIT_SIO_010
                LD      A,D
                AND     00000010B
                JR      Z,INIT_SIO_020
                IN      A,(USARTDW)
                JR      INIT_SIO_000
INIT_SIO_010:
                LD      A,(CTLWORD)
                OR      00010000B
                OUT     (USARTCW),A
                JR      INIT_SIO_000
INIT_SIO_020:
                LD      A,(FLGDATA)
                AND     FLG_FIRSTSEND
                JR      NZ,INIT_SIO_030
                LD      DE,SNDBUF_TOP   ; 8251 -> ESP32-WROOM-32 power-on send dust removal support
                LD      HL,TBL_CRLF
                LD      BC,2
                LDIR
                LD      B,2
                CALL    SENDBUF_OUT
                LD      A,(FLGDATA)
                OR      FLG_FIRSTSEND
                LD      (FLGDATA),A
INIT_SIO_030:
                LD      HL,NROM_WORKTOP
                LD      (ROM_WORKTOP),HL
                LD      HL,0
                LD      (SAVESIOIRQ),HL
                XOR     A
                LD      (RCVBUF_RPOS),A
                LD      (RCVBUF_WPOS),A
                LD      A,(FLGDATA)
                AND     ~FLG_ENABLESTOP
                AND     ~FLG_EXECPC8001
                LD      (FLGDATA),A
                LD      A,(ROM_PC8001CHK)
                CP      80H             ; N-BASIC IMPLEMENTED IN PC-8001
                JR      Z,INIT_SIO_100
                CP      0AFH            ; N-BASIC IMPLEMENTED IN PC-8001mkII
                JR      Z,INIT_SIO_200
                JP      SETCFRET
INIT_SIO_100:
                LD      A,(FLGDATA)
                OR      FLG_EXECPC8001
                LD      (FLGDATA),A
                JR      INIT_SIO_900
INIT_SIO_200:
                LD      HL,(CMD_ENTRY + 1)
                LD      DE,PC8001MK2_N80MODE
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                JR      Z,INIT_SIO_210
                JR      INIT_SIO_220
INIT_SIO_210:
                LD      HL,N80ROM_WORKTOP
                LD      (ROM_WORKTOP),HL
INIT_SIO_220:
                LD      HL,(VECTOR_TBL_SIO)
                LD      (SAVESIOIRQ),HL
                DI
                LD      HL,SIOIRQ_ENTRY
                LD      (VECTOR_TBL_SIO),HL
                LD      A,7
                OUT     (INTLEVEL),A
                LD      A,00000100B     ; bit2 : /RxMF USART    IRQ ENABLE
                                        ; bit1 : /VRMF VRTC     IRQ DISABLE
                                        ; bit0 : /RTMF INTERVAL IRQ DISABLE
                OUT     (INTMASK),A
                EI
INIT_SIO_900:
                JP      CLRCFRET

;
; A :  0 no wait term sio
;   : !0 1sec wait term sio
;
TERM_SIO:
                PUSH    DE
                CP      0
                JR      Z,TERM_SIO_020
                CALL    ROM_TIMEREAD
                LD      A,(BCD_TIME_SEC)
                LD      D,A
TERM_SIO_010:
                PUSH    DE
                CALL    ROM_TIMEREAD
                POP     DE
                LD      A,(BCD_TIME_SEC)
                CP      D
                JR      Z,TERM_SIO_010
TERM_SIO_020:
                LD      A,(FLGDATA)
                AND     FLG_EXECPC8001
                JR      NZ,TERM_SIO_030
                DI
                LD      HL,(SAVESIOIRQ)
                LD      (VECTOR_TBL_SIO),HL
                LD      A,00000000B     ; bit2 : /RxMF USART    IRQ DISABLE
                                        ; bit1 : /VRMF VRTC     IRQ DISABLE
                                        ; bit0 : /RTMF INTERVAL IRQ DISABLE
                OUT     (INTMASK),A
                EI
TERM_SIO_030:
                CALL    DISABLE_RTS
                CALL    DISABLE_DTR
                CALL    DISABLE_SIO
                POP     DE
                RET
;
;
;
SIOIRQ_ENTRY:
                DI
                EX      AF,AF'
                EXX
                LD      A,(LAST_INTLEVEL)
                PUSH    AF
;
                LD      A,7
                OUT     (INTLEVEL),     A
                LD      (LAST_INTLEVEL),A
                LD      (FLG_INTEXEC),  A
;
SIOIRQ_010:
                IN      A,(USARTCW)
                LD      D,A
                AND     00111000B
                JR      NZ,SIOIRQ_030
                LD      A,D
                AND     00000010B
                JR      Z,SIOIRQ_EXIT
;
                LD      A,(RCVBUF_WPOS)
                LD      HL,RCVBUF_TOP
                LD      B,0
                LD      C,A
                ADD     HL,BC
                IN      A,(USARTDW)
                LD      (HL),A
                INC     C
                LD      A,C
                LD      B,RCVBUF_BOTTOM - RCVBUF_TOP + 1
                CP      B
                JR      NZ,SIOIRQ_020
                JR      C,SIOIRQ_020
                LD      C,0
SIOIRQ_020:
                LD      A,C
                LD      (RCVBUF_WPOS),A
                JR      SIOIRQ_EXIT
SIOIRQ_030:
                LD      A,(CTLWORD)
                OR      00010000B
                OUT     (USARTCW),A
                JR      SIOIRQ_010
SIOIRQ_EXIT:
;
                POP     AF
                OUT     (INTLEVEL),A
                EXX
                EX      AF,AF'
                EI
                RET
;
;
;
ENABLE_SIO:
                LD      A,(CTL1_OUTDATA)
                AND     11001111B       ; BS2,BS1 CLR
                OR      00100000B       ; BS2 ON
                OUT     (CONTROL1),A
                LD      (CTL1_OUTDATA),A
                RET
;
;
;
DISABLE_SIO:
                LD      A,(CTL1_OUTDATA)
                AND     11001111B       ; BS2,BS1 CLR
                OUT     (CONTROL1),A
                LD      (CTL1_OUTDATA),A
                RET
;
;
;
ENABLE_DTR:
                LD      A,(CTLWORD)
                OR      00000010B       ; DATA TERMINAL READY : TRUE
                OUT     (USARTCW),A
                RET
;
;
;
DISABLE_DTR:
                LD      A,(CTLWORD)
                AND     11111101B       ; DATA TERMINAL READY : FALSE
                OUT     (USARTCW),A
                RET
;
;
;
ENABLE_RTS:
                LD      A,(CTLWORD)
                OR      00100000B       ; REQUEST TO SEND : TRUE
                OUT     (USARTCW),A
                RET
;
;
;
DISABLE_RTS:
                LD      A,(CTLWORD)
                AND     11011111B       ; REQUEST TO SEND : FALSE
                OUT     (USARTCW),A
                RET
;
;
;
IN_SIO:
                LD      A,(FLGDATA)
                AND     ~FLG_RCVTIMEOUT
                AND     ~FLG_RCVCANCEL
                LD      (FLGDATA),A
                PUSH    BC
                PUSH    DE
                PUSH    HL
                LD      HL,3            ; 5000msec Timer
                LD      BC,0A00H
IN_SIO_010:
                LD      A,(FLGDATA)
                AND     FLG_ENABLESTOP
                JR      Z,IN_SIO_020
                IN      A,(KEYBRD9)
                AND     00000001B
                JR      Z,IN_SIO_080
IN_SIO_020:
                LD      A,(FLGDATA)
                AND     FLG_EXECPC8001
                JR      NZ,IN_SIO_040
;
                LD      A,(RCVBUF_RPOS)
                LD      E,A
                LD      A,(RCVBUF_WPOS)
                CP      E
                JP      Z,IN_SIO_060
                LD      HL,RCVBUF_TOP
                LD      D,0
                ADD     HL,DE
                INC     E
                LD      A,E
                LD      D,RCVBUF_BOTTOM - RCVBUF_TOP + 1
                CP      D
                JR      NZ,IN_SIO_030
                JR      C,IN_SIO_030
                LD      E,0
IN_SIO_030:
                LD      A,E
                LD      (RCVBUF_RPOS),A
                LD      A,(HL)
                JR      IN_SIO_100
;
IN_SIO_040:
                IN      A,(USARTCW)
                LD      D,A
                AND     00111000B
                JR      NZ,IN_SIO_050
                LD      A,D
                AND     00000010B
                JR      NZ,IN_SIO_090
                JR      IN_SIO_060
IN_SIO_050:
                LD      A,(CTLWORD)
                OR      00010000B
                OUT     (USARTCW),A
IN_SIO_060:
                DEC     BC
                LD      A,C
                CP      0
                JR      NZ,IN_SIO_010
                LD      A,B
                CP      0
                JR      NZ,IN_SIO_010
                DEC     HL
                LD      A,L
                CP      0
                JR      NZ,IN_SIO_010
                LD      A,H
                CP      0
                JR      NZ,IN_SIO_010
IN_SIO_070:
                LD      A,(FLGDATA)
                OR      FLG_RCVTIMEOUT
                LD      (FLGDATA),A
                XOR     A
                JR      IN_SIO_100
IN_SIO_080:
                LD      A,(FLGDATA)
                OR      FLG_RCVCANCEL
                LD      (FLGDATA),A
                XOR     A
                JR      IN_SIO_100
IN_SIO_090:
                IN      A,(USARTDW)
IN_SIO_100:
                POP     HL
                POP     DE
                POP     BC
                RET
;
;
;
OUT_SIO:
                PUSH    AF
OUT_SIO_000:
                IN      A,(USARTCW)
                AND     00000001B
                JR      Z,OUT_SIO_000
                POP     AF
                OUT     (USARTDW),A
                RET
;
;
;
SENDBUF_OUT:
                LD      HL,SNDBUF_TOP
SENDBUF_OUT_000:
                LD      A,(HL)
                CALL    OUT_SIO
                INC     HL
                DJNZ    SENDBUF_OUT_000
                RET
;
;
;
RECVBUF_IN:
                LD      A,B
                LD      (LFRECVCOUNT),A
                LD      HL,RCVBUF_TOP
RECVBUF_IN_000:
                CALL    IN_SIO
                PUSH    BC
                LD      B,A
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                LD      A,B
                POP     BC
                JR      NZ,RECVBUF_IN_020                
                LD      (HL),A
                CP      LF
                JR      Z,RECVBUF_IN_030
RECVBUF_IN_010:
                INC     HL
                JR      RECVBUF_IN_000
RECVBUF_IN_020:
                LD      A,(LFRECVCOUNT)
                LD      C,A
                LD      A,B
                CP      C
                JR      Z,RECVBUF_IN_040
                LD      A,(FLGDATA)
                AND     ~FLG_RCVTIMEOUT
                LD      (FLGDATA),A
                JR      RECVBUF_IN_040
RECVBUF_IN_030:
                DEC     B
                XOR     A
                CP      B
                JR      Z,RECVBUF_IN_040
                JR      RECVBUF_IN_010
RECVBUF_IN_040:
                RET
;
;
;
RECVBUF_CHK:
                LD      HL,RCVBUF_TOP
RECVBUF_CHK_000:
                LD      A,(DE)
                CP      (HL)
                JP      NZ,SETCFRET
                INC     HL
                INC     DE
                DJNZ    RECVBUF_CHK_000
                LD      A,':'
                CP      (HL)
                JP      NZ,SETCFRET
                INC     HL
                JP      CLRCFRET
;
;
;
MSG_DISP:
                XOR     A
                LD      (DE),A
                LD      (OUTPUT_DEVICE),A
                INC     A
                LD      (CURSOR_XPOS),A
                LD      HL,DISPBUF_TOP
                CALL    ROM_MSGOUT
                CALL    ROM_DSPCRLF
                RET
;
; D = 0
; HL = E * A
;
MUL_88_2_16:
                LD      D,0
                LD      HL,0
                LD      B,8
MUL_L000:
                ADD     HL,HL
                ADD     A,A
                JR      NC,MUL_000
                ADD     HL,DE
MUL_000:
                DJNZ    MUL_L000
                RET
;
;
;
ERR_MSG_000:    DB      "abort receive", 0
ERR_MSG_001:    DB      "receive time out", 0
ERR_MSG_002:    DB      "received command mismatch", 0
ERR_MSG_003:    DB      "ftp/spiffs get failed", 0
ERR_MSG_004:    DB      "load address not set", 0
ERR_MSG_005:    DB      "not support hardware", 0
TBL_EXT:
TBL_EXT_BME:    DB      "BME",       0, 1
                DW      PARSER_EXT_BME
                DW      EXT_BME
TBL_EXT_FTPLIST:DB      "FTP", 93H,  0, 2       ; reserve code 93H : "LIST"
                DW      PARSER_EXT_FTPLIST
                DW      EXT_FTPLIST
TBL_EXT_FTPGET: DB      "FTP", 0C7H, 0, 3       ; reserve code C7H : "GET"
                DW      PARSER_EXT_FTPGET
                DW      EXT_FTPGET
TBL_EXT_SNTP:   DB      "SNTP",      0, 4
                DW      PARSER_EXT_SNTP
                DW      EXT_SNTP
TBL_EXT_SPIFFSLIST:
                DB      "SPI", 93H,  0, 5    ; reserve code 93H : "LIST"
                DW      PARSER_EXT_SPIFFSLIST
                DW      EXT_SPIFFSLIST
TBL_EXT_SPIFFSGET:
                DB      "SPI", 0C7H, 0, 6    ; reserve code C7H : "GET"
                DW      PARSER_EXT_FTPGET
                DW      EXT_SPIFFSGET
TBL_EXT_VER:    DB      "VER",       0, 7
                DW      PARSER_EXT_VER
                DW      EXT_VER
                DB      0
TBL_EXT_FTPLIST2:
                DB      "FTPLIST"
TBL_EXT_FTPGET2:DB      "FTPGET:"
TBL_EXT_LIST:   DB      "LIST:"
TBL_EXT_GET:    DB      "GET:"
TBL_EXT_SPIFFSLIST2:
                DB      "SPIFFSLIST"
TBL_EXT_SPIFFSGET2:
                DB      "SPIFFSGET:"
TBL_RUN:        DB      "RUN", 0DH, 0
TBL_COUNT_MSG0: DB      "file count: ", 0
TBL_TEMP_MSG0:  DB      "temp : ", 0
TBL_TEMP_MSG1:  DB      0DFH, "C", 0
TBL_HUMI_MSG0:  DB      "humi : ", 0
TBL_HUMI_MSG1:  DB      "%", 0
TBL_PRESS_MSG0: DB      "press: ", 0
TBL_PRESS_MSG1: DB      "hPa", 0
TBL_ESP32_VER:  DB      "esp32 firmware v", 0
TBL_SIO_VER:    DB      "sio   firmware v", 30H + VER_MAJOR, ".", 30H + VER_MINOR, ".", 30H + VER_REVISION, 0
TBL_CRLF:       DB      CR, LF
                ;END

