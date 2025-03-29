*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
trapGetChar	EQU	0
trapPutChar	EQU	1
trapNewLine	EQU	2
trapGetParam EQU	3
trapPutString EQU	4

callSYS	MACRO
	MOVE.B	#\1,D1	; load syscall num
	TRAP	#0	; call syscall
	ENDM
	

    ORG    $000
START:                  ; first instruction of program
	LEA	(strHead,PC),A4
	callSYS	trapPutString
	callSYS trapNewLine
	LEA	(strReset,PC),A4
	callSYS	trapPutString
	RTS
	
	
strHead	DC.B	'Second Stage Bootloader ...',0
strReset	DC.B	'Resetting ...',0

* Put program code here

    SIMHALT             ; halt simulator

* Put variables and constants here

    END    START        ; last line of source

*~Font name~Courier New~
*~Font size~10~
*~Tab type~0~
*~Tab size~4~
