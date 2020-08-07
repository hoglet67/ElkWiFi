 1332:HOST
 1334 .ASCII "TCP",#0D
 1336 .ASCII "WWW.ACORNATOM.NL",#0D
 1338 .ASCII "80",#0D,#00
 1340:HTTPGET
 1342 .ASCII "GET /atomwifi/time.php HTTP/1.1",#0D,#0A
 1344 .ASCII "HOST: www.acornatom.nl",#0D,#0A,#0D,#0A,#00
 1346 
 1350:SET_BUFFER
 1360 LDX @#70
 1370 LDY @#7F
 1380 LDA @11
 1390 JMP WIFIDRIVER
 1399 
 2000 \ DO YOUR THING FROM HERE....
 2005:DO_YOUR_THING
 2010 \ LIST ACCESS POINTS
 2015 JSR SET_BUFFER
 2020 LDA @8 \ OPEN TCP CONNECTION TO SERVER
 2025 LDX @HOST/256
 2027 LDY @HOST%256
 2030 JSR WIFIDRIVER
 2032 LDA @HTTPGET%256;STA #70
 2034 LDA @HTTPGET/256;STA #71
 2036 LDA @(SET_BUFFER-HTTPGET)%256;STA #72
 2038 LDA @(SET_BUFFER-HTTPGET)/256;STA #73
 2040 LDA @#00;STA #74
 2042 LDX @#70
 2044 LDA @13 \ SEND HTTP GET COMMAND
 2046 JSR WIFIDRIVER
 2060 LDA @#70
 2062 STA HAYSTACK+1
 2064 LDA @#00
 2070 STA HAYSTACK
 2080 LDA @TIMESTR%256
 2090 STA NEEDLE
 2100 LDA @TIMESTR/256
 2110 STA NEEDLE+1
 2120 LDA @5
 2130 STA SIZE
 2140 JSR FND
 2150 BCS DISPLAY_TIME
 2155 JSR #F7D1
 2160 .ASCII "NO DATE RECEIVED",#EA
 2170 BRK
 2173:TIMESTR
 2175 .ASCII "DATE="
 2180:DISPLAY_TIME
 2190 CLC
 2200 LDA @5
 2210 ADC ZP
 2220 STA ZP
 2230 LDA ZP+1
 2240 ADC @#00
 2250 STA ZP+1
 2252 LDA @CH"2";JSR #FFF4
 2254 LDA @CH"0";JSR #FFF4
 2260 JSR PRINT_STRING
 2270 JMP #FFED
 2280 
 2900:INC_POINTER
 2910 INC ZP
 2920 BNE IP1
 2930 INC ZP+1
 2940:IP1
 2950 RTS
 2960 
 3000:PRINT_STRING
 3010 LDY @0
 3020:PS1
 3030 LDA (ZP),Y
 3040 JSR #FFF4
 3050 CMP @#0D
 3060 BEQ PS2
 3070 JSR INC_POINTER
 3080 BPL PS1
 3090:PS2
 3100 RTS
 3110 
 4900 \ FIND ROUTINE: SEARCH FOR A NEEDLE IN A HAYSTACK
 4910 \ ZEROPAGE: HAYSTACK = POINTER TO MEMORY BLOCK 
 4920 \           NEEDLE   = POINTER TO STRING
 4930 \           SIZE     = NUMBER OF BYTES TO SEARCH
 4940 \ ON EXIT:  CARRY = 1: STRING FOUND, HAYSTACK POINTS TO ST
 4950 \           CARRY = 0: STRING NOT FOUND
 5000:FND
 5010 LDY @0
 5020 LDX SIZE
 5030:FND1
 5040 LDA (HAYSTACK),Y
 5050 CMP (NEEDLE),Y
 5060 BNE FND2
 5070 INY
 5080 CPY SIZE
 5100 BNE FND1
 5110 SEC
 5120 RTS
 5130:FND2
 5135 LDY @0
 5140 JSR INC_POINTER
 5145 LDA HAYSTACK+1
 5150 BPL FND1
 5160 CLC
 5170 RTS
 5180 
 9970 
 9980 .END
 9990 RETURN
>P.$3
