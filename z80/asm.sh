#!/bin/sh
z80asm --input=esp32pc8001sio_8krom.asm --output=esp32pc8001sio_8krom.bin --list=esp32pc8001sio_8krom.lst
z80asm --input=esp32pc8001sio_ram.asm --output=esp32pc8001sio_ram.bin --list=esp32pc8001sio_ram.lst
#z80asm --input=test001.asm --output=test001.bin --list=test001.lst
cp esp32pc8001sio_8krom.bin USER.ROM 
#cp esp32pc8001sio_ram.bin ~/work/ramtest/ramtest.bin
#cp test001.bin ~/work/ramtest/ramtest.bin
