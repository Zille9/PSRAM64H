{{

Hive-Computer-Projekt

Name            : Peek and Poke
Chip            : Regnatix-Code (ramtest)
Version         : 0.1
Dateien         : ram_pasm.spin

Beschreibung    :
}}
CON

_CLKMODE     = XTAL1 + PLL16X
_XINFREQ     = 5_000_000
DB_IN           = %00000000_00000000_00000000_00000000  'maske: dbus-eingabe

CS      =0       'CS 1
SIO0    =8        'MISO 5
SIO1    =9        '2
SIO2    =10       '3
SIO3    =11       'MOSI 7
CLK     =1       'CLK 6

#0,JOB_NONE,JOB_POKE,JOB_PEEK,JOB_FILL,JOB_WRLONG,JOB_RDLONG,JOB_WRWORD,JOB_RDWORD,DO_READ,DO_WRITE,JOB_COPY,JOB_KEEP,JOB_SQI,JOB_RESET

VAR
  long CogNr
  long JobNr     ' 3 continue params
  long Address
  long Value
  long Anzahl
  long Werte

pub rd_value(adr,m):w
    Address := adr
    Value   := m
    dira    := 0
    JobNr   := DO_READ
    repeat until JobNr == JOB_NONE
    dira   := DB_IN
    w := Werte

pub wr_value(adr,val,m)
  Address := adr
  Value   := val
  Anzahl   := m
  dira    := 0
  JobNr   := DO_WRITE
  repeat until JobNr == JOB_NONE
  dira := DB_IN


pub ram_fill(adr,anz,wert)

    Address:=adr
    Value  :=wert
    Anzahl :=anz
    dira   :=0
    JobNr  :=JOB_FILL
    repeat until JobNr==JOB_NONE
    dira:=DB_IN

pub ram_copy(von,ziel,zahl)
    Address:=von
    Value:=ziel
    Anzahl:=zahl
    dira :=0
    JobNr:=Job_Copy
    repeat until JobNr==JOB_NONE
    dira:=DB_IN

pub ram_keep(adr):w
    address:=adr
'    Value:=0
'    Anzahl:=0
    dira  := 0
    JobNr:=Job_keep
    repeat until JobNr == JOB_NONE
    dira   := DB_IN
    w := Werte+1

PUB ram_sqi
    address:=0
    Value:=0
    Anzahl:=0
    dira  := 0
    JobNr:=Job_SQI
    repeat until JobNr == JOB_NONE
    dira:=DB_IN
PUB ram_reset
    address:=0
    Value:=0
    Anzahl:=0
    dira  := 0
    JobNr:=Job_RESET
    repeat until JobNr == JOB_NONE
    dira:=DB_IN
Pub Start

  CogNr := cognew(@cog_loop,@JobNr)

Pub Stop
  if CogNr==-1
    return
  cogstop(CogNr)
  CogNr:=-1

DAT                     ORG 0

cog_loop                rdlong  _job,par wz     ' get job id
              if_z      jmp     #cog_loop

              '********** Parameter einlesen **********************
                        mov     _ptr,par        ' pointer of params
                        add     _ptr,#4         ' move to param 1
                        rdlong  _adr,_ptr       ' lese 1.Parameter
                        add     _ptr,#4         ' move to param 2
                        rdlong  _val,_ptr       ' lese 2.Parameter
                        add     _ptr,#4         ' move to param 3
                        rdlong  _count,_ptr     ' lese 3-Parameter
                        mov     _ftemp,_adr     ' Kopie von _adr
                        mov     _tmpval,_val    ' Kopie von Wert
              '********** Kommandoabfrage *************************
                        cmp     _job,#DO_WRITE wz
              if_z      jmp     #cog_write

                        cmp     _job,#DO_READ wz
              if_z      jmp     #cog_read

                        cmp     _job,#JOB_FILL wz
              if_z      jmp     #cog_fill

                        cmp     _job,#JOB_COPY wz
              if_z      jmp     #cog_copy

                        cmp     _job,#JOB_KEEP wz
              if_z      jmp     #cog_keeping

                        cmp    _job,#JOB_SQI wz
              if_z      jmp     #SPI2SQI                'Set to SQI-Mode

                        cmp    _job,#JOB_RESET wz
              if_z      jmp     #SPIRESET                'Reset-Befehl
                        jmp     #cog_loop


'**************************************************************************************

cog_ready               mov     _ptr,par        'Parameter
                        mov     _job,#JOB_NONE  'Job mit null füllen
                        wrlong  _job,_ptr       'nach hubram
                        mov     outa,DESELECT
                        jmp     #cog_loop       'zurück zur Abfrageschleife
'######################################################################################

'**************************************************************************************

cog_subpeek             add     _ptr,#4         ' Ergebnis nach Werte übergeben next param
                        wrlong  _tmp,_ptr       ' Wert -> hubram
                        jmp     #cog_ready      ' ausstieg

'**************************** eine Zeile überspringen (testet auf 0)***************

cog_keeping             call    #sub_peekadr     'Adresse setzen
keeping_loop            call    #sub_peek        'Wert aus Ram lesen
                        cmp     _tmp,#0   wz     'Wert 0?
                if_z    jmp     #cog_keepout     'dann raus
                        call    #moving          'Adresse erhöhen (als Rückgabewert gebraucht)
                        jmp     #keeping_loop    'weiter

cog_keepout             mov     _tmp,_ftemp      'Adresse nach tmp
                        mov     outa,DESELECT    'CS=1 ->Ram inaktiv
                        jmp     #cog_subpeek

'************************Ram-Bereich kopieren**************************************

cog_copy
                        mov     _REGA,_val       'zieladresse merken

loop_copy               call    #sub_peekadr
                        call    #sub_peek        'Wert aus Quellspeicher lesen
                        mov     outa,DESELECT    'CS=1 ->Ram inaktiv
                        mov     _val,_tmp        'peekwert nach _val kopieren
                        mov     _adr,_REGA       'zieladresse nach _adr
                        call    #sub_pokeadr     'adresse setzen
                        call    #sub_poke        'wert in Zielspeicher schreiben
                        mov     outa,DESELECT    'CS=1 Ram inaktiv
                        add     _REGA,#1         'Zieladresse erhöhen
                        call    #moving          'Quelladresse erhöhen und nach _adr zurückschreiben
                        djnz    _count,#loop_copy 'counter runterzählen
                        jmp     #cog_ready        'raus



'***********************Byte, Word oder Long lesen*************************************
cog_read
                        mov     _RegA,#8        ' shiftwert
                        mov     _RegC,#3        ' Schleifenzaehler

                        call    #sub_peekadr
                        call    #sub_peek
                        cmp     _val,#JOB_PEEK wz 'wenn nur peek hier aussteigen
              if_z      jmp     #cog_subpeek

                        call    #rd_wr

loop_rd                 call    #sub_peek
                        shl     _tmp,_RegA
                        add     _tmp,_RegB
                        call    #rd_wr

                        cmp     _val,#JOB_RDWORD wz 'wenn rdword, dann hier raus
              if_z      jmp     #cog_subrdword

                        add     _regA,#8
                        djnz    _RegC,#loop_rd

cog_subrdword           add     _ptr,#4         ' next param
                        wrlong  _RegB,_ptr

                        jmp     #cog_ready

'************************Byte,Word oder Long schreiben*********************************
cog_write
                        mov     _RegA,_val      ' wert merken
                        mov     _RegB,#8        ' shiftwert
                        mov     _RegC,#3        ' Zaehlerschleifenwert

                        call    #sub_pokeadr
                        call    #sub_poke

                        cmp     _count,#JOB_POKE wz 'wenn nur poke hier aussteigen
              if_z      jmp     #cog_ready

loop_wrlong             mov     _val,_RegA
                        shr     _val,_RegB      'wert>>8
                        add     _RegB,#8        'shiftwert um 8 erhoehen

                        call    #moving
                        call    #sub_poke

                        cmp     _count,#JOB_WRWORD wz 'wenn wrword hier aussteigen
              if_z      jmp     #cog_ready

                        djnz    _RegC,#loop_wrlong

                        jmp     #cog_ready

'**************************************************************************************

rd_wr                   mov     _RegB,_tmp
moving                  add     _ftemp,#1        'adresse+1
                        mov     _adr,_ftemp      'adresse zurueckschreiben
moving_ret
rd_wr_ret               ret


'************************Ram-Bereich mit einem Wert füllen*****************************

cog_fill                mov     _val,_tmpval            ' Kopie von _val zurückschreiben
                        call    #sub_pokeadr

fill_loop               mov     _val,_tmpval            ' Kopie von _val zurückschreiben
                        call    #sub_poke
                        djnz    _count, #fill_loop      'nächste runde bis _count 0
                        mov     outa,DESELECT           'CS=1 ->Ram inaktiv
                        jmp     #cog_ready

'*****************************ein Byte in den RAM schreiben****************************

sub_pokeadr
                        mov     outa,_BUS_INIT          'all de-selected
                        mov     dira,_DIR_OUT           'S0-S3 als Output für Commando, Clock und CS=0 ->Ram aktiv
                        mov     outa,_COM38_A           '%0011 Befehl $38
                        call    #CLOCK
                        mov     outa,_COM38_B           '%1000
                        call    #CLOCK
                        call    #setadr
sub_pokeadr_ret         ret

sub_poke                mov     _tmp,_val               'kopie von _val
                        and     _tmp,#$F0               'nur die linken 4Bit
                        shl     _tmp,#4                 '4bit nach links in Position 11..8 schieben
                        mov     outa,_tmp
                        call    #CLOCK
                        and     _val,#$F
                        shl     _val,#8                 '8bit nach links in Position 11..8 schieben
                        mov     outa,_val
                        call    #CLOCK

sub_poke_ret            ret


'*****************************Ein Byte aus dem Ram lesen*******************************

sub_peekadr
                        ' BUS
                        mov     outa,_BUS_INIT          'all de-selected
                        mov     dira,_DIR_OUT           'S0-S3 als Output für Commando, Clock und CS=0 ->Ram aktiv
                        mov     outa,_COMEB             '$EB für Fast transfer
                        call    #CLOCK
                        mov     outa,_COM0B             'Commando $EB (bis 133MHz)
                        call    #CLOCK
                        call    #setadr
                        mov     dira,_DIR_IN
                        call    #CLOCK                  '4xClock bei Commando $0B (6x bei $EB)
                        call    #CLOCK
                        call    #CLOCK
                        call    #CLOCK
                        call    #CLOCK
                        call    #CLOCK
sub_peekadr_ret         ret
sub_peek
                        mov     _tmp,#0                 '_tmp löschen
                        mov     _tmp2,#0                '_tmp2 löschen
                        mov     _tmp,ina
                        and     _tmp,ANDMASK            '4bit maskieren
                        shl     _tmp,#4
                        call    #CLOCK
                        mov     _tmp2,ina
                        and     _tmp2,ANDMASK           '4bit maskieren
                        add     _tmp,_tmp2
                        shr     _tmp,#8
                        call    #CLOCK

sub_peek_ret            ret

'******************************RAM-Adresse setzen***************************************

setadr                  ' ADR 24 bit

                        mov     _tmp2,_adr              '23-20   Kopie von _adr machen
                        shr     _tmp2,#12               '12Bits nach rechts schieben 23..20->11..8
                        and     _tmp2,ANDMASK           'SIO3..SIO0 ausmaskieren
                        mov     outa,_tmp2              'Bit 23-20 ausgeben
                        call    #CLOCK

                        mov     _tmp2,_adr              '19-16
                        shr     _tmp2,#8                '8Bits nach rechts schieben 19..16 ->11..8
                        and     _tmp2,ANDMASK           'SIO3..SIO0 ausmaskieren
                        mov     outa,_tmp2              'Bit 19-16 ausgeben
                        call    #CLOCK

                        mov     _tmp2,_adr              '15-12
                        shr     _tmp2,#4                '4Bits nach rechts chieben 15..12 ->11..8
                        and     _tmp2,ANDMASK           'SIO3..SIO0 ausmaskieren
                        mov     outa,_tmp2              'Bit 15-12 ausgeben
                        call    #CLOCK

                        mov     _tmp2,_adr              '11-8
                        and     _tmp2,ANDMASK           'SIO3..SIO0 ausmaskieren 11..8 = 11..8
                        mov     outa,_tmp2              'Bit 11-8 ausgeben
                        call    #CLOCK

                        mov     _tmp2,_adr              '7-4
                        shl     _tmp2,#4                '4bits nach links schieben 7..4 ->11..8
                        and     _tmp2,ANDMASK           'SIO3..SIO0 ausmaskieren
                        mov     outa,_tmp2              'Bit 7-4 ausgeben
                        call    #CLOCK

                        mov     _tmp2,_adr              '3-0
                        shl     _tmp2,#8                '8Bits nach links schieben 3..0 ->11..8
                        and     _tmp2,ANDMASK           'SIO3..SIO0 ausmaskieren
                        mov     outa,_tmp2              'Bit 3-0 ausgeben
                        call    #CLOCK
setadr_ret              ret

'############################ Umschalten von SPI nach SQI (Quad-Mode) #####################

SPI2SQI                 mov     outa,_SIO0_Out0           'SIO0=0 CS=0
                        mov     dira,_SIO0                'SPI zu SQI Befehl $35 %0011_0101
                        call    #CLOCK
                        call    #CLOCK
                        mov     outa,_SIO0_Out1           'SIO0=1
                        call    #CLOCK
                        call    #CLOCK
                        mov     outa,_SIO0_Out0           'SIO0=0
                        call    #CLOCK
                        mov     outa,_SIO0_Out1           'SIO0=1
                        call    #CLOCK
                        mov     outa,_SIO0_Out0           'SIO0=0
                        call    #CLOCK
                        mov     outa,_SIO0_Out1           'SIO0=1
                        call    #CLOCK
                        mov     dira,_DIR_IN
                        jmp     #cog_ready
'############################ Reset-Kommando, Chip wird in SPI-Modus versetzt #############

SPIRESET                mov     outa,_RESET_A             '$66 Kommando Reset folgt
                        mov     dira,_DIR_OUT             'S0-S3 als Output für Commando, Clock und CS=0 ->Ram aktiv
                        call    #CLOCK
                        call    #CLOCK
                        mov     outa,DESELECT             'das eigentliche Reset-Kommando $99
                        mov     outa,_RESET_B
                        call    #CLOCK
                        call    #CLOCK
                        mov     outa,DESELECT
                        jmp     #cog_ready

'**************************************************************************************
CLOCK                   or      outa,ClkPin            ' Toggle clock
                        xor     outa,ClkPin

CLOCK_ret               ret




_DIR_OUT      long %00000000_00000000_00001111_00000011
_DIR_IN       long %00000000_00000000_00000000_00000011
_BUS_INIT     long %00000000_00000000_00000000_00000000

_SIO0         long %00000000_00000000_00000001_00000011
_SIO0_Out0    long %00000000_00000000_00000000_00000000
_SIO0_Out1    long %00000000_00000000_00000001_00000000

_RESET_A      long %00000000_00000000_00000110_00000000 'Kommando Reset folgt $66
_RESET_B      long %00000000_00000000_00001001_00000000 'Kommando Reset $99


_COM38_A      long %00000000_00000000_00000011_00000000 'Kommando schreiben MSB
_COM38_B      long %00000000_00000000_00001000_00000000 'Kommando schreiben LSB

_COMEB        long %00000000_00000000_00001110_00000000 'Kommando lesen MSB
_COM0B        long %00000000_00000000_00001011_00000000 'Kommando lesen LSB

CLKPIN        long |< 1

ANDMASK       long %00000000_00000000_00001111_00000000
DESELECT      long %00000000_00000000_00000000_00000001



_job          res 1
_ptr          res 1
_adr          res 1
_val          res 1
_count        res 1
_tmp          res 1
_tmp2         res 1
_ftemp        res 1
_regA         res 1
_tmpval       res 1
_REGB         res 1
_REGC         res 1
                                                       fit 496
