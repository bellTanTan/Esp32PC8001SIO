#!/bin/sh
z80asm --input=esp32pc8001sio_4krom.asm --output=esp32pc8001sio_4krom.bin --list=esp32pc8001sio_4krom.lst
z80asm --input=esp32pc8001sio_8krom.asm --output=esp32pc8001sio_8krom.bin --list=esp32pc8001sio_8krom.lst
z80asm --input=esp32pc8001sio_ram.asm --output=esp32pc8001sio_ram.bin --list=esp32pc8001sio_ram.lst


