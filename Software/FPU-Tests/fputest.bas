1 PRINT "VECTORING ..."
5 A=$00000000
10 FOR I=0 TO 255
20 IF LEEK(A)=$49FA0135 GOTO 60
30 A=A+$00000004
40 NEXT I
50 GOTO 99
60 LOKE A,$00200E44
70 GOTO 30
99 PRINT "LOADING ..."
100 LOKE $0400,$70037202
105 LOKE $0404,$21C02000
110 LOKE $0408,$21C12004
120 LOKE $040C,$F2004000
130 LOKE $0410,$F2014080
140 LOKE $0414,$F2000422
150 LOKE $0418,$F2006000
160 LOKE $041C,$21C02008
170 LOKE $0420,$4E754E75
175 PRINT "RUNNING ..."
180 CALL $0400
190 PRINT HEX$(LEEK($2000))
200 PRINT HEX$(LEEK($2004))
210 PRINT HEX$(LEEK($2008))

1 PRINT "VECTORING ..."
5 A=$00000000
10 FOR I=0 TO 255
20 IF LEEK(A)=$49FA0135 GOTO 60
30 A=A+$00000004
40 NEXT I
50 GOTO 99
60 LOKE A,$00200E44
70 GOTO 30
99 PRINT "LOADING ..."
100 LOKE $0400,$F23C4400
101 LOKE $0404,$40100000
102 LOKE $0408,$F23C4480
103 LOKE $040C,$40700000
104 LOKE $0410,$F2386400
105 LOKE $0414,$2000F238
106 LOKE $0418,$64802004
107 LOKE $041C,$F2000422
108 LOKE $0420,$F2386400
109 LOKE $0424,$20084E75
175 PRINT "RUNNING ..."
180 CALL $0400
190 PRINT HEX$(LEEK($2000))
200 PRINT HEX$(LEEK($2004))
210 PRINT HEX$(LEEK($2008))
215 PRINT "DONE."
