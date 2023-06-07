{{
''
'' PSRAM 8MB-Treiber für PSRAM 64H,APS6404L Chip
''
'' erste Testversion als Ersatz für Parallel-Ram (-> Upgrade 1MB -> 8MB) des Hive
'' Spin-Routinen (notwendig für regflash.spin)
'' verbrochen von : Zille9 02/2021
'' https://hive-project.de
''
''
''
''
Logbuch:

04-03-2021      -Spin und PASM-Routinen funktionsfähig aber noch nicht optimiert
                -momentan nur eine Pinconfiguration im PASM
                -die Funktionen Byte-Read, Byte-Write, Ram-Fill, Ram-Copy, Ram-Keep(für Trios Basic) sind vorhanden

}}

con
_CLKMODE     = XTAL1 + PLL16X
_XINFREQ     = 5_000_000

'DB_IN           = %00000000_00000000_00110000_00000000  'maske: dbus-eingabe
'DB_OUT          = %00000000_00000000_00111111_00000000  'maske: dbus-ausgabe
'DB_IN           = %00000000_00000000_00000000_00110000  'maske: dbus-eingabe
'DB_OUT          = %00000000_00000000_00000000_00111111  'maske: dbus-ausgabe

'##################################################################################
'# HINWEIS:die PASM-Routinen sind nur für die folgende Pinkonfiguration erstellt !#
'##################################################################################

'CS      =0        'CS 1
'SIO0    =8        'MISO 5
'SIO1    =9        '2
'SIO2    =10       '3
'SIO3    =11       'MOSI 7
'CLK     =1        'CLK 6


baud    =57600


{{  PSRAM64H driver. Für PSRAM-Chip 8M (64Mbit)

                              Vdd(+3.3V)
                                  
                  PSRAM64H        │
                                  │
             ┌────────────────┐   │ 0.1µF
   P16 ─────┤1 /CS    Vcc   8├───┻────── Vss
   P9  ─────┤2 S0     SIO3  7├────────── Vss
   Vss ─────┤3 SIO2   CLK   6├────────── P17
          ┌──┤4 GND    SI    5├────────── P8
            └────────────────┘
         Vss
DO,CLK,DI,CS
}}

obj     ser    :"RS232_ComEngine"'"FullDuplexSerialExtended"
        psram  :"23lc1024"'"PSRAM_PASM_HIVE"
        'psram  :"PSRAM_PASM0-6"
var     byte buffer[$200]

PUB Main|adr,putbyte,getbyte,fails,i,durchlauf
    Dira:=0'DB_IN
    ser.start(31, 30,0,baud)'0, baud)                              'serielle Schnittstelle starten
    waitcnt(clkfreq+cnt)
    psram.start(9,17,8,16)                                                   'PSRAM-Cog starten
    i:=0
    'psram.ram_reset
    'psram.ram_sqi
    ser.str(string("PSRAM-Test",13))
    putbyte:=0
    durchlauf:=0
    ser.str(string("Weiter -> Taste",13))
    repeat while ser.rx==0
repeat
    durchlauf++
    Ser.str(string("Testdurchlauf:"))
    Ser.dec(durchlauf)
    ser.tx(13)
    ser.str(string("PSRAM loeschen $400000 bytes...",13)) 'ca.8sek.
    'psram.write(buffer,0,$200)
    'psram.ram_fill($0,$400000,0)

    repeat adr from $10000 to $1FFFF
              psram.write(putbyte,adr,1)
              'psram.wr_value(adr,PutByte,psram#Job_Poke)
              'waitcnt(clkfreq/30+cnt)
              psram.read(Getbyte,adr,1)'psram.rd_value(adr,psram#JOB_PEEK)

              if Putbyte<>Getbyte
                 fails++
                 ser.hex(adr,6)
                 ser.tx(32)
                 ser.dec(putbyte)
                 ser.tx(32)
                 ser.dec(Getbyte)
                 ser.tx(13)
              PutByte++
              if putbyte>255
                 putbyte:=0



    Ser.str(string("RAM-Schreib-Lese-Test abgeschlossen",13))
    ser.str(string("Fehler:"))
    ser.dec(fails)
    ser.tx(13)
    Ser.str(string("RAM von $2000-$3FFF mit dem Wert $94 fuellen...",13))
    ser.str(string("Weiter -> Taste",13))
    repeat while ser.rx==0
    fails:=0
    'psram.ram_fill($2000,$2000,$94)
    psram.write($94,$2000,$1FFF)
    repeat adr from $2000 to $3FFF
           psram.read(Getbyte,adr,1)'Getbyte:=psram.rd_value(adr,psram#JOB_PEEK)

           if getbyte<>$94
              fails++
              ser.hex(adr,4)
              ser.tx(32)
              ser.hex(getbyte,2)
              ser.tx(13)
    ser.str(string("RAM fuellen beendet",13))
    ser.str(string("Fehler:"))
    ser.dec(fails)
    ser.tx(13)
    Ser.str(string("RAM Bereich kopieren von $2000-$2FFF nach $1000-$1FFF",13))
    ser.str(string("Weiter -> Taste",13))
    repeat while ser.rx==0
    'psram.ram_copy($2000,$1000,$1000)
    'repeat adr from $1000 to $1FFF
    '       Getbyte:=psram.rd_value(adr,psram#JOB_PEEK)

'           if getbyte<>$94
'              fails++
'              ser.hex(adr,4)
'              ser.tx(32)
'              ser.hex(getbyte,2)
'              ser.tx(13)

    ser.str(string("Alle Tests abgeschlossen !",13))
    ser.str(string("Fehler:"))
    ser.dec(fails)
    ser.tx(13)

obj
{{
Ram-Funktionen:

psram.ram_fill(Adresse,Anzahl,Wert)                     'Ram-Bereich füllen mit Wert -> die 8MB des Chips werden in ca.7sek gefüllt
psram.ram_copy(Quelle,Ziel,Anzahl)                      'Ram Bereich kopieren
Wert:=psram.rd_value(Adresse,psram#JOB_PEEK)            'Byte lesen
Wert:=psram.rd_value(Adresse,psram#JOB_RDWORD)          'Word lesen
Wert:=psram.rd_value(Adresse,psram#JOB_RDLONG)          'Long lesen
psram.wr_value(Adresse,Wert,psram#Job_Poke)             'Byte schreiben
psram.wr_value(Adresse,Wert,psram#Job_WRWORD)           'Word schreiben
psram.wr_value(Adresse,Wert,psram#Job_WRLONG)           'Long schreiben

}}

con'############################################# SPIN-Routinen ohne PASM #################################################################################
{{
' WICHTIG:Vor der ersten Verwndung von Read oder Write muss der CHIP in den SQI (Quad) Modus geschalten werden -> SPI2SQI
{Bsp. für Readbyte:

SQIReadAdr(Adresse)
Getbyte:=SQIByteRead
Deselect
}

{Bsp. für WriteByte:
SQIWriteadr(adr)
SQIByteWrite(wert)
Deselect
}
}}

{pub str(n)|i
    repeat strsize(n)
         SQIByteWrite(byte[n++])
}
{PUB ClockStrobe                                         'Clock-Signal
outa[CLK]:=1
outa[CLK]:=0

PUB SQIAddress(adr)|i                                     'Adresse senden

  outa[sio3..sio0]:=adr>>20 & $F                        '// Output Address 23 To 20;
  ClockStrobe                                           '// Latch Address 23 To 20;
  outa[sio3..sio0]:=adr>>16 & $F                        '// Output Address 19 To 16
  ClockStrobe                                           '// Latch Address 19 To 16
  outa[sio3..sio0]:=adr>>12 & $F                        '// Output Address 15 To 12
  ClockStrobe                                           '// Latch Address 15 To 12
  outa[sio3..sio0]:=adr>>8 & $F                         '// Output Address 11 To 8
  ClockStrobe                                           '// Latch Address 11 To 8
  outa[sio3..sio0]:=adr>>4 & $F                         '// Output Address 7 To 4
  ClockStrobe                                           '// Latchh Address 7 To 4
  outa[sio3..sio0]:=adr & $F                            '// Output Address 3 To 0
  ClockStrobe                                           '// Latch Address 3 to 0

PUB SQIByteRead(adr):wert|a,b                           'QPI READ-Byte $0B(%0000_1011 slow) or $EB(%1110_1011 fast) für Spin reicht slow (bis 66MHz)

  outa[CS]                      :=0                     '// Enable RAM Chip
  outa[SIO3..SIO0]              :=%1110                 '// Output Upper Nibble Command  $EB
  dira                          :=DB_OUT
  ClockStrobe                                           '// Latch Upper Nibble Command
  outa[SIO3..SIO0]              :=%1011                 '// Output Lower Nibble Command
  ClockStrobe                                           '// Latch Lower Nibble Command
  SQIAddress(adr)                                       '// Strobe Out The Address
  dira                          :=DB_IN

  ClockStrobe                                        '// Strobe (bei $0B 4xStrobe bei $EB 6xStrobe)
  ClockStrobe                                        '// Strobe (bei $0B 4xStrobe bei $EB 6xStrobe)
  ClockStrobe                                        '// Strobe (bei $0B 4xStrobe bei $EB 6xStrobe)
  ClockStrobe                                        '// Strobe (bei $0B 4xStrobe bei $EB 6xStrobe)
  ClockStrobe                                        '// Strobe (bei $0B 4xStrobe bei $EB 6xStrobe)
  ClockStrobe                                        '// Strobe (bei $0B 4xStrobe bei $EB 6xStrobe)

  wert :=ina[SIO3..SIO0]                             '// Grab Upper Nibble From SRAM
  wert:=wert<<4
  ClockStrobe                                           '// Ack Upper Nibble
  wert  :=wert + ina[SIO3..SIO0]                        '// Grab Lower Nibble From SRAM
  ClockStrobe                                           '// Ack Lower Nibble
    dira                        :=DB_IN
  outa[CS]                      :=1
  return wert

PUB SQIByteWrite(adr,c)|l1,l2                            'QPI WRITE-Byte $02 (%0000_0010) or $38 (%0011_1000)

  outa[CS]                      :=0                     '// Enable RAM Chip
  outa[SIO3..SIO0]              :=%0011                 '// Output Upper Nibble Command
  dira                          :=DB_OUT
  ClockStrobe                                           '// Latch Upper Nibble Command
  outa[SIO3..SIO0]              :=%1000                 '// Output Lower Nibble Command
  ClockStrobe                                           '// Latch Lower Nibble Command
  SQIAddress(adr)                                       '// Strobe Out The Address
  outa[SIO3..SIO0]              :=c >> 4                '// Output Data Upper Nibble
  ClockStrobe                                           '// Latch The Data Upper Nibble
  outa[SIO3..SIO0]              :=c & $F                    '// Output Data Lower Nibble
  ClockStrobe                                           '// Latch The Data Lower Nibble
    dira                        :=DB_IN
  outa[CS]                      :=1

pub deselect                                            'Deselect PSRAM
    dira                        :=DB_IN
    outa[CS]                    :=1

PUB SPI2SQI                     '// Force RAM Into SQI Mode 0x35 %0011_0101

  dira[SIO0]                    :=1
  outa[CS]                      :=0

  outa[SIO0]                    :=0                     '// Set Data Output Low
  ClockStrobe                                           '// Latch Bit7=0
  ClockStrobe                                           '// Latch Bit6=0
  outa[SIO0]                    :=1                     '// Set Data Output HIGH
  ClockStrobe                                           '// Latch Bit5=1
  ClockStrobe                                           '// Latch Bit4=1
  outa[SIO0]                    :=0                     '// Set Data Output Low
  ClockStrobe                                           '// Latch Bit3=0
  outa[SIO0]                    :=1                     '// Set Data Output HIGH
  ClockStrobe                                           '// Latch Bit2=1
  outa[SIO0]                    :=0                     '// Set Data Output Low
  ClockStrobe                                           '// Latch Bit1=0
  outa[SIO0]                    :=1                     '// Set Data Output HIGH
  ClockStrobe                                           '// Latch Bit0=1
  dira                          :=DB_IN
  outa[CS]                      :=1                     '// Disable RAM Chip

PUB SQIReset                                            'Reset-Kommando !!! Schalten den Ram wieder in den SPI-Mode !!!

  dira                          :=DB_OUT
  outa[CLK]                     :=0
  outa[CS]                      :=0
  outa[SIO3..SIO0]              :=%0110                 '// Output Upper Nibble Command
  ClockStrobe                                           '// Latch Bit6=0
  outa[SIO3..SIO0]              :=%0110                 '// Output Upper Nibble Command
  ClockStrobe
  outa[CS]                      :=1
  outa[CS]                      :=0
  outa[SIO3..SIO0]              :=%1001                 '// Output Upper Nibble Command
  ClockStrobe
  outa[SIO3..SIO0]              :=%1001                 '// Output Upper Nibble Command
  ClockStrobe
  outa[CS]                      :=1

}
Dat
{{

┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}
