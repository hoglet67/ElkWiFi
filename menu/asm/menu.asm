org &E00


tmp = &70


title_ptr = &72

OSRDCH = &FFE0
OSASCI = &FFE3
OSNEWL = &FFE7
OSWRCH = &FFEE
OSBYTE = &FFF4
OSCLI  = &FFF7

saved_title_lo = &C00
saved_title_hi = &C20


.start_addr


.test
{




    LDA #<titles
    STA title_ptr
    LDA #>titles
    STA title_ptr + 1


.loop1

    LDA #22
    JSR OSWRCH
    LDA #4
    JSR OSWRCH

    LDX #0
.loop2

    LDA title_ptr
    STA saved_title_lo, X
    LDA title_ptr+1
    STA saved_title_hi, X

    LDY #0
    LDA (title_ptr), Y
    CMP #&FF
    BMI done

    JSR print_title

    TYA
    CLC
    ADC title_ptr
    STA title_ptr
    LDA title_ptr + 1
    ADC #0
    STA title_ptr + 1

    INX
    CPX #24
    BNE loop2

.done

    JSR OSRDCH

    AND #&DF

    CMP #'Z' + 1
    BCS loop1

    CMP #'A'
    BCC loop1

    SBC #'A'
    TAX
    LDA saved_title_lo, X
    STA title_ptr
    LDA saved_title_hi, X
    STA title_ptr+1


    LDX #0

    ;; Get pointer to directory
    LDY #0
    LDA (title_ptr), Y
    TAY
    LDA dirlo,Y
    STA tmp
    LDA dirhi,Y
    STA tmp+1

    ;; Copy directory
    LDY #0
    JSR copy_tmp_string

    ;; Path sep
    LDA #'/'
    STA url, X
    INX

    ;; Copy Filename
    LDA title_ptr
    STA tmp
    LDA title_ptr+1
    STA tmp+1
    LDY #1
    JSR copy_tmp_string

    ;; A = suffix with bit set
    AND #&7F
    TAY
    LDA suflo,Y
    STA tmp
    LDA sufhi,Y
    STA tmp+1

    ;; Copy Suffix
    LDY #0
    JSR copy_tmp_string

    ;; Term
    LDA #13
    STA url, X

    LDA #22
    JSR OSWRCH
    LDA #6
    JSR OSWRCH

    ;; *QUPCFS
    LDX #<oscli0
    LDY #>oscli0
    JSR OSCLI

    ;; print *WGET for debugging
    LDX #0
.testloop
    LDA oscli1, X
    JSR OSASCI
    INX
    CMP #&0D
    BNE testloop

    ;; *WGET ...
    LDX #<oscli1
    LDY #>oscli1
    JSR OSCLI

    ;; *REWIND
    LDX #<oscli2
    LDY #>oscli2
    JSR OSCLI


    LDX #0
.c_loop
    STX tmp
    LDY chain,X
    BEQ c_done
    LDA #&99
    LDX #&00
    JSR OSBYTE
    LDX tmp
    INX
    BNE c_loop
.c_done

    RTS
}

.copy_tmp_string
{
.loop
    LDA (tmp), Y
    BEQ done
    BMI done
    STA url, X
    INX
    INY
    BNE loop
.done
    RTS
}


.oscli_load_data
    EQUB "*WGET -U http://192.168.0.205/DATA", 13

.chain
    EQUB "CHAIN ", &22, &22, &0D, &00

.oscli0
    EQUB "*QUPCFS", 13

.oscli1
    EQUB "*WGET -U http://192.168.0.207/uefarchive/"

.url
    SKIP &40

.oscli2
    EQUB "*REWIND", 13



;;.OSWRCH
;;{
;;    CMP #&80
;;    BCS ctrl
;;    CMP #&20
;;    BCS not_ctrl
;;.ctrl
;;    LDA #'#'
;;.not_ctrl
;;    JMP &FFEE
;;}


;; (title_ptr) points to title entry
.print_title
{
    TXA
    CLC
    ADC #'A'
    JSR OSWRCH
    LDA #' '
    JSR OSWRCH
    LDA #'['
    JSR OSWRCH
    LDY #0
    LDA (title_ptr), Y
    JSR print_dir
    LDA #']'
    JSR OSWRCH
    LDA #' '
    JSR OSWRCH
    LDA title_ptr
    STA tmp
    LDA title_ptr + 1
    STA tmp + 1
    LDY #1
    JSR print_camel_string
    INY
    JMP OSNEWL
}



;; A = directory id
.print_dir
{
    TAY
    LDA dirlo, Y
    STA tmp
    LDA dirhi, Y
    STA tmp + 1
    LDY #0
    ;; Fall through to print_camel_string
}

;; Print Camel-Cased String, inserting spaces where appropriate
;; (tmp),y points to string
;;
.print_camel_string
{
    LDA (tmp), Y
    JSR OSWRCH
.loop
    INY
    LDA (tmp), Y
    BEQ done
    BMI done
    CMP #'-'
    BEQ loop
    CMP #'A'
    BCC not_caps
    CMP #'Z'+1
    BCS not_caps
    PHA
    LDA #' '
    JSR OSWRCH
    PLA
.not_caps
    JSR OSWRCH
    JMP loop
.done
    RTS
}

include "data.asm"

.end_addr

SAVE "MENU", start_addr, end_addr
