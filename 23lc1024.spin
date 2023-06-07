{{
  Fast SPI RAM Driver. (requires a cog)
  Only access when nothing else is using the bus and only access from one cog
}}

VAR

long command_v
word hubaddr_v
word length_v

byte cog


PUB start(DO,CLK,DI,CS) | cmdp,hubp,lenp

  stop
  cmdp:= @command_v
  hubp:= @hubaddr_v
  lenp:= @length_v
  command_v~
  result := cog := cognew(@entry,@DO) + 1

  outa[DO]~~ '' Work around Ventilator hardware bug (missing MISO/SIO1 pullup)
  dira[DO]~~
'  special($ffffffff,1) 'reset to SPI mode
'  dira[DO]~
'  outa[DO]~

'  special($0140<<16,2) 'set sequential mode
  
  'waitcnt(cnt+10_000) 'wait for cog to actually start


PUB stop

  if cog
    cogstop(cog-1)
    cog~



PUB special(command,length)

  length_v := length
  hubaddr_v := 0
  command_v := command

  repeat while command_v


pub write(buffer,address,length)

  length_v := length
  hubaddr_v := buffer
  command_v := ((address<<8)|$02)->8
  repeat while command_v

pub read(buffer,address,length)
  length_v := length
  hubaddr_v := buffer
  command_v := ((address<<8)|$03)->8
  repeat while command_v

DAT

entry                   ''Get parameters
                        mov     t1,par
:get                    rdlong _DO,t1
                        add :get,destbit
                        add t1,#4
                        djnz iter,#:get

                        shl DImask,_DI
                        shl DOmask,_DO
                        shl CSmask,_CS
                        shl CLKmask,_CLK
                        movs ctr_clock,_CLK
                        movs ctr_read,_DO
                        movd ctr_read,_CLK
                        movs ctr_write,_DI
                        mov ctrb,ctr_clock
                        mov outa,CSmask
                        mov dira,CSmask
                        jmp #wait
                        
done                    nop
                        nop
                        or outa,CSmask
                        nop
                        nop
                        mov dira,CSmask ' release bus
                        wrlong zero,_command_ptr

wait                    ''Wait for command
                        rdlong serbuffer,_command_ptr wz
              if_z      jmp #wait
                        test  serbuffer,read_bit wc     'Is SPI->HUB?
              if_c      movs jmpxfer,#spi2hub
              if_nc     movs jmpxfer,#hub2spi
                        mov cmdlen,#4
                        rdword hubptr,_hubaddr_ptr wz '' get hub pointer (if zero, special command)
              if_z      movs jmpxfer,#done
                        rdword len,_length_ptr
              if_z      mov cmdlen,len

                        
                        ''aquire bus
                        mov outa,CSmask
                        or dira,CLKmask
                        or dira,DImask
                        

                        andn outa,CSmask

                        ''send out command
                        mov phsa,serbuffer
sendcmd                 call #out8
                        djnz cmdlen,#sendcmd                        
jmpxfer                 jmp #0-0

                        
                        
                        
spi2hub                 call #in8
                        wrbyte serbuffer,hubptr
                        add hubptr,#1
                        djnz len,#spi2hub
                        jmp #done


hub2spi                 rdbyte phsa,hubptr
                        add hubptr,#1
                        shl phsa,#24
                        call #out8
                        djnz len,#hub2spi
                        jmp #done
                        


{in8
        or outa,DImask
        mov iter,#8
:loop
        test DOmask,ina wc
        rcl serbuffer,#1
        or outa,CLKmask
        andn outa,CLKmask
        djnz iter,#:loop
        rev serbuffer,#24
in8_ret
        ret

out8    
        andn outa,DImask
        mov iter,#8
        mov ctra,ctr_write
:loop
        or outa,CLKmask
        andn outa,CLKmask
        rol phsa,#1
        djnz iter,#:loop
out8_ret           
        ret}

in8
        or outa,DImask
        mov ctra,ctr_read
        ' Start my clock
        mov frqa,#1<<7
        mov phsa,#0
        movi phsb,#%11_0000000
        movi frqb,#%01_0000000
        ' keep reading in my value, one bit at a time!  (Kuneko - "Wh)
        shr frqa,#1
        shr frqa,#1
        shr frqa,#1
        shr frqa,#1
        shr frqa,#1
        shr frqa,#1
        shr frqa,#1
        mov frqb,#0 ' stop the clock
        mov serbuffer,phsa
        mov frqa,#0
in8_ret
        ret

out8
        andn outa,DImask
        mov ctra,ctr_write
        movi phsb,#%11_0000000
        movi frqb,#%01_0000000
        'mov phsb,#0  
        'movi frqb,#%010000000
        rol phsa,#1
        rol phsa,#1
        rol phsa,#1
        rol phsa,#1
        rol phsa,#1
        rol phsa,#1
        rol phsa,#1
        mov frqb,#0 ' stop the clock
        rol phsa,#1 'shift out final bit                              
out8_ret           
        ret


destbit       long 512
zero          long 0
iter          long 1+(_length_ptr - _DO) ' init to number of parameters
ctr_clock long (%00110 << 26) {| (spiCLK << 0)} ' DUTY, 25% duty cycle
ctr_read long (%11000 << 26) {| (spiDO << 0) | (spiCLK << 9)}
ctr_write long (%00100 << 26) {| (spiDI << 0)}
read_bit long $01_00_0000
DOmask        long 1
CLKmask       long 1
DImask        long 1
CSmask        long 1



t1            res 1
serbuffer     res 1
len           res 1
hubptr        res 1
cmdlen        res 1

_DO           res 1
_CLK          res 1
_DI           res 1
_CS           res 1
_command_ptr  res 1
_hubaddr_ptr  res 1
_length_ptr   res 1                    


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
