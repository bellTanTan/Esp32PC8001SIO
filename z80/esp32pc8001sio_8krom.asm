                ORG     06000H
_USER_ROM_START:
_PROG_TOP:
                DB      "AB"
                NOP
                JP      _ENTRY
_MON_ENTRY:
                CALL    _ENTRY
                JP      ROM_BASPROMPT
                NOP
                DB      VER_MAJOR
                DB      VER_MINOR
                DB      VER_REVISION
_MON_U_ENTRY:
                CALL    _ENTRY
                JP      ROM_MON_UNEXT
_ENTRY:
                CALL    ENTRY_SETUP
                RET
NEWJPTBL:
                JP      NEW_CMD
NEW_CMD:
                INCLUDE "esp32pc8001sio.asm"
_PROG_END:
;
;
;
_USER_ROM_END:
                DS      8192 - 4 - ( _USER_ROM_END - _USER_ROM_START ), 0FFH
;
                JP      _MON_U_ENTRY
                DB      "U"
                END

