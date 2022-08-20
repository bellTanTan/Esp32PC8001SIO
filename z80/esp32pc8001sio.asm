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
; CMD FTPGET,nnn,&HXXXX
; CMD SNTP
; CMD VER
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
ROMBAS_WORKTOP: EQU     0EA00H
FUNKEY_DISPSTS: EQU     0EA60H
CRT_TEXT_ROWS:  EQU     0EA62H
CURSOR_YPOS:    EQU     0EA63H
CURSOR_XPOS:    EQU     0EA64H
CRT_TEXT_COLS:  EQU     0EA65H
CTL1_OUTDATA:   EQU     0EA66H
BCD_TIME_SEC:   EQU     0EA76H
BCD_TIME_YEAR:  EQU     0EA7BH     
OUTPUT_DEVICE:  EQU     0EB49H
BASAREA_TOP:    EQU     0EB54H
VARAREA_TOP:    EQU     0EFA0H
ARRAYAREA_TOP:  EQU     0EFA2H
FREEAREA_TOP:   EQU     0EFA4H
BIN_ACC:        EQU     0F0A8H
CMD_ENTRY:      EQU     0F0FCH
;
; N-BASIC ROM FREE AREA1 : F216~F2FF
; N-BASIC ROM FREE AREA2 : FF3D~FFFF
; CONSTANT ESP32PC8001SIO WORK AREA
;
SAVESP:         EQU     0F216H
LISTCNT:        EQU     0F218H
SELLISTNO:      EQU     0F21AH
LOADADRS:       EQU     0F21CH
EXECADRS:       EQU     0F22EH
MODEWORD:       EQU     0F220H
CTLWORD:        EQU     0F221H
CMDNO:          EQU     0F222H
CHKBLKNO:       EQU     0F223H
LFRECVCOUNT:    EQU     0F224H
DISPBUF_TOP:    EQU     0F230H
SNDBUF_TOP:     EQU     0F270H
RCVBUF_TOP:     EQU     0F270H
RCVBUF_HEADER:  EQU     RCVBUF_TOP
RCVBUF_BLKNO:   EQU     RCVBUF_TOP +1
RCVBUF_CBLKNO:  EQU     RCVBUF_TOP +2
RCVBUF_DATA:    EQU     RCVBUF_TOP +3
RCVBUF_CHKSUM:  EQU     RCVBUF_DATA +128
RCVBUF_BOTTOM:  EQU     RCVBUF_CHKSUM
FLGDATA:        EQU     0F2FFH          ; 76543210
                                        ; |||||||+--- <CR><LF> first send
                                        ; ||||||+---- load basic cmt type       
                                        ; |||||+----- sio recv time out (5sec)
                                        ; ||||+------ sio recv cancel (keyboard STOP key)
                                        ; |||+------- enable keyboard STOP key check
                                        ; ||+-------- reserve
                                        ; |+--------- reserve
                                        ; +---------- reserve
FLG_FIRSTSEND:  EQU     00000001B
FLG_LOADBAS:    EQU     00000010B
FLG_RCVTIMEOUT: EQU     00000100B
FLG_RCVCANCEL:  EQU     00001000B
FLG_ENABLESTOP: EQU     00010000B
;
; CONSTANT ESP32PC8001SIO VERSION DATA
;
VER_MAJOR:      EQU     1
VER_MINOR:      EQU     0
VER_REVISION:   EQU     0
;
                ;ORG    0H
CMD_START:
                DI
                LD      (SAVESP),SP
                EX      DE,HL
                LD      HL,0FFFFH
                LD      SP,HL
                EX      DE,HL
                EI
                CALL    PARSER_CMDPARAM
                JP      C,CMD_SYNERR_EXIT
                JP      (IY)
CMD_EXIT:
                XOR     A
CMD_EXIT000:
                DI
                EX      DE,HL
                LD      HL,(SAVESP)
                LD      SP,HL
                EX      DE,HL
                EI
                CP      0
                JR      NZ,CMD_EXIT010
                RET
CMD_EXIT010:
                POP     DE
                JP      (IX)
CMD_SYNERR_EXIT:
                LD      A,1
                LD      IX,ROM_SYNERR
                JR      CMD_EXIT000
CMD_MYERR_EXIT:
                LD      A,2
                LD      IX,ROM_BASPROMPT
                JR      CMD_EXIT000
;
;
;
CMD_BME:
                PUSH    HL
                CALL    INIT_SIO
                LD      HL,TBL_CMD_BME
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
                JP      NZ,CMD_ERR1
                LD      DE,TBL_CMD_BME
                LD      B,3
                CALL    RECVBUF_CHK
                JP      C,CMD_ERR2
                LD      B,0
                CALL    CMD_BME_MSG
                LD      B,1
                CALL    CMD_BME_MSG
                LD      B,2
                CALL    CMD_BME_MSG
                JP      CMD_END
CMD_BME_MSG:
                PUSH    HL
                LD      A,B
                CP      1
                JR      Z,CMD_BME_000
                CP      2
                JR      Z,CMD_BME_010
                LD      HL,TBL_TEMP_MSG0
                JR      CMD_BME_020
CMD_BME_000:
                LD      HL,TBL_HUMI_MSG0
                JR      CMD_BME_020
CMD_BME_010:
                LD      HL,TBL_PRESS_MSG0
CMD_BME_020:
                LD      DE,DISPBUF_TOP
CMD_BME_L010:
                LD      A,(HL)
                LD      (DE),A
                INC     HL
                INC     DE
                CP      0
                JR      NZ,CMD_BME_L010
                POP     HL
                DEC     DE
CMD_BME_L020:
                LD      A,(HL)
                CP      ','
                JR      Z,CMD_BME_050
                CP      CR
                JR      Z,CMD_BME_050
                LD      (DE),A
                INC     HL
                INC     DE
                JR      CMD_BME_L020
CMD_BME_050:
                INC     HL
                PUSH    HL
                LD      A,B
                CP      1
                JR      Z,CMD_BME_060
                CP      2
                JR      Z,CMD_BME_070
                LD      HL,TBL_TEMP_MSG1
                JR      CMD_BME_L030
CMD_BME_060:
                LD      HL,TBL_HUMI_MSG1
                JR      CMD_BME_L030
CMD_BME_070:
                LD      HL,TBL_PRESS_MSG1
CMD_BME_L030:
                LD      A,(HL)
                LD      (DE),A
                INC     HL
                INC     DE
                CP      0
                JR      NZ,CMD_BME_L030
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
CMD_FTPLIST:
                PUSH    HL
                CALL    INIT_SIO
                LD      HL,TBL_CMD_FTPLIST2
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
                JP      NZ,CMD_ERR1
                LD      DE,TBL_CMD_FTPLIST2
                LD      B,7
                CALL    RECVBUF_CHK
                JP      C,CMD_ERR2
                PUSH    HL
                LD      HL,TBL_COUNT_MSG0
                LD      DE,DISPBUF_TOP
CMD_FTPLIST_L000:
                LD      A,(HL)
                LD      (DE),A
                INC     HL
                INC     DE
                CP      0
                JR      NZ,CMD_FTPLIST_L000
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
                JP      Z,CMD_END
                LD      (SELLISTNO),DE
CMD_FTPLIST_L010:
                LD      HL,DISPBUF_TOP
                LD      DE,(SELLISTNO)
                LD      (BIN_ACC),DE
                LD      BC,0
                CALL    ROM_BIN2DECASC
                LD      HL,TBL_CMD_LIST
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
                JP      NZ,CMD_ERR1
                LD      DE,TBL_CMD_LIST
                LD      B,4
                CALL    RECVBUF_CHK
                JP      C,CMD_ERR2
                LD      DE,DISPBUF_TOP
                LD      BC,3
                LDIR
                LD      A,':'
                LD      (DE),A
                INC     DE
                LD      A,(CRT_TEXT_COLS)
                CP      72
                JR      Z,CMD_FTPLIST_040
                CP      80
                JR      Z,CMD_FTPLIST_040
                LD      B,4
CMD_FTPLIST_010:
                LD      A,(HL)
                INC     HL
                CP      ','
                JR      Z,CMD_FTPLIST_020
                JR      CMD_FTPLIST_010
CMD_FTPLIST_020:
                DJNZ    CMD_FTPLIST_010
CMD_FTPLIST_030:
                LD      A,(HL)
                LD      (DE),A
                INC     HL
                INC     DE
                CP      CR
                JR      Z,CMD_FTPLIST_070
                JR      CMD_FTPLIST_030
CMD_FTPLIST_040:
                INC     HL
CMD_FTPLIST_L020:
                LD      A,(HL)
                CP      ','
                JR      Z,CMD_FTPLIST_050
                CP      CR
                JR      Z,CMD_FTPLIST_070
                JR      CMD_FTPLIST_060
CMD_FTPLIST_050:
                LD      A,' '
CMD_FTPLIST_060:
                LD      (DE),A
                INC     HL
                INC     DE
                JR      CMD_FTPLIST_L020
CMD_FTPLIST_070:
                CALL    MSG_DISP
                IN      A,(KEYBRD9)
                LD      D,A
                AND     00000001B
                JP      Z,CMD_END
                LD      A,D
                AND     10000000B
                JR      NZ,CMD_FTPLIST_090
CMD_FTPLIST_080:
                IN      A,(KEYBRD9)
                LD      D,A
                AND     00000001B
                JP      Z,CMD_END
                LD      A,D
                AND     10000000B
                JR      Z,CMD_FTPLIST_080
CMD_FTPLIST_090:
                LD      HL,(LISTCNT)
                LD      DE,(SELLISTNO)
                INC     DE
                LD      (SELLISTNO),DE
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                JP      NZ,CMD_FTPLIST_L010
                JP      CMD_END
;
;
;
CMD_FTPGET:
                PUSH    HL
                CALL    INIT_SIO
                LD      HL,DISPBUF_TOP
                LD      DE,(SELLISTNO)
                LD      (BIN_ACC),DE
                LD      BC,0
                CALL    ROM_BIN2DECASC
                LD      HL,TBL_CMD_FTPGET2
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
                JP      NZ,CMD_ERR1
                LD      DE,TBL_CMD_FTPGET2
                LD      B,6
                CALL    RECVBUF_CHK
                JP      C,CMD_ERR2
                INC     HL
                INC     HL
                INC     HL
                INC     HL
                LD      A,(HL)
                AND     0FH
                CP      0
                JP      Z,CMD_ERR3
                CP      1
                JP      Z,CMD_FTPGET_100
                CP      2
                JR      Z,CMD_FTPGET_110
                CP      3
                JR      Z,CMD_FTPGET_120
                JP      CMD_ERR2
CMD_FTPGET_100:
                LD      DE,(EXECADRS)
                PUSH    HL
                LD      HL,0
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                POP     HL
                JP      Z,CMD_ERR4
                LD      (LOADADRS),DE
                JR      CMD_FTPGET_200
CMD_FTPGET_110:
                LD      A,(FLGDATA)
                OR      FLG_LOADBAS
                LD      (FLGDATA),A
                LD      DE,(BASAREA_TOP)
                LD      (LOADADRS),DE
                JR      CMD_FTPGET_200
CMD_FTPGET_120:
                INC     HL
                INC     HL
                LD      B,4
                LD      DE,0
CMD_FTPGET_130:
                LD      A,(HL)
                PUSH    HL
                EX      DE,HL
                CALL    ROM_HEXASC2BIN
                EX      DE,HL
                POP     HL
                INC     HL
                DJNZ    CMD_FTPGET_130
                LD      (LOADADRS),DE
CMD_FTPGET_200:
                LD      A,(FLGDATA)
                OR      FLG_ENABLESTOP
                LD      (FLGDATA),A
                LD      A,1
                LD      (CHKBLKNO),A
CMD_FTPGET_L010:
                LD      A,NAK
                CALL    OUT_SIO
CMD_FTPGET_L020:
                CALL    IN_SIO
                CP      EOT
                JP      Z,CMD_FTPGET_030
                CP      SOH
                JR      Z,CMD_FTPGET_010
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                JR      NZ,CMD_FTPGET_L010
                LD      A,(FLGDATA)
                AND     FLG_RCVCANCEL
                JP      NZ,CMD_FTPGET_CANCEL
                JR      CMD_FTPGET_L020
CMD_FTPGET_L030:
                CALL    IN_SIO
                CP      EOT
                JR      Z,CMD_FTPGET_030
                CP      SOH
                JR      Z,CMD_FTPGET_010
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                JP      NZ,CMD_FTPGET_CANCEL
                LD      A,(FLGDATA)
                AND     FLG_RCVCANCEL
                JP      NZ,CMD_FTPGET_CANCEL
                JR      CMD_FTPGET_L030
CMD_FTPGET_010:
                CALL    CLR_RCVBUF
                LD      (HL),A
                INC     HL
                LD      B,131
CMD_FTPGET_L040:
                CALL    IN_SIO
                LD      C,A
                LD      A,(FLGDATA)
                AND     FLG_RCVTIMEOUT
                JP      NZ,CMD_FTPGET_CANCEL
                LD      A,(FLGDATA)
                AND     FLG_RCVCANCEL
                JP      NZ,CMD_FTPGET_CANCEL
                LD      A,C
                LD      (HL),A
                INC     HL
                DJNZ    CMD_FTPGET_L040
;
                CALL    DISABLE_RTS
                CALL    CHKDATA
                JR      C,CMD_FTPGET_020
                CALL    CHK_MEMOVER
                JR      C,CMD_FTPGET_CANCEL
                LD      HL,RCVBUF_DATA
                LD      BC,128
                LDIR
                CALL    DISP_PROGRESS
                CALL    ENABLE_RTS
;
                LD      A,ACK
                CALL    OUT_SIO        
                LD      HL,CHKBLKNO
                INC     (HL)
                JR      CMD_FTPGET_L030
CMD_FTPGET_020:
                CALL    ENABLE_RTS
                LD      A,NAK
                CALL    OUT_SIO        
                JR      CMD_FTPGET_L030
CMD_FTPGET_030:
                LD      A,ACK
                CALL    OUT_SIO
                LD      A,1
                CALL    TERM_SIO
                POP     HL
                LD      A,(FLGDATA)
                AND     FLG_LOADBAS
                JR      NZ,CMD_FTPGET_FIXBAS
                PUSH    HL
                LD      HL,0
                LD      DE,(EXECADRS)
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                POP     HL
                JP      Z,CMD_EXIT
                LD      HL,(SAVESP)
                LD      SP,HL
                EX      DE,HL
                JP      (HL)
CMD_FTPGET_FIXBAS:
                PUSH    HL
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
                INC     HL
                LD      (VARAREA_TOP),  HL
                LD      (ARRAYAREA_TOP),HL
                LD      (FREEAREA_TOP), HL
                POP     HL
                JP      CMD_EXIT
CMD_FTPGET_CANCEL:
                CALL    ROM_DSPCRLF
                XOR     A
                LD      (OUTPUT_DEVICE),A
                INC     A
                LD      (CURSOR_XPOS),A
                LD      HL,ERR_MSG_000
                CALL    ROM_MSGOUT
                CALL    ROM_BEEP
                LD      A,CAN
                CALL    OUT_SIO
                LD      A,1
                CALL    TERM_SIO
                POP     HL
                JP      CMD_EXIT
;
;
;
CMD_SNTP:
                PUSH    HL
                CALL    INIT_SIO
                LD      HL,TBL_CMD_SNTP
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
                JP      NZ,CMD_ERR1
                LD      DE,TBL_CMD_SNTP
                LD      B,4
                CALL    RECVBUF_CHK
                JP      C,CMD_ERR2
                LD      DE,BCD_TIME_YEAR
                INC     HL
                INC     HL
CMD_SNTP_L000:
                LD      A,(HL)
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
                LD      (DE),A
                INC     HL
                DEC     DE
                LD      A,(HL)
                CP      CR
                JR      Z,CMD_SNTP_000
                INC     HL
                JR      CMD_SNTP_L000
CMD_SNTP_000:
                CALL    ROM_TIMEWRITE
                JP      CMD_END
;
;
;
CMD_VER:
                PUSH    HL
                CALL    INIT_SIO
                LD      HL,TBL_CMD_VER
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
                JR      NZ,CMD_ERR1
                LD      DE,TBL_CMD_VER
                LD      B,3
                CALL    RECVBUF_CHK
                JR      C,CMD_ERR2
                PUSH    HL
                LD      HL,TBL_ESP32_VER
                LD      DE,DISPBUF_TOP
CMD_VER_L010:
                LD      A,(HL)
                LD      (DE),A
                INC     HL
                INC     DE
                CP      0
                JR      NZ,CMD_VER_L010
                POP     HL
                DEC     DE
CMD_VER_L020:
                LD      A,(HL)
                CP      ','
                JR      Z,CMD_VER_010
                CP      CR
                JR      Z,CMD_VER_030
                JR      CMD_VER_020
CMD_VER_010:
                LD      A,'.'
CMD_VER_020:
                LD      (DE),A
                INC     HL
                INC     DE
                JR      CMD_VER_L020
CMD_VER_030:
                CALL    MSG_DISP
                LD      HL,TBL_SIO_VER
                LD      DE,DISPBUF_TOP
CMD_VER_L030:
                LD      A,(HL)
                LD      (DE),A
                INC     HL
                INC     DE
                CP      0
                JR      NZ,CMD_VER_L030
                CALL    MSG_DISP
                JR      CMD_END
;
;
;
CMD_ERR0:
                LD      HL,ERR_MSG_000
                JR      CMD_ERR
CMD_ERR1:
                LD      HL,ERR_MSG_001
                JR      CMD_ERR
CMD_ERR2:
                LD      HL,ERR_MSG_002
                JR      CMD_ERR
CMD_ERR3:
                LD      HL,ERR_MSG_003
                JR      CMD_ERR
CMD_ERR4:
                LD      HL,ERR_MSG_004
CMD_ERR:
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
                JP      CMD_MYERR_EXIT
CMD_END:
                XOR     A
                CALL    TERM_SIO
                POP     HL
                JP      CMD_EXIT
;
;
;
PARSER_CMDPARAM:
                PUSH    HL
                LD      HL,0
                LD      (LOADADRS),HL
                LD      (EXECADRS),HL
                XOR     A
                LD      (CMDNO),A
                LD      A,(FLGDATA)
                AND     ~FLG_LOADBAS
                AND     ~FLG_RCVTIMEOUT
                LD      (FLGDATA),A
                POP     HL
                LD      DE,TBL_CMD
PARSER_CMDPARAM_000:
                LD      A,(DE)
                CP      0
                JP      Z,SETCFRET
                PUSH    HL
PARSER_CMDPARAM_010:
                CP      (HL)
                JR      NZ,PARSER_CMDPARAM_020
                INC     HL
                INC     DE
                LD      A,(DE)
                CP      0
                JR      Z,PARSER_CMDPARAM_040
                JR      PARSER_CMDPARAM_010
PARSER_CMDPARAM_020:
                POP     HL
PARSER_CMDPARAM_030:
                INC     DE
                LD      A,(DE)
                CP      0
                JR      NZ,PARSER_CMDPARAM_030
                INC     DE
                INC     DE
                INC     DE
                INC     DE
                INC     DE
                INC     DE
                JR      PARSER_CMDPARAM_000
PARSER_CMDPARAM_040:
                DEC     HL
                INC     DE
                LD      A,(DE)
                LD      (CMDNO),A
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
PARSER_CMD_BME:
PARSER_CMD_FTPLIST:
PARSER_CMD_SNTP:
PARSER_CMD_VER:
                INC     HL
                LD      A,(HL)
                CP      0
                JR      Z,CLRCFRET
                CP      ':'
                JR      Z,CLRCFRET
                JR      SETCFRET
PARSER_CMD_FTPGET:
                CALL    PARSER_SKIP
                CP      0FH             ; ID CODE 0FH : 1 byte hex
                JR      Z,PARSER_CMD_FTPGET_010
                CP      11H             ; ID CODE 11H -> 0, 12H -> 1, ... 19H -> 8, 1AH -> 9
                JR      Z,PARSER_CMD_FTPGET_000
                CP      1AH
                JR      C,PARSER_CMD_FTPGET_000
                JR      Z,PARSER_CMD_FTPGET_000
                CP      1CH             ; ID CODE 0CH : 2 byte hex
                JR      Z,PARSER_CMD_FTPGET_020
                JR      SETCFRET
PARSER_CMD_FTPGET_000:
                SUB     A,11H
                LD      E,A
                XOR     A
                LD      D,A
                JR      PARSER_CMD_FTPGET_030
PARSER_CMD_FTPGET_010:
                INC     HL
                LD      E,(HL)
                XOR     A
                LD      D,A
                JR      PARSER_CMD_FTPGET_030
PARSER_CMD_FTPGET_020:
                INC     HL
                LD      E,(HL)
                INC     HL
                LD      D,(HL)
PARSER_CMD_FTPGET_030:
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
                LD      BC,128
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
                EX      DE,HL
                LD      HL,_PROG_TOP
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
                LD      HL,ROMBAS_WORKTOP
                CALL    ROM_CMPHLDE     ;         Z CY
                                        ; HL<DE : 0  1
                                        ; HL=DE : 1  0
                                        ; HL>DE : 0  0
                POP     DE
                RET
;
;
;
CHKDATA:
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
CHKDATA_L010:
                LD      A,(HL)
                ADD     A,C
                LD      C,A
                INC     HL
                DJNZ    CHKDATA_L010
                LD      A,C
                CP      (HL)
                JP      NZ,SETCFRET
                JP      CLRCFRET
;
;
;
DISP_PROGRESS:
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
                LD      A,(FLGDATA)
                AND     ~FLG_ENABLESTOP
                LD      (FLGDATA),A
                RET
INIT_SIO_010:
                LD      A,(CTLWORD)
                OR      00010000B
                OUT     (USARTCW),A
                JR      INIT_SIO_000
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
                CALL    DISABLE_RTS
                CALL    DISABLE_DTR
                CALL    DISABLE_SIO
                POP     DE
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
                JR      Z,IN_SIO_015
                IN      A,(KEYBRD9)
                AND     00000001B
                JR      Z,IN_SIO_070
IN_SIO_015:
                IN      A,(USARTCW)
                LD      D,A
                AND     00111000B
                JR      NZ,IN_SIO_050
                LD      A,D
                AND     00000010B
                JR      NZ,IN_SIO_030
IN_SIO_020:
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
IN_SIO_060:
                LD      A,(FLGDATA)
                OR      FLG_RCVTIMEOUT
                LD      (FLGDATA),A
                XOR     A
                JR      IN_SIO_040
IN_SIO_070:
                LD      A,(FLGDATA)
                OR      FLG_RCVCANCEL
                LD      (FLGDATA),A
                XOR     A
                JR      IN_SIO_040
IN_SIO_030:
                IN      A,(USARTDW)
IN_SIO_040:
                POP     HL
                POP     DE
                POP     BC
                RET
IN_SIO_050:
                LD      A,(CTLWORD)
                OR      00010000B
                OUT     (USARTCW),A
                JR      IN_SIO_020
;
;
;
OUT_SIO:
                PUSH    AF
OUT_SIO1:
                IN      A,(USARTCW)
                AND     00000001B
                JR      Z,OUT_SIO1
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
RECVBUF_CHK1:
                LD      A,(DE)
                CP      (HL)
                JP      NZ,SETCFRET
                INC     HL
                INC     DE
                DJNZ    RECVBUF_CHK1
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
ERR_MSG_003:    DB      "ftpget failed", 0
ERR_MSG_004:    DB      "load address not set", 0
TBL_CMD:
TBL_CMD_BME:    DB      "BME",       0, 1
                DW      PARSER_CMD_BME
                DW      CMD_BME
TBL_CMD_FTPLIST:DB      "FTP", 93H,  0, 2       ; reserve code 93H : "LIST"
                DW      PARSER_CMD_FTPLIST
                DW      CMD_FTPLIST
TBL_CMD_FTPGET: DB      "FTP", 0C7H, 0, 3       ; reserve code C7H : "GET"
                DW      PARSER_CMD_FTPGET
                DW      CMD_FTPGET
TBL_CMD_SNTP:   DB      "SNTP",      0, 4
                DW      PARSER_CMD_SNTP
                DW      CMD_SNTP
TBL_CMD_VER:    DB      "VER",       0, 6
                DW      PARSER_CMD_VER
                DW      CMD_VER
                DB      0
TBL_CMD_FTPLIST2:
                DB      "FTPLIST"
TBL_CMD_FTPGET2:DB      "FTPGET:"
TBL_CMD_LIST:   DB      "LIST:"
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

