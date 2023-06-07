{{
  Driver for Winbond SPI Flash Memory (W25X16AVDAIZ 2MB)
  It also supports similar Winbond 4MB and 8MB flash memories.
  It also supports 1 or 2 Microchip 23K256 SPI SRAMSs.
  
  A file system is supported with 8.3 file names and the usual
  edited output methods are provided for strings and decimal,
  hexadecimal, and binary values.  Multiple files can be open
  at the same time with each file requiring a file control block.

  Copyright (c) 2009 by Michael Green
       See end of file for terms of use.
}}

'' The start method is used to supply pin numbers for both the
'' Winbond Flash and Microchip SRAM chips.  Separate CS pins
'' are required for each chip.  If a chip is not provided, -1
'' should be used for the CS pin number.  The Clk, DI (DIO),
'' and DO pins are shared (in common) for all the chips used.
'' If present, the SRAM chips are initialized for sequential
'' mode.  If present, the size of the flash memory is read
'' from the device and available using the flashSize method.
'' To speed up searches for files and free space, a bitmap
'' of erased 4K sectors is initialized by the start method
'' and kept up to date as sectors are allocated and erased.

'' sendRecv is the low level SPI driver.  It provides for
'' sending a command code plus an address or other control
'' information followed by sending a block of data or receiving
'' a block of data.  There's no checking possible.

'' readSRAM and writeSRAM are the main user routines for SRAM
'' use.  See the method description below for details.  Note
'' that, although multiple 23K256 SRAMs are treated as one
'' contiguous address space, a single readSRAM or writeSRAM
'' that appears to span multiple SRAMs will not work as expected.
'' Each readSRAM or writeSRAM operation selects a single device
'' and the address will wraparound at the next 32K boundary.

'' readData, writeData, and eraseData are the main user routines
'' for Winbond flash access.  Reading can start at any address
'' and continue to the end of flash memory.  Writing can start
'' at any address and continue to the end of flash memory.  The
'' locations being written must be erased (value $FF) and the
'' write operation is done in 256 byte pages internal to the
'' write routine.  The erase operation is done for the 4K block
'' containing the address passed to eraseData.

'' initFile, openFile, createFile, eraseFile, readFile, writeFile,
'' firstFile, nextFile, and bootFile all support a file system
'' where files are allocated in 4K blocks.  There's no central
'' directory and file name and segment information is stored
'' in each 4K file segment.  Hashing is used to spread the
'' segments of a file across the flash memory to try to do simple
'' wear levelling.

'' To do a directory listing, you need to call firstFile to initialize an FCB.
'' Each time nextFile is called, either a file name is copied to the FCB or
'' nextFile returns FALSE indicating that no further file names are available.

'' openFile is used to open a file for sequential reading.  The file must be
'' present on the flash drive or FALSE is returned.

'' createFile is used to create a file for sequential writing.  If the file
'' is already present, it is erased.  The first 4K file segment of the new
'' file is allocated.  If there's no free space, FALSE is returned.

'' eraseFile is used to erase all segments of the file whose name is in the FCB.
'' If the file doesn't already exist, FALSE is returned.

'' readFile provides for sequential reading from an opened FCB.  This returns
'' FALSE if an attempt is made to read past the end of space allocated to the
'' file.  readFile keeps track (in the FCB) of the file position.

'' writeFile is used to sequentially write a file initialized with createFile.
'' New file space is allocated as needed as the file is written.  writeFile
'' returns FALSE if there's no free space when needed.  The file position is
'' recorded in the FCB.  There's no inherent end of file marker nor is the file
'' length recorded in the file.  Note that a file is initially erased to $FF.

'' bootFile is used to load and execute a Spin program from an opened file
'' beginning at the current file position (as stored in the FCB).  An assembly
'' loader is started in the cog calling bootFile.  This loader stops all other
'' cogs except for up to 2 cogs possibly running a video driver.  These are
'' supplied (prior to calling bootFile) with the setVideo call.  The intention
'' is that the video buffer may be in the high end of memory where it won't be
'' overlaid with the new program and the one or two cog video driver can be
'' left running while the new program loads and starts up.  The new Spin
'' interpreter is loaded into the cog used for the loader.
 
'' There's a file control block (FCB) associated with any file I/O.
''
'' ***********************************************************
'' *                    File Name Bytes 1-4                  *
'' ***********************************************************
'' *                    File Name Bytes 5-8                  *
'' ***********************************************************
'' * File Segment *        File Extension Bytes 1-3          *
'' ***********************************************************
'' *    Reserved  *          Current File Address            *
'' ***********************************************************
''
'' File Name      - Up to 8 bytes, padded with $FF
'' File Extension - Up to 3 bytes, padded with $FF
'' File Segment   - $00 to $FE.  $FF used for erased blocks
'' File Address   - Current flash memory address of file position
''
'' Each 4K block has a 16 byte prefix leaving 4080 bytes for data.
'' This prefix contains the first 12 bytes of the file control block,
'' followed by a word with the block number of the next block in the
'' file.  A value of $FFFF indicates that there's no next block.
'' The last word of the prefix is currently unused.
''
'' ***********************************************************
'' *                    File Name Bytes 1-4                  *
'' ***********************************************************
'' *                    File Name Bytes 5-8                  *
'' ***********************************************************
'' * File Segment *        File Extension Bytes 1-3          *
'' ***********************************************************
'' *          Reserved         *      Next Block Number      *
'' ***********************************************************

CON WrStat   = $01_00                  ' Write Status / Data
    WrData   = $02_000000              ' Write Data / Address / Data
    WrSRAM   = $02_0000                ' Write SRAM / Address / Data
    RdData   = $03_000000              ' Read Data / Address / (Data)
    RdSRAM   = $03_0000                ' Read SRAM / Address / (Data)
    Status   = $05                     ' Read Status / (Data)
    WrtEna   = $06                     ' Write Enable
    SecEra   = $20_000000              ' Erase Sector / Address
    JEDEC    = $9F                     ' Return JEDEC device info
    JEDEC2M  = $1540EF                 '  2MB Flash Memory (W25X16/16A)
    JEDEC4M  = $1640EF                 '  4MB Flash Memory (W25X32)
    JEDEC8M  = $1740EF                 '  8MB Flash Memory (W25X64)
    JEDEC16  = $1840EF                 ' 16MB Flash Memory (W25X128)
    FLASH    = 1                       ' Device # for Flash Memory
    INV_DEV  = 2                       ' Invalid device number
{    SRAM0    = 0                       ' Device # for SRAM 0
    SRAM1    = 1                       ' Device # for SRAM 1
    FLASH    = 2                       ' Device # for Flash Memory
    invDev   = 3                       ' Invalid device number
}
    Busy     = $01                     ' Busy Status
    AllOnes  = $FFFFFFFF               ' All one bits (erased)

    maxSeg   = $FE                     ' Last file segment (4K)
    secSize  = 4096                    ' Number of bytes in sector
    secHdr   = 32'16                      ' Space in each sector for header
    secMask  = secSize - 1             ' Mask for sector size
    dataSize = secSize - secHdr        ' Space in sector for user data

    initCkSm = ($FF+$FF+$F9+$FF)*2     ' Initial checksum (stack marker)

VAR long maxSize                       ' Size of Flash Memory
    long cog                           ' Cog used for assembly routine
    long params[3]                     ' Parameters to assembly I/O driver
    long CSpin, Clkpin, DIOpin, DOpin  ' I/O pins
    long CSpin0, CSpin1                ' SRAM CS I/O pins
    long freeMap[128]                   ' One bit per block (erased blocks) 64 auf 128 erhöht für 16MB Flash
    long laenge
    byte INFO[16]


obj rtc             : "adm-rtc"'"DSRTC_driver"'

PUB start(CS, Clk, DIO, DO, CS0, CS1) | i ' Initialize the object
'  CS  = Pin number for Winbond Flash Memory chip (or -1 if none)
'  Clk = Pin number for clock line on all chips
'  DIO = Pin number for DIO or DI line on all chips
'  DO  = Pin number for DO line on all chips
'  CS0 = Pin number for first Microchip SRAM chip (or -1 if none)
'  CS1 = Pin number for second Microchip SRAM chip (or -1 if none)
   stop                                ' Stop any running I/O driver
   DOMask   := |< DO
   DIOMask  := |< DIO                  ' Initialize the I/O masks
   ClkMask  := |< Clk
   CSflshMask   := |< CS
'   CS0Mask  := |< CS0
'   CS1Mask  := |< CS1
   outaMask := CSflshMask'CSMask '| CS0Mask | CS1Mask
   diraMask := DIOMask | ClkMask | CSflshMask'CSMask '| CS0Mask | CS1Mask
   params[0] := params[1] := 0         ' Clear the parameters
   params[2] := inv_Dev
   ifnot cog := cognew(@entryPoint,@params) + 1
      return false                     ' Quit if can't start cog
{   if CS0 <> -1
      sendRecv(0,WrStat|%0100_0001,0,0) ' Sequential mode, no HOLD mode
   if CS1 <> -1
      sendRecv(1,WrStat|%0100_0001,0,0)}
   longfill(@freeMap,0,128)             ' Mark bits of erased blocks
   maxSize := -1                       ' Default is unknown size flash
   if CS <> -1
      case sendRecv(FLASH,JEDEC,3,0)       ' Get JEDEC code for the device
         JEDEC2M: maxSize := 2 * |<20  ' Winbond W25X16/16A - 2MB Flash
         JEDEC4M: maxSize := 4 * |<20  ' Winbond W25X32     - 4MB Flash
         JEDEC8M: maxSize := 8 * |<20  ' Winbond W25X64     - 8MB Flash
         JEDEC16: maxSize :=16 * |<20  ' Winbond W25X128    -16MB Flash
      'return maxsize
      result:=freeSize
PUB stop
   if cog                              ' Stop any running I/O driver
      cogstop(cog~ - 1)

{PUB setVideo(cogNo1,cogNo2)            ' Set cog numbers for VGA driver
   videoCog1 := cogNo1                 ' Supply -1 for a cog number not used
   videoCog2 := cogNo2                 ' These will not be stopped on a boot
}
PUB flashSize                          ' Return the size of the mgc#a_FlashSizeemory in bytes
   return maxSize
pub freeSize|i
      repeat i from 0 to maxSize-secSize step secSize
         if readData(i+11,0,-1) == $FF ' Is block erased?
            freeMap[i>>17] |= |< (i>>12 & $1F)
            result++                   ' Count free space in blocks

Pub FlashID
    return sendRecv(Flash,$9F,3,0)

pub sendRecv(d, sD, rCt, rA) | i, m    ' Send and possibly receive
'  d   = Device to be used: 0 - SRAM0, 1 - SRAM1, 2 - Winbond Flash
'  sD  = Value to be sent MSB first, right justified in parameter
'  rCt = Number of bytes to be transferred (>0 received, <0 sent)
'  rA  = 0 or address of buffer area.  If 0, @RESULT is used
   repeat while params.byte[8] < inv_Dev ' Wait until done
   params.long[0] := sD                ' Possible literal value
   params.word[2] := rCt               ' Byte count
   if rA
      params.word[3] := rA
   else
      params.word[3] := @result        ' Use RESULT if rA is zero
   params.byte[8] := d                 ' Set device to use (starts)
   repeat while params.byte[8] < inv_Dev ' Wait until done

PUB readSRAM(addr, data, count)        ' Read bytes from SRAM
'  addr  = SRAM memory starting address for reading data
'  data  = Hub starting address for data
'  count = Number of bytes to be read from SRAM memory
'          If count is -1 to -4, use @RESULT for data address
   if count < 0
      sendRecv(addr>>15,RdSRAM|(addr&$7FFF),-count,@result)
   else
      sendRecv(addr>>15,RdSRAM|(addr&$7FFF),count,data)

PUB writeSRAM(addr, data, count)       ' Write bytes to SRAM
'  addr  = SRAM memory starting address for writing data
'  data  = Hub starting address for data or data itself
'  count = Number of bytes to be written to SRAM memory
'          If count is -1 to -4, use @data for data address
   if count < 0
      sendRecv(addr>>15,WrSRAM|(addr&$7FFF),count,@data)
   else
      sendRecv(addr>>15,WrSRAM|(addr&$7FFF),-count,data)

PUB readData(addr, data, count)        ' Read bytes from flash memory
'  addr  = Flash memory starting address for reading data
'  data  = Hub starting address for data
'  count = Number of bytes to be read from flash memory
'          If count is -1 to -4, use @RESULT for data address
   if count < 0
      sendRecv(FLASH,RdData|addr,-count,@result)
   else
      sendRecv(FLASH,RdData|addr,count,data)

PUB WriteData(Addr, Data, Count) | DataPointer, Offset ' Write bytes to flash memory
{
   Addr  = Flash memory starting address for writing data
   Data  = Hub starting address for data or data itself
   Count = Number of bytes to be written to flash memory
           If Count is -1 to -4, use @Data for data address
   This routine handles the process of writing to flash memory
   in pages of 256 bytes or less (aligned to 256 page boundaries)
}
   if Count < 0
      DataPointer := @Data
      Count := -Count
   else
      DataPointer := Data
   repeat while Count > 0                               ' Handle end of page, full pages,
      Offset := Count <# (256 - (Addr & $FF))           ' and last partial page
      sendRecv(FLASH, WRTENA, 0, 0)                    ' Enable writes
      sendRecv(FLASH, WRDATA | Addr, -Offset, DataPointer)
      repeat until sendRecv(FLASH, STATUS, 1, 0) & BUSY == 0 ' Wait until done
      Addr += Offset
      DataPointer += Offset                             ' Advance pointers
      Count -= Offset

PUB eraseData(addr)                    ' Erase a 4K sector of flash
'  addr  = Flash memory address within sector to be erased
   sendRecv(FLASH,WrtEna,0,0)              ' Enable writes
   sendRecv(FLASH,SecEra|addr,0,0)         ' Erase 4K sector
   freeMap[addr>>17] |= |< (addr>>12 & $1F) ' Mark sector
   repeat until sendRecv(FLASH,Status,1,0) & Busy == 0 ' Wait until done

PRI readClock |y' 3 + 11 Stack Longs
  'rtc.ReadClock
  repeat while(lockset(cardLockID))
  info[0]:=rtc.getSeconds
  info[1]:=rtc.getMinutes
  info[2]:=rtc.getHours
  y:=rtc.getYear
  info[3]:=y & $FF
  info[4]:=y>>8
  info[5]:=rtc.getDate
  info[6]:=rtc.getMonth
  lockclr(cardLockID)


PUB initFile(p,s,sz) | i, c               ' Initialize file control block
'  p     = Address of file control block as described earlier
'  s     = Address of start of a string containing a file name and extension
'  returns true if a valid file name (and extension) is parsed, false otherwise
'          The file control block is initialized to the normalized file name
'          Valid file name characters include letters, digits, "-", and "_".
'          Only the first 8 characters of the file name are kept and only the
'          first 3 characters of the file extension are kept.  A "." separates
'          the file name and extension.
   repeat i from 0 to 7
      long[p][i] := AllOnes
   i := 0
   readclock
   laenge:=sz

   repeat
      case c := byte[s++]
         "-", "0".."9", "A".."Z", "_", "a".."z":
            if i < 8
               byte[p][i++] := c
         ".":
            quit
         0: return long[p][0] & long[p][1] <> $FFFFFFFF
         other:
            return false
   i := 8
   repeat
      case c := byte[s++]
         "-", "0".."9", "A".."Z", "_", "a".."z":
            if i < 11
               byte[p][i++] := c
         0: return long[p][0] & long[p][1] <> $FFFFFFFF
         other:
            return false


PRI findFile(p) | i,x,z,a,b,c,d,e          ' Find match for specified file
'  p     = Address of file control block as described earlier
'  returns true if found, false if not found.  File control block updated.
'  The file control block is used to choose the starting segment for the
'  search and the "random" operator is applied as well to attempt to
'  scatter the file segments around the flash memory to provide some
'  "wear levelling".
   x := long[p][0] ^ long[p][1] ^ long[p][2]
   x := x? & constant(!secMask)
   repeat i from 0 to maxSize-secSize step secSize
      z := (i + x) & (maxSize-1)                                                ' Scatter file segments around
      if freeMap[z>>17] & |< (z>>12 & $1F)                                      ' Check for free blocks
         next
      readData(z,@a,12)


      if long[p][0] == a and long[p][1] == b and long[p][2] == c
         long[p][3] := byte[p][15] << 24 | (z + 32)'16)
         readData(z+16,@info,12)                                                   'Datei-Infos lesen


         return true
   return false

PRI findFree(p) | i,x,z,a,b,c,e          ' Find erased file segment
'  p     = Address of file control block as described earlier
'  returns true if found, false if not found.  File control block updated.
'  The file control block is used to choose the starting segment for the
'  search and the "random" operator is applied as well to attempt to
'  scatter the file segments around the flash memory to provide some
'  "wear levelling".  The first erased segment found is initialized.
   x := long[p][0] ^ long[p][1] ^ long[p][2]
   x := x? & constant(!secMask)
   repeat i from 0 to maxSize-secSize step secSize
      z := (i + x) & (maxSize-1)       ' Scatter file segments around
      ifnot freeMap[z>>17] & |< (z>>12 & $1F) ' Check for used blocks
         next
      readData(z,@a,12)
      if a == AllOnes and b == AllOnes and c == AllOnes
         long[p][3] := byte[p][15] << 24 | (z + 32)'16)
         writeData(z,p,12)             ' Write file name & segment #
         writeData(z+16,@info,8)       'Datum und Zeit, Dateigröße
         writeData(z+24,laenge,-4)


         freeMap[z>>17] &= ! |< (z>>12 & $1F) ' Mark as not erased
         return true
   return false
Pub Fattrib(n):wert
''                              : anr - 0  = Dateigröße
''                              :       1  = Erstellungsdatum - Tag
''                              :       2  = Erstellungsdatum - Monat
''                              :       3  = Erstellungsdatum - Jahr
''                              :       4  = Erstellungsdatum - Sekunden
''                              :       5  = Erstellungsdatum - Minuten
''                              :       6  = Erstellungsdatum - Stunden
''                              :       7  = Zugriffsdatum - Tag
''                              :       8  = Zugriffsdatum - Monat
''                              :       9  = Zugriffsdatum - Jahr
''                              :       10 = Änderungsdatum - Tag
''                              :       11 = Änderungsdatum - Monat
''                              :       12 = Änderungsdatum - Jahr
''                              :       13 = Änderungsdatum - Sekunden
''                              :       14 = Änderungsdatum - Minuten
''                              :       15 = Änderungsdatum - Stunden
''                              :       16 = Read-Only-Bit
''                              :       17 = Hidden-Bit
''                              :       18 = System-Bit
''                              :       19 = Direktory
''                              :       20 = Archiv-Bit
''                              : wert - wert des abgefragten attributes
    case n
         0:wert:=laenge:=info[8]+info[9]<<8+info[10]<<16+info[11]<<24
         1:wert:=info[5]
         2:wert:=info[6]
         3:wert:=info[4]<<8 + info[3]
         4:wert:=info[0]
         5:wert:=info[1]
         6:wert:=info[2]

PUB firstFile(p)                      ' Init file control block for dir list
   long[p][3] := byte[p][15] << 24    ' Start with first 4K segment in memory

PUB nextFile(p) | t                   ' Look for next file in flash memory
   repeat t from long[p][3] & $00FFFFFF to maxSize-secSize step secSize
      if freeMap[t>>17] & |< (t>>12 & $1F) ' Check for erased block
         next
      readData(t,p,12)                ' Get the directory entry
      if byte[p][11] == 0             ' Is this the 1st segment in the file?
         readData(t+16,@info,12)         ' Datum und Zeit, Dateigröße
         'readData(t+24,laenge,-4)
         long[p][3] := byte[p][15] << 24 | (t + secSize)
         return true
   return false

PUB openFile(p)                       ' Open file for reading
'  p     = Address of file control block as described earlier
'  returns true if successful, false if file doesn't exist.
'          File control block initialized for first read from start of file
   long[p][2] &= $00FFFFFF            ' Set current segment to $00
   if findFile(p)                     ' Look for specified file
      return true
   long[p][2] |= $FF000000            ' Invalid file segment
   return false

PUB eraseFile(p) | c, n               ' Erase existing file
'  p     = Address of file control block as described earlier
'  returns true if successful, false if file doesn't exist
'          All blocks / segments of the file are erased.
   long[p][2] &= $00FFFFFF            ' Set current segment to $00
   if findFile(p)                     ' Specified file must be present
      c := long[p][3] & $00FFF000     ' Start of current file segment
      repeat until c == $0FFFF000     ' Continue until link == $FFFF
         n := c
         c := readData(n+12,0,-2)<<12 ' Get link to next segment
         eraseData(n)                 ' Erase current segment
      return true
   return false

PUB createFile(p) | c, n              ' Open file for writing
'  p     = Address of file control block as described earlier
'  returns true if successful, false if flash memory is full.
'          File control block initialized for first write to start of file
'          If the file already exists, it is erased before creating a new one
   if long[p][0] & long[p][1] & (long[p][2] | $FF000000) == $FFFFFFFF
      return false                    ' Can't create file with empty name
   long[p][2] &= $00FFFFFF            ' Set current segment to $00
   if findFile(p)                     ' If file already exists, erase it
      c := long[p][3] & $00FFF000     ' Start of current file segment
      repeat until c == $0FFFF000     ' Continue until link == $FFFF
         n := c
         c := readData(n+12,0,-2)<<12 ' Get link to next segment
         eraseData(n)                 ' Erase current segment
   if findFree(p)                     ' Allocate first segment
      return true                     '  probably in same location
   long[p][2] |= $FF000000            ' Invalid file segment
   return false

PUB readFile(p,a,c) | f, n, h         ' Read data from a file
'  p     = Address of file control block as described earlier
'  a     = Address of area to receive data from the file
'  c     = Count of number of bytes to be read
'  returns true if successful, false if an end of file occurs
'          The read begins at the Current File Address in the file control
'          block.  The Current File Address is updated as necessary.  Note
'          that there is no end of file marker other than the lack of further
'          4K blocks in the file.
   f := long[p][3] & $00FFFFFF        ' Current file position
   h := f & $FFF000 + 12              ' Position of link to next block
   if f & $FFF => secHdr              ' Positioned in data area?
      n := c <# $1000 - (f & $FFF)    ' Remainder in block
      readData(f,a,n)                 ' Read the data
      f += n
      if f & $FFF == 0                ' File position at end of block?
         f -= secSize                 ' Leave pointing at beginning for
      a += n                          '  access to the next block link
      c -= n                          ' Advance the pointers
   repeat while c > 0                 ' Any blocks left to read?
      if byte[p][11] == $FE           ' Too many segments?
         return false
      byte[p][11] += 1                ' Increment segment number
      f := readData(h,0,-2)<<12       ' Get link to next block
      if f == $0FFFF000               ' Reached end of file
         return false
      h := f & $FFF000 + 12           ' Position of link to next block
      f += secHdr                     ' Start of data area
      n := c <# dataSize              ' Amount to read
      readData(f,a,n)                 ' Read the data
      f += n
      if f & $FFF == 0                ' File position at end of block?
         f -= secSize                 ' Leave pointing at beginning for
      a += n                          '  access to the next block link
      c -= n                          ' Advance the pointers
   long[p][3] := byte[p][15] << 24 | f ' Update file pointer
   return true

PUB writeFile(p,a,c) | f, n, h        ' Write data to a file
'  p     = Address of file control block as described earlier
'  a     = Address of area containing data to be written to the file
'  c     = Count of number of bytes to be written
'  returns true if successful, false if new block needed and none available
'          The write begins at the Current File Address in the file control
'          block.  The Current File Address is updated as necessary.  When
'          the write operation fills the current block, a new block is
'          allocated, the block's header is initialized, and the write
'          operation continues in the new block.
   f := long[p][3] & $00FFFFFF        ' Current file position
   h := f & $FFF000 + 12              ' Position of link to next block
   if f & $FFF => secHdr              ' Positioned in data area?
      n := c <# $1000 - (f & $FFF)    ' Remainder in block
      writeData(f,a,n)                ' Write the data
      f += n
      if f & $FFF == 0                ' File position at end of block?
         f -= secSize                 ' Leave pointing at beginning for
      a += n                          '  access to the next block link
      c -= n                          ' Advance the pointers
   repeat while c > 0                 ' Any blocks left to write?
      if byte[p][11] == $FE           ' Too many segments?
         return false
      byte[p][11] += 1                ' Increment segment number
      ifnot findFree(p)               ' Request a new one
         return false
      f := long[p][3] & $00FFFFFF
      writeData(h,f>>12,-2)           ' Update file link
      h := f & $FFF000 + 12           ' Position of link to next block
      n := c <# dataSize              ' Amount to write
      writeData(f,a,n)                ' Write the data
      f += n
      if f & $FFF == 0                ' File position at end of block?
         f -= secSize                 ' Leave pointing at beginning for
      a += n                          '  access to the next block link
      c -= n                          ' Advance the pointers
   long[p][3] := byte[p][15] << 24 | f ' Update file pointer
   return true

PUB writeStr(p,s)                     ' Write a string to a file
'  p     = Address of file control block as described earlier
'  s     = Address of zero-terminated string
'  returns true if successful, false if new block needed and none available
'          The write begins at the Current File Address in the file control
'          block.  The Current File Address is updated as necessary.  When
'          the write operation fills the current block, a new block is
'          allocated, the block's header is initialized, and the write
'          operation continues in the new block.
   return writeFile(p,s,strsize(s))

PUB dec(p,value) | s, i, f0,f1,f2      ' Output decimal value
'  p     = Address of file control block as described earlier
'  value = Value to be converted to a string of digits with a leading "-"
'  returns true if successful, false if new block needed and none available
'          The write begins at the Current File Address in the file control
'          block.  The Current File Address is updated as necessary.  When
'          the write operation fills the current block, a new block is
'          allocated, the block's header is initialized, and the write
'          operation continues in the new block.
'          Note: This will produce "-0" for value == $80000000
   result := 0
   s~                                  ' No significant digits yet
   if value < 0
      -value                           ' Leading sign if negative
      f0.byte[result++] := "-"
   i := 1_000_000_000                  ' Up to 10 decimal digits
   repeat 10
      if value => i
         f0.byte[result++] := value/i + "0" ' Output the digit
         value //= i
         s~~                           ' Indicate significant digit
      elseif s or i == 1
         f0.byte[result++] := "0"      ' Output leading zero
      i /= 10
   return writeFile(p,@f0,result)

PUB hex(p, value, digits) | f0,f1      ' Output hexadecimal value
'  p      = Address of file control block as described earlier
'  value  = Value to be converted to a string of hexadecimal digits
'  digits = Number of hexadecimal digits to be used.
'  returns  true if successful, false if new block needed and none available
'           The write begins at the Current File Address in the file control
'           block.  The Current File Address is updated as necessary.  When
'           the write operation fills the current block, a new block is
'           allocated, the block's header is initialized, and the write
'           operation continues in the new block.
  value <<= (8 - digits) << 2
  result := 0
  repeat digits
    f0.byte[result++] := lookupz((value <-= 4) & $F : "0".."9", "A".."F")
  return writeFile(p,@f0,digits)

PUB bin(p, value, digits) | f0,f1,f2,f3,f4,f5,f6,f7 ' Output binary value
'  p      = Address of file control block as described earlier
'  value  = Value to be converted to a string of binary digits
'  digits = Number of binary digits to be used.
'  returns  true if successful, false if new block needed and none available
'           The write begins at the Current File Address in the file control
'           block.  The Current File Address is updated as necessary.  When
'           the write operation fills the current block, a new block is
'           allocated, the block's header is initialized, and the write
'           operation continues in the new block.
  value <<= 32 - digits
  result := 0
  repeat digits
    f0.byte[result++] := (value <-= 1) & 1 + "0"
  return writeFile(p,@f0,digits)

PUB bootFile(p) | c                   ' Start Spin program from open file
'  p     = Address of file control block as described earlier
'  This routine starts up the loader in the current cog.  This loader stops
'  all other cogs, then loads in the currently open file (from the FCB) and
'  starts a new Spin interpreter in the cog used by the loader.  The header
'  in the 1st 16 bytes of the program is used to provide the size of the
'  program to be loaded, the starting address of the program's stack area,
'  and the size and location of the program's variable area.  These are used
'  to initialize the stack and the variable area.  The clock is reinitialized
'  if the clock frequency or mode is changed for the new program.
   stop                                ' Stop current I/O driver
   coginit(cogid,@entryPoint,((long[p][3]>>10)&$7FFC)|$8000)
   repeat                              ' Wait until cog restarted
dat
DAT ' I/O driver for flash and SRAM
{{
  I/O driver for flash and SRAM.  If the address passed in PAR is > 32K,
  it is the starting block number of the file to be loaded * 4.  If the
  address is < 32K, it is the address of a three long parameter block.
  The first long is a 0 to 4 byte literal value to be transmitted to the
  device as described in sendRecv.  The next word is the number of bytes to
  be read (> 0) or written (< 0).  The next word is the starting address for
  the transfer.  The next byte is the device number.  1 is the flash chip.
  0 is the SRAM chip.  After the operation is completed, the byte count is
  set to zero and the address is updated.
}}
                        org     0
EntryPoint              mov     FlashTemp,PAR
                        rdlong  Preamble+0,FlashTemp    ' Get parameters
                        add     FlashTemp,#4
                        rdword  Preamble+1,FlashTemp    ' Byte count
                        add     FlashTemp,#2
                        test    Preamble+1,StartROM  wc ' Extend word sign
                        rdword  Preamble+2,FlashTemp    ' Starting address
                 if_c   or      Preamble+1,WordSign
                        add     FlashTemp,#2
                        rdbyte  Preamble+3,FlashTemp    ' Device #
                        cmp     Preamble+3,#INV_DEV  wc ' If invalid device #,
                if_nc   jmp     #EntryPoint             '  go back and wait
                        or      outa,OutaMask           ' Will set /WP, /HOLD
                        andn    outa,ClkMask            '  make sure Clk low
                        or      dira,DiraMask           ' DOpin is only input
                        movs    :SelectDev,#CSsramMask
                        add     :SelectDev,Preamble+3   ' Select proper /CS
                        movs    SkipRecv,:SelectDev
                        mov     FlashMask,#$FF          ' Set up sending mask
                        shl     FlashMask,#24           ' m := $FF000000
:SelectDev              andn    outa,0-0                ' Select device
:ScanMask               test    Preamble+0,FlashMask wz ' sD & m == 0?
                 if_z   shr     FlashMask,#8            '  m >>= 8, m == 0?
                 if_z   tjnz    FlashMask,#:ScanMask
                        and     FlashMask,MSBMask       ' m &= $80808080
                        tjz     FlashMask,#:SkipImm     ' Skip if nothing
:SendImm                test    Preamble+0,FlashMask wz ' Output bit to be sent
                        muxnz   outa,DIOMask
                        or      outa,ClkMask            ' Toggle clock
                        andn    outa,ClkMask
                        shr     FlashMask,#1            ' Advance bit mask
                        tjnz    FlashMask,#:SendImm     ' Continue to lsb
:SkipImm                test    Preamble+1,CmdMask   wc ' If byte count < 0
                if_nc   jmp     #SkipSend               '  then transmit data
                        neg     Preamble+1,Preamble+1   ' Make transmit count
SendData                mov     FlashMask,#$80          '  positive
                        rdbyte  FlashTemp,Preamble+2    ' Get the data byte and
                        add     Preamble+2,#1           '  increment address
:BitLoop                test    FlashTemp,FlashMask  wz ' Output bit to be sent
                        muxnz   outa,DIOMask
                        or      outa,ClkMask            ' Toggle clock
                        andn    outa,ClkMask
                        shr     FlashMask,#1            ' Advance bit mask
                        tjnz    FlashMask,#:BitLoop     ' Continue to lsb
                        djnz    Preamble+1,#SendData    ' Continue to next byte
SkipSend                andn    dira,DIOMask            ' Don't need DIO now
                        tjz     Preamble+1,#SkipRecv    ' Skip if count == 0
RecvByte                mov     FlashMask,#$80
:BitLoop                or      outa,ClkMask            ' Toggle clock
                        test    DOMask,ina           wz ' Test input bit
                        muxnz   FlashTemp,FlashMask     ' Copy to result byte
                        andn    outa,ClkMask
                        shr     FlashMask,#1            ' Advance bit mask
                        tjnz    FlashMask,#:BitLoop     ' Continue to lsb
                        wrbyte  FlashTemp,Preamble+2    ' Store the data byte
                        add     Preamble+2,#1           ' Increment address
                        djnz    Preamble+1,#RecvByte    ' Continue to next byte
SkipRecv                or      outa,0-0                ' Deselect device
                        mov     FlashTemp,PAR           ' Force invalid device #
                        add     FlashTemp,#8            '  to notify sendRecv
                        andn    dira,DiraMask           ' Turn off all outputs
                        wrbyte  WordMask,FlashTemp      '  after /CS high >100ns
                        jmp     #EntryPoint

CmdMask                 long    $80000000               ' Also used for long sign
MSBMask                 long    $80808080               ' MSB mask for reading
WordMask                long    $FFFF
WordSign                long    $FFFF0000               ' For extending word sign
StartROM                long    $8000                   ' Also used for word sign
DiraMask                long    0                       ' DIO, Clk, CS all outputs
OutaMask                long    0                       ' DIO, Clk, selected CS
DOMask                  long    0                       ' DO from flash
DIOMask                 long    0                       ' DIO to flash
ClkMask                 long    0                       ' Clock to flash
CSsramMask              long    0                       ' CS to SRAM  - Dev #0
CSflshMask              long    0                       ' CS to flash - Dev #1
cardLockID              byte 0 'frida ((HUB_Lock <# 7) #> 0)

FlashTemp               res     1
FlashMask               res     1

Preamble                res     4

