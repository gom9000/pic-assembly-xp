;=============================================================================
; @(#)xp-scheduler.asm
;                       ________.________
;   ____   ____  ______/   __   \   ____/
;  / ___\ /  _ \/  ___/\____    /____  \ 
; / /_/  >  <_> )___ \    /    //       \
; \___  / \____/____  >  /____//______  /
;/_____/            \/                \/ 
; Copyright (c) 2017 by Alessandro Fraschetti (gos95@gommagomma.net).
;
; This file is part of the xp-pic-asm project:
;     https://github.com/gos95-electronics/xp-pic-asm
; This code comes with ABSOLUTELY NO WARRANTY.
;
; Author.....: Alessandro Fraschetti
; Company....: gos95
; Target.....: Microchip PIC 16F648A Microcontroller
; Compiler...: Microchip Assembler (MPASM)
; Version....: 1.1 2018/03/11 - source refactory
;              1.0 2017/03/21
; Description: 
;    Simple scheduler manager for executing tasks at regular intervals
;=============================================================================

    PROCESSOR   16f648a
    __CONFIG    _CP_OFF & _DATA_CP_OFF & _LVP_OFF & _BOREN_OFF & _MCLRE_ON & _WDT_OFF & _PWRTE_ON & _HS_OSC
    INCLUDE     <p16f648a.inc>


;=============================================================================
;  Label equates
;=============================================================================

;----- SCREG overflow bitflags -----------------------------------------------
SC1OF           equ     0x00        ; SCREG<0>
SC2OF           equ     0x01        ; SCREG<1>
SC3OF           equ     0x02        ; SCREG<2>
SC4OF           equ     0x03        ; SCREG<3>
SC5OF           equ     0x04        ; SCREG<4>
SC6OF           equ     0x05        ; SCREG<5>
SC7OF           equ     0x06        ; SCREG<6>
SC8OF           equ     0x07        ; SCREG<7>


;----- counters init cycles --------------------------------------------------
; on 20MHz FOSC : 2ms, 10ms, 50ms, 100ms, 250ms, 500ms, 1s, 2s
SC1CYCLES       equ     d'5'        ; 5 x timer0 cycles =   10000
SC2CYCLES       equ     d'5'        ; 5 x SC1 cycles    =   50000
SC3CYCLES       equ     d'5'        ; 5 x SC2 cycles    =  250000
SC4CYCLES       equ     d'2'        ; 2 x SC3 cycles    =  500000
SC5CYCLES       equ     d'5'        ; 5 x SC3 cycles    = 1250000
SC6CYCLES       equ     d'2'        ; 2 x SC5 cycles    = 2500000
SC7CYCLES       equ     d'2'        ; 2 x SC6 cycles    = 5000000
SC8CYCLES       equ     d'2'        ; 2 x SC7 cycles    =10000000


;=============================================================================
;  File register use
;=============================================================================
	cblock		h'20'
		w_temp						; variable used for context saving
		status_temp					; variable used for context saving
        pclath_temp                 ; variable used for context saving

        SCREG                       ; scheduler bitflags register

        sc1Counter                  ; 2ms counter
        sc2Counter                  ; 10ms counter
        sc3Counter                  ; 50ms counter
        sc4Counter                  ; 100ms counter
        sc5Counter                  ; 250ms counter
        sc6Counter                  ; 500ms counter
        sc7Counter                  ; 1s counter
        sc8Counter                  ; 2s counter
	endc


;=============================================================================
;  Start of code
;=============================================================================
;start
	org			h'0000'				; processor reset vector
	goto		main				; jump to the main routine

	org			h'0004'				; interrupt vector location
	movwf		w_temp				; save off current W register contents
	movf		STATUS, W			; move status register into W register
	movwf		status_temp			; save off contents of STATUS register
    movf        PCLATH, W           ; move pclath register into W register
    movwf       pclath_temp         ; save off contents of PCLATH register

    ; isr code can go here or be located as a call subroutine elsewhere

    movf        pclath_temp, W      ; retrieve copy of PCLATH register
    movwf       PCLATH              ; restore pre-isr PCLATH register contents
    movf		status_temp, W		; retrieve copy of STATUS register
	movwf		STATUS				; restore pre-isr STATUS register contents
	swapf		w_temp, F
	swapf		w_temp, W			; restore pre-isr W register contents
	retfie							; return from interrupt


;=============================================================================
;  Init Timer0 (internal clock source)
;=============================================================================
init_timer0
    errorlevel	-302

    ; Clear the Timer0 registers
    clrf		STATUS                      ; select Bank0
    clrf        TMR0                        ; clear module register

    ; Disable interrupts
    bcf         INTCON, T0IE                ; mask timer interrupt

    ; Set the Timer0 control register
    bsf			STATUS, RP0                 ; select Bank1
    movlw       b'10000010'                 ; setup prescaler and timer (1:8)
    movwf       OPTION_REG
    bcf			STATUS, RP0                 ; select Bank0

    errorlevel  +302

    return


;=============================================================================
;  Init scheduler
;=============================================================================
init_scheduler
        movlw       SC1CYCLES
        movwf       sc1Counter
        movlw       SC2CYCLES
        movwf       sc2Counter
        movlw       SC3CYCLES
        movwf       sc3Counter
        movlw       SC4CYCLES
        movwf       sc4Counter
        movlw       SC5CYCLES
        movwf       sc5Counter
        movlw       SC6CYCLES
        movwf       sc6Counter
        movlw       SC7CYCLES
        movwf       sc7Counter
        movlw       SC8CYCLES
        movwf       sc8Counter

        return


;=============================================================================
;  Task Routines
;=============================================================================


;=============================================================================
;  Main Program
;=============================================================================
main
        call        init_timer0
        call        init_scheduler


;==== tasks scheduler ========================================================
schedulerloop
        btfss       INTCON, T0IF                ; timer overflow?
        goto        schedulerloop               ; no  : loop!

        bcf         INTCON, T0IF                ; yes : reset overflow flag
        movlw       7                           ; and reset TMR0 to overflow every
        movwf       TMR0                        ; 250*8 cycles (400uS on 20MHz FOSC)
                                                ; (256 - 250 + 3)


; --  manage sc1-period tasks ------------------------------------------------
begin_sc1tasks
        btfss       SCREG, SC1OF                ; SC1 timer overflow?
        goto        end_sc1tasks                ; not time yet
        nop                                     ; yes, execute tasks
end_sc1tasks
; ----------------------------------------------------------------------------


; --  manage sc2-period tasks ------------------------------------------------
begin_sc2tasks
        btfss       SCREG, SC2OF                ; SC2 timer overflow?
        goto        end_sc2tasks                ; not time yet
        nop                                     ; yes, execute tasks
end_sc2tasks
; ----------------------------------------------------------------------------


; --  manage sc3-period tasks ------------------------------------------------
begin_sc3tasks
        btfss       SCREG, SC3OF                ; SC3 timer overflow?
        goto        end_sc3tasks                ; not time yet
        nop                                     ; yes, execute tasks
end_sc3tasks
; ----------------------------------------------------------------------------


; --  manage sc4-period tasks ------------------------------------------------
begin_sc4tasks
        btfss       SCREG, SC4OF                ; SC4 timer overflow?
        goto        end_sc4tasks                ; not time yet
        nop                                     ; yes, execute tasks
end_sc4tasks
; ----------------------------------------------------------------------------


; --  manage sc5-period tasks ------------------------------------------------
begin_sc5tasks
        btfss       SCREG, SC5OF                ; SC5 timer overflow?
        goto        end_sc5tasks                ; not time yet
        nop                                     ; yes, execute tasks
end_sc5tasks
; ----------------------------------------------------------------------------


; --  manage sc6-period tasks ------------------------------------------------
begin_sc6tasks
        btfss       SCREG, SC6OF                ; SC6 timer overflow?
        goto        end_sc6tasks                ; not time yet
        nop                                     ; yes, execute tasks
end_sc6tasks
; ----------------------------------------------------------------------------


; --  manage sc7-period tasks ------------------------------------------------
begin_sc7tasks
        btfss       SCREG, SC7OF                ; SC7 timer overflow?
        goto        end_sc7tasks                ; not time yet
        nop                                     ; yes, execute tasks
end_sc7tasks
; ----------------------------------------------------------------------------


; --  manage sc8-period tasks ------------------------------------------------
begin_sc8tasks
        btfss       SCREG, SC8OF                ; SC8 timer overflow?
        goto        end_sc8tasks                ; not time yet
        nop                                     ; yes, execute tasks
end_sc8tasks
; ----------------------------------------------------------------------------


; --  scheduler counters business --------------------------------------------
begin_scheduler_business
        clrf        SCREG                       ; reset scheduler register
sc1test
        decfsz      sc1Counter, F               ; countdown and test sc1 counter
        goto        end_scheduler_business      ; not time yet
        movlw       SC1CYCLES                   ; yes, reset counter
        movwf       sc1Counter
        bsf         SCREG, SC1OF                ; and set bitflag
        nop
sc2test
        decfsz      sc2Counter, F               ; countdown and test sc2 counter
        goto        end_scheduler_business      ; not time yet
        movlw       SC2CYCLES                   ; yes, reset counter
        movwf       sc2Counter
        bsf         SCREG, SC2OF                ; and set bitflag
        nop
sc3test
        decfsz      sc3Counter, F               ; countdown and test sc3 counter
        goto        end_scheduler_business      ; not time yet
        movlw       SC3CYCLES                   ; yes, reset counter
        movwf       sc3Counter
        bsf         SCREG, SC3OF                ; and set bitflag
        nop
sc4test
        decfsz      sc4Counter, F               ; countdown and test sc4 counter
        goto        sc5test                     ; not time yet
        movlw       SC4CYCLES                   ; yes, reset counter
        movwf       sc4Counter
        bsf         SCREG, SC4OF                ; and set bitflag
        nop
sc5test
        decfsz      sc5Counter, F               ; countdown and test sc5 counter
        goto        end_scheduler_business      ; not time yet
        movlw       SC5CYCLES                   ; yes, reset counter
        movwf       sc5Counter
        bsf         SCREG, SC5OF                ; and set bitflag
        nop
sc6test
        decfsz      sc6Counter, F               ; countdown and test sc6 counter
        goto        end_scheduler_business      ; not time yet
        movlw       SC6CYCLES                   ; yes, reset counter
        movwf       sc6Counter
        bsf         SCREG, SC6OF                ; and set bitflag
        nop
sc7test
        decfsz      sc7Counter, F               ; countdown and test sc7 counter
        goto        end_scheduler_business      ; not time yet
        movlw       SC7CYCLES                   ; yes, reset counter
        movwf       sc7Counter
        bsf         SCREG, SC7OF                ; and set bitflag
        nop
sc8test
        decfsz      sc8Counter, F               ; countdown and test sc8 counter
        goto        end_scheduler_business      ; not time yet
        movlw       SC8CYCLES                   ; yes, reset counter
        movwf       sc8Counter
        bsf         SCREG, SC8OF                ; and set bitflag
        nop
end_scheduler_business
; ----------------------------------------------------------------------------

endloop
        goto        schedulerloop

;==== tasks scheduler ========================================================
        end