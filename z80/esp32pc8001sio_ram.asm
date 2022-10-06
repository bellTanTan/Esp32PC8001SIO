                ORG     0A000H
_PROG_TOP:
_MON_ENTRY:
                CALL    _ENTRY
                JP      ROM_BASPROMPT
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                DB      VER_MAJOR
                DB      VER_MINOR
                DB      VER_REVISION
_ENTRY:
                CALL    ENTRY_SETUP
                RET
NEWJPTBL:
                JP      NEW_CMD
NEW_CMD:
                INCLUDE "esp32pc8001sio.asm"
_PROG_END:
                END

