LIST P=PIC18F4321	F=INHX32
    #include <p18f4321.inc>
    
    CONFIG  OSC=HSPLL ; L?oscil.lador
    CONFIG  PBADEN=DIG ; Volem que el PORTB sigui DIGital
    CONFIG  WDT=OFF ; Desactivem el WatchDog Timer
    
    ORG 0x0000
    GOTO    MAIN
    ORG 0x0008
    GOTO    HIGH_RSI
    ORG 0x0018
    RETFIE  FAST
    
    TAULA7S EQU 0x0020
    TAULASERVO EQU 0x0040
    TAULASPEAKER EQU 0x0060
    TAULADURACTUAL EQU 0x0080
 
    NNOTES EQU 0x10

    MOTOR_UP EQU 0x11
    MOTOR_CYCLE EQU 0x12
    ECHO_CYCLE EQU 0x13
 
    ESTAT_SENSOR EQU 0x14
 
    MA_POSADA EQU 0x15
 
    TRIGGER_CYCLE EQU 0x16
    ECHO_EMITINTSE EQU 0x17

    esperaTR EQU 0x18
    distAUX EQU 0x19
 
    NNOTES_POSADES EQU 0x1A
 
    TimeCounterL EQU 0x1B
    TimeCounterH EQU 0x1C
 
    distancia EQU 0x1D
    DIST_CYCLE EQU 0x1E
 
    correcte EQU 0x1F
    notaPosada EQU 0x20
 
    notaActual EQU 0x21
    durActual EQU 0x22
 
    durActualL EQU 0x23
    durActualH EQU 0x24
 
    SPEAKER_CYCLE EQU 0x25
    SPEAKER_FREQ EQU 0x26
 
    gameEnd EQU 0x27
 
    GUARDAR_DURACIO EQU 0x28
 
    inGame EQU 0x29

ORG TAULA7S
    ;Segments del 0, segments del 1
    DB 0x02, 0x4F
    ;Segments del 2, segments del 3
    DB 0x11, 0x05
    ;Segments del 4, segments del 5
    DB 0x4C, 0x24
    ;Segments del 6, segments del 7
    DB 0x20, 0xFF
    
ORG TAULASERVO
    ;1 i 2 notes
    DB .18, .9 ; 1664
    ;3 i 4 notes
    DB .6, .4  ; 832
    ;5 i 6 notes
    DB .3, .3  ; 554.6
    ;7 i 8 notes
    DB .2, .2 ; 416
    ;9 i 10 notes
    DB .2, .2 ; 332.8
    ;11 i 12 notes
    DB .1, .1  ; 277.3
    ;13 i 14 notes
    DB .1, .1  ; 237.7
    ;15 i 16 notes
    DB .1, .1  ; 208
    
ORG TAULASPEAKER
    DB .10, .12
    DB .14, .16
    DB .18, .20
    DB .22, .24
    
ORG TAULADURACTUAL
    DB 0x21, 0x63 
    DB 0x42, 0xC6
    DB 0x64, 0x29
    
HIGH_RSI   ;Fa una interrupcio cada [117 microsegons]

	;PEL SERVO:
	    ;117 * 22 = 2574 = 2.5 ms aprox
	    ;117 * 171 = 20007 = 20 ms aprox
	    ;117 * 4 = 468 = 0.5 ms aprox
	   
	;PEL SPEAKER
	    ;de 854.7 Hz (1s / (10 * 117us))
	    ;a 356 Hz   (1s / (24 * 117us))
	   
	;PEL SENSOR D'ULTRASONS
	    ;117 * 3 = 351 = 7.1 CM aprox
	    ;117 * 4275 = 499941 = 0.5 s aprox
	    ;117 * 8547 = 999999 = 1 s aprox
	    ;117 * 17094 = 1999998 = 2 s aprox
	    ;117 * 25641 = 2999997 = 3 s aprox
    
	   ;
	   ;CODI DEL TIMER0
	   ;

    MOVLW  0xFB
    MOVWF  TMR0H, 0
    
    MOVLW  0x6E
    MOVWF  TMR0L, 0
    
    BCF	INTCON,TMR0IF,0  ;Netejem el bit de causa d'interrupció
			 ;i començara a anar el timer
		
	    ;
	    ;CODI DEL SERVOMOTOR
	    ;
    INCF MOTOR_CYCLE, 1 ;cycle++;
    MOVLW .171
    SUBWF MOTOR_CYCLE, W
    BTFSC STATUS, Z, 0 ; mirem si han passat 20 ms
    CALL SERVO_CYCLE_ACABAT
    
    MOVF MOTOR_UP, 0
    SUBWF MOTOR_CYCLE, W
    BTFSC STATUS, Z, 0 ; mirem si ja toca baixar el pin del servo
    BCF	    LATC, 2, 0 ; baixar el pin del servo
    ;BTFSC SERVO_ACTIVAT, 0, 1
    ;CALL GIRAR_SERVO
    
    BTFSS inGame, 0, 0  ;Quan encara no ha començat el joc, nomes es fa
    RETFIE FAST		;el srvomotor
    
    
    ;UN COP COMENÇA EL JOC 
     
    	    ;
	    ;CODI DEL SPEAKER
	    ;

    BTFSC MA_POSADA, 0, 0 ;Si esta posant la ma, fem funcionar el speaker.
    CALL SPEAKER
    BTFSS MA_POSADA, 0, 0 ;Si no hi ha nota, s'eapeaker no fa res.
    BCF  LATC, 3,0 
    
            ;
	    ;CODI DEL ULTRASONS
	    ;
	    
	;
	;ESTATS D'INTRODUIR LA NOTA
	;
	
    CALL MAQUINA_ESTATS

	;
	; MESURAR DISTANCIA
	;
	
    INCF DIST_CYCLE, 1 
    MOVLW .3
    SUBWF DIST_CYCLE, W  ; cada 3 cicles, 7 CM
    BTFSC STATUS, Z, 0 ; mirem si ha passat el temps de 7 CM
    INCF distAUX, 1  ;distAUX++
    
    MOVLW .3   ; if (DIST_CYCLE == 3) DIST_CYCLE = 0;
    SUBWF DIST_CYCLE, W  
    BTFSC STATUS, Z, 0
    CLRF  DIST_CYCLE, 1 
    
    
	;
	; MIRAR EL ECHO
	;
	
    BTFSC ECHO_EMITINTSE, 1  ;Si el echo esta emitint-se, es mira si s'ha parat
    CALL MIRAR_ECHO          ;Si s'ha parat, echo_emitintse = 0;
    
    
    MOVLW .0		    ;if (!echocycle) echocycle++;
    SUBWF ECHO_CYCLE, W	    ;quan echo cicle, no es 0, es va sumant
    BTFSS STATUS, Z, 0	    ;comença quan el echo acaba
    INCF ECHO_CYCLE, 1;
    
    MOVLW .87		    ;Quan han pasat 10.1ms (87 * 117us)
    SUBWF ECHO_CYCLE, W	    ;ja es pot tornar a enviar el trigger
    BTFSC STATUS, Z, 0	   
    CALL PREPARAT_PER_TRIGGER     ;trigger_cycle = 0, echo_cycle = 0;
   
	;
	; TRIGGER del Ultrasons
	;
    MOVLW .0
    SUBWF TRIGGER_CYCLE, W
    BTFSC STATUS, Z, 0  
    CALL FER_TRIGGER      ;Senvia el trigger, 10 us = 100 Tinst
			;quan trigger_cycle és 0.
			
    MOVLW .2           ;Es mira el echo 234 micros després del trigger
    SUBWF TRIGGER_CYCLE, W
    BTFSC STATUS, Z, 0
    CALL ECHO_START    ;Quan comença, el ECHO_EMITINTSE = 1;
    
    
    INCF TRIGGER_CYCLE, 1  ; if (trigger_cycle != 3) trigger_cycle++
    MOVLW .4           ;Un cop s'ha arribat al echo, trigger cycle es queda a 3
    SUBWF TRIGGER_CYCLE, W
    BTFSC STATUS, Z, 0
    DECF TRIGGER_CYCLE, 1 
    
    CALL INC_TIMECOUNTER  ;TimeCounter++
   
    RETFIE FAST
    
    
    
    ;
    ; FUNCIONS DEL SERVO
    ;
    
SERVO_CYCLE_ACABAT
    CLRF MOTOR_CYCLE, 1
    BSF	    LATC, 2, 0 ; pujar el pin del servo
    RETURN
    
INCR_SERVO    

    MOVF  NNOTES, W     ; n notes 
    DECF WREG, 0	; (n notes - 1)
    ADDLW TAULASERVO    ; (n notes - 1) + posicio de la taula
    MOVFF WREG, TBLPTRL 
    TBLRD*             
    MOVF  TABLAT, W
    ADDWF MOTOR_UP ,1 ,0  ;a servo_mantenir esta el temps que s'ha de mantindre
    
    RETURN
    
    
    
    ;
    ; FUNCIONS DEL SPEAKER
    ;
    
SPEAKER
	
    MOVF  distancia, W  ;Posar la dunracio de la nota en segons
    ADDLW TAULASPEAKER
    MOVFF WREG, TBLPTRL
    TBLRD* ;READ
    MOVFF TABLAT, SPEAKER_FREQ
    
    INCF SPEAKER_CYCLE, 1 ;speaker_cycle++
    
    MOVF SPEAKER_FREQ, W  ;if (speaker_cycle == speaker_freq) toggle speaker
    SUBWF SPEAKER_CYCLE, W
    BTFSC STATUS, Z, 0
    BTG  LATC, 3,0      
    
    MOVF SPEAKER_FREQ, W ;if (speaker_cycle == speaker_freq) speaker_cycle = 0;
    SUBWF SPEAKER_CYCLE, W
    BTFSC STATUS, Z, 0
    CLRF SPEAKER_CYCLE, 1 
    
    RETURN
    
    
    
    ;
    ; FUNCIONS DEL SENSOR DE ULTRASONS
    ;
    
    ; FER TRIGGER
    
ACTIVAR_TR   
    NOP 
    NOP
    NOP
    MOVLW .238           ;1
    MOVWF esperaTR, 1      ;1
BUCLE_TR
    INCF esperaTR, 1     ;1
    BTFSS  STATUS, C, 0  ;1 o 3  --> 2 + 1 + 1 + 1 + 1 + n(4) + 2 = 8 + 4n
    GOTO BUCLE_TR        ;2            8 + 4n = 100, 4n = 92 , n = 23
					;256 - 23 = 233 
    RETURN               ;2		
    
FER_TRIGGER

    BSF LATC, 4, 0
    CALL ACTIVAR_TR   ;10us = 100 instruccions
    BCF LATC, 4, 0
    RETURN
    
PREPARAT_PER_TRIGGER
    CLRF ECHO_CYCLE, 1
    CLRF TRIGGER_CYCLE, 1
    RETURN
    
    ; ESPERAR EL COMENÇAMENT DEL ECHO
    
ECHO_START

    BTFSS PORTC, 5, 0 ;Esperar al HIGH del ECHO
    GOTO ECHO_START
    SETF ECHO_EMITINTSE, 1
    CLRF DIST_CYCLE, 1 ;Es inicialitzen els valors de distancia
    CLRF distAUX, 1
    RETURN            ;Cuan arriba el HIGH es comença a mesurar la distancia
    
    ; ESPERAR EL FINAL DEL ECHO
    
MIRAR_ECHO
    BTFSC PORTC, 5, 0 ;Mirar si encara esta el ECHO a 1
    RETURN
		       ;Quan el ECHO s'acaba
    MOVFF distAUX, distancia
    CALL MIRAR_DISTANCIA
    INCF ECHO_CYCLE, 1 ;echo_cycle = 1;
    CLRF ECHO_EMITINTSE, 1
    RETURN
    
MIRAR_DISTANCIA
    ;si distancia es mes gran que 7 (0x07) (+60cm) no s'esta posant nota

    ;si el 4t bit de distancia es 0, s'esta posant nota
    BTFSS  distancia, 3, 1
    SETF MA_POSADA, 1	    ;En cas de posar nota
    BTFSC  distancia, 3, 1
    CLRF MA_POSADA, 1	    ;En cas de no posar nota

    RETURN
    
    
    
    ;
    ; MAQUINA D'ESTATS PER POSAR NOTA
    ;
    
    
MAQUINA_ESTATS
    ;A l'hora d'introduir una nota, hi ha varios estats
    CLRF correcte, 1
    ;Estat 0: l'usuari encara no ha posat la ma al sensor. 
    ;Quan es posi, s'anirà a l'estat 1
    MOVLW .0
    SUBWF ESTAT_SENSOR, W  
    BTFSC STATUS, Z, 0    ;Es mira si està a l'estat 0
    CALL ESTAT_0
    
    ;Estat 1: l'usuari posa la ma al sensor, si la treu, no passa res i torna
    ;a l'estat 0
    ;Si està 3 segons seguits posant la ma, sense arribar a la nota correcta
    ;s'encendrà AnswerIncorrect, si troba la nota correcta, inmediatament anirà a
    ;l'estat 2.
    MOVLW .1
    SUBWF ESTAT_SENSOR, W  
    BTFSC STATUS, Z, 0    ;Es mira si està a l'estat 1
    CALL ESTAT_1
    
    ;Estat 2: l'usuari ha arribat la nota correcta. 
    ;Si l'usuari la manté durant 0.5 segons, s'envà a l'estat 3. Si treu la mà
    ;o canvia de nota, a l'estat 1
    MOVLW .2
    SUBWF ESTAT_SENSOR, W  
    BTFSC STATUS, Z, 0    ;Es mira si està a l'estat 2
    CALL ESTAT_2
    
    ;Estat 3: l'usuari esta introduint la nota
    ;S'apaguen els LEDs
    ;L'usuari ha de mantindre la nota fins que el LED verd s'encengui
    ; Si no ho fa, LED vermell i a l'estat 0
    ; Si ho fa, LED verd i a l'estat 0
    MOVLW .3
    SUBWF ESTAT_SENSOR, W  
    BTFSC STATUS, Z, 0    ;Es mira si està a l'estat 3
    CALL ESTAT_3
    
    RETURN
    
ESTAT_0
    BTFSS MA_POSADA, 0, 1 ;Si hi ha la ma posada, es va a l'estat 1
    RETURN

    INCF ESTAT_SENSOR, 1 ;estat = 1
    CLRF TimeCounterL, 1  ;TimeCounter = 0
    CLRF TimeCounterH, 1

    RETURN
    
ESTAT_1
    BTFSS MA_POSADA, 0, 1 ;Si NO hi ha la ma posada, es va a l'estat 0
    DECF ESTAT_SENSOR, 1
    
    ; 25641 = 0x6429  <-- 3 segons

    MOVLW 0x64
    SUBWF TimeCounterH, W
    BTFSC STATUS, Z, 0
    INCF correcte, 1
    
    MOVLW 0x29
    SUBWF TimeCounterL, W
    BTFSC STATUS, Z, 0
    INCF correcte, 1
    
    MOVLW .2
    SUBWF correcte, W
    BTFSC STATUS, Z, 0
    GOTO NOTA_FALLADA    ;Si portes 3 segons en aquest estat tornes al
			;Estat 0

    MOVF notaActual, W       ;Si es troba la nota correcta vas a l'estat 2
    SUBWF distancia, W
    BTFSS STATUS, Z, 0
    RETURN

    INCF ESTAT_SENSOR, 1  ;estat = 2
    CLRF TimeCounterL, 1  ;TimeCounter = 0
    CLRF TimeCounterH, 1
    
    RETURN
    
TORNAR_ESTAT_1
    
    DECF ESTAT_SENSOR, 1 ;estat = 1
    CLRF TimeCounterL, 1  ;TimeCounter = 0
    CLRF TimeCounterH, 1
    
    RETURN
    
ESTAT_2
    BTFSS MA_POSADA, 0, 1 ;Si NO hi ha la ma posada, es va a l'estat 0
    CLRF ESTAT_SENSOR, 1
    BTFSS MA_POSADA, 0, 1
    RETURN

    MOVF notaActual, W       ;Si NO ES MANTE la nota correcta, es torna a 
    SUBWF distancia, W	    ; l'estat 1
    BTFSS STATUS, Z, 0
    GOTO TORNAR_ESTAT_1

    ; 4273 = 0x10B1  <-- 0.5 segons
    
    MOVLW 0x10
    SUBWF TimeCounterH, W
    BTFSC STATUS, Z, 0
    INCF correcte, 1
    
    MOVLW 0xB1
    SUBWF TimeCounterL, W
    BTFSC STATUS, Z, 0
    INCF correcte, 1
   
    MOVLW .2
    SUBWF correcte, W
    BTFSS STATUS, Z, 0
    RETURN    ;Si portes 0.5 segons en aquest estat vas al
        	;Estat 3
    INCF ESTAT_SENSOR, 1  
    CLRF TimeCounterL, 1  ;TimeCounter = 0
    CLRF TimeCounterH, 1
    CLRF correcte, 1

    DECF  durActual, W  ;Posar la duracio de la nota en segons
    RLNCF WREG, W
    ADDLW TAULADURACTUAL
    MOVFF WREG, TBLPTRL
    TBLRD*+ ;READ++
    MOVFF TABLAT, durActualH
    TBLRD* ;READ
    MOVFF TABLAT, durActualL
    
    RETURN
    
ESTAT_3
    
    BCF     LATC,6,0      ;Apagar LEDs
    BCF     LATC,7,0      
    
    MOVF notaActual, W       ;Si NO ES MANTE la nota correcta, es torna a 
    SUBWF distancia, W	    ; l'estat 0. Nota fallada
    BTFSS STATUS, Z, 0
    GOTO NOTA_FALLADA

    
    MOVF durActualH, W
    SUBWF TimeCounterH, W
    BTFSC STATUS, Z, 0
    INCF correcte, 1
    
    MOVF durActualL, W
    SUBWF TimeCounterL, W
    BTFSC STATUS, Z, 0
    INCF correcte, 1

    MOVLW .2
    SUBWF correcte, W
    BTFSC STATUS, Z, 0
    GOTO NOTA_CORRECTA   ;Si portes els segons que calen vas a l'estat 0
		    ;Nota correcta

    RETURN
    
NOTA_FALLADA
	
    BSF     LATC,7,0      ;AnswerIncorrect
    CLRF ESTAT_SENSOR, 1  ;Torna a l'estat 0
    INCF NNOTES_POSADES, 1  ;notes_posades++
    
    MOVF NNOTES, W       ;Si ja s'han posat totes les notes, s'acaba el joc
    SUBWF NNOTES_POSADES, W
    BTFSC STATUS, Z, 0
    GOTO FINISH_GAME
    
    CALL READNOTA              ;Es passa a la seguent nota
    
    RETURN
    
NOTA_CORRECTA
    
    CALL INCR_SERVO
    
    BSF     LATC,6,0      ;AnswerCorrect
    CLRF ESTAT_SENSOR, 1  ;Torna a l'estat 0
    ;CALL INCREMENTAR_ESPERA ;moure el servomotor
    INCF NNOTES_POSADES, 1  ;notes_posades++

    MOVF NNOTES, W       ;Si ja s'han posat totes les notes, s'acaba el joc
    SUBWF NNOTES_POSADES, W
    BTFSC STATUS, Z, 0
    GOTO FINISH_GAME
    
    CALL READNOTA              ;Es passa a la seguent nota
    
    RETURN
    
FINISH_GAME

    SETF gameEnd, 0
    RETURN
    
INC_TIMECOUNTER ;Incrementa el comtador de temps + 1
    
    INCF TimeCounterL, 1
    BTFSC STATUS, Z, 0
    INCF TimeCounterH, 1
    
    RETURN
   
    
    
 ;
 ; INITS AL FER PCI
 ;
    
    
    
    
INIT_PORTS
    
    MOVLW 0x00
    MOVWF  TRISD, 0	; Aixo es el 7Seg
    SETF LATD, 0
    ;Seran els 7 Seg de les notes, aprofitant el 7SEG display soldat
    
    SETF    ADCON1,0    ; Configurem el PORTA digital
    BCF	    ADCON1, VCFG1, 0
    BCF	    ADCON1, VCFG0, 0
    
    BSF     TRISA,0,0  ; Configurem el port RA0 d'entrada
    BSF	    TRISA,1,0  ; Configurem el port RA1 d'entrada
    BSF     TRISA,2,0  ; Configurem el port RA3 d'entrada
    ;Aquests 3 bits son la nota
    
    BCF	    TRISA,3,0  ; Configurem el port RA3 de sortida
    BCF     TRISA,4,0  ; Configurem el port RA4 de sortida
    BCF	    LATA,3,0   
    BCF	    LATA,4,0   ; Els posem a 0
    ;Aquests 2 bits son la duració que mostrarem, aprofintant els LEDs
    
    BSF	    TRISC,0,0  ; Configurem el port RC0 d'entrada
    BSF     TRISC,1,0  ; Configurem el port RC1 d'entrada
    ;Aquests 2 bits son la duració
    BCF     TRISC,2,0  ; Configurem el port RC2 de sortida
    ;Controla el servomotor
    BCF	    LATC, 2, 0
    
    BCF     TRISC,3,0  ; Configurem el port RC3 de sortida
    BCF     LATC, 3,0
    ;Pel speaker
    
    BCF     TRISC,4,0  ; Configurem el port RC4 de sortida
    ;Sera el TR
    BCF     LATC,4,0
    BSF     TRISC,5,0  ; Configurem el port RC5 d'entrada
    ;Sera el 
    
    
    ;Aquestes son les entrades i sortides del sensor d'ultrasons
    
    BCF     TRISC,6,0  ; Configurem el port RC6 de sortida
    ;Sera el LED verd (nota correcta)
    BCF     TRISC,7,0  ; Configurem el port RC7 de sortida
    ;Sera el LED vermell (nota incorrecta)
    BCF     LATC,6,0
    BCF     LATC,7,0
    
    BSF     TRISB,0,0  ; Configurem el port RB0 d'entrada
    ;El port de newNote
    BSF     TRISB,1,0  ; Configurem el port RB1 d'entrada
    ;El port de startGame
    
    BCF	    TRISB,2,0  ; Configurem el port RB2 de sortida, sera el ACK
    BCF	    LATB,2,0   ; Configurem el ACK a 0
    ;El port de ACK
    
    BSF	    TRISB,3,0  ; Configurem el port RB3 d'entrada, es el PCI
    
    BSF     TRISA,6,0  ; Configurem el port RA6 d'entrada
    
    RETURN
    
INIT_REGS   ;Es netejen tots els registres 
    
    CLRF MA_POSADA, 0
    CLRF NNOTES, 0 ; començem amb 0 notes
    CLRF NNOTES_POSADES, 0  ;posem 0 a notes posades
    CLRF gameEnd, 0
    CLRF TRIGGER_CYCLE, 0
    CLRF ECHO_EMITINTSE, 0
    CLRF ECHO_CYCLE, 0
    CLRF ESTAT_SENSOR, 0
    CLRF TimeCounterL, 0
    CLRF TimeCounterH, 0
    SETF distancia, 0	;La distancia ha de començar sent 0xFF perque si fos
    CLRF SPEAKER_CYCLE, 0  ;0 donaria problemes
    CLRF inGame, 0
    CLRF MOTOR_UP, 0
    CLRF MOTOR_CYCLE, 0
    CLRF esperaTR, 0
    CLRF distAUX, 0
    CLRF DIST_CYCLE, 0
    CLRF correcte, 0
    CLRF notaPosada, 0
    CLRF notaActual, 0
    CLRF durActual, 0
    CLRF durActualL, 0
    CLRF durActualH, 0
    CLRF SPEAKER_FREQ, 0
    CLRF GUARDAR_DURACIO, 0 
    
    RETURN
    
INIT_POINTERS   
    ;Fer que els punters del TBLPTR apuntin a la adreça de la taula del 7S. 
    MOVLW 0x00 ; Load TBLPTR with the base
    MOVWF TBLPTRU ; address of the word
    MOVWF TBLPTRH
    MOVWF  TBLPTR, 1   ;posem 0 al punter
    MOVLW TAULA7S
    MOVWF TBLPTRL 
     
    MOVLW 0x00  ;Aquests punters son per escriure i llegir dintre la RAM 
    MOVWF FSR0H, 0 ;les notes
    MOVWF FSR0L, 0
    
    MOVLW 0x00
    MOVWF FSR1H, 0
    MOVWF FSR1L, 0
    
    RETURN
    

INIT_SERVO
    
    CLRF MOTOR_CYCLE, 1 ;20 ms = 171
    MOVLW .4
    MOVWF MOTOR_UP, 1   ;1 ms aprox
    
    RETURN
    
INIT_TIMER
    BCF	RCON,IPEN,0	 ; Desactivem les prioritats
    MOVLW   b'10001000'	 ; Configurem el TIMER0
    MOVWF   T0CON,0      ; Timer0 Controller, no TOCÓN!!!
    
    MOVLW   b'11100000'
    MOVWF   INTCON,0	 ; Habilitem totes les interrupcions i la del TMR0
    
    RETURN
    
    
    ;
    ; ABANS DE COMENÇAR EL JOC
    ;
    
MAIN
    
    CALL INIT_PORTS
    CALL INIT_REGS
    CALL INIT_POINTERS
    CALL INIT_SERVO
    CALL INIT_TIMER  
LOOP
    
    BTFSS   PORTB,3,0  ; Si en algun moment s'activa el PCI, es reinicia tot
    GOTO MAIN          ; (logica negativa, PCI = 0)
    
    BTFSS   PORTB,0,0  ; Es mira si el newNote està activat
    CALL NEWNOTE       ; Si el newNote no està activat, hi ha una nova nota
    
    BTFSC   PORTB,1,0  ; Es mira si el startGame està desactivat
    GOTO STARTGAME     ; Si el startgame esta activat, comença el joc
    
    GOTO LOOP
    
    
    
NEWNOTE    ;funcio del newNote
   
    ;Primer es guarda la duracio
    MOVFF PORTC, GUARDAR_DURACIO
    
    ;MOVLW 0x03 aixo va
    ;MOVWF GUARDAR_DURACIO, 0
    
    MOVLW b'00000011'
    ANDWF GUARDAR_DURACIO, 1
    
    ;POSAR LA DURACIO ALs 4 bits de mes pes
    RLCF GUARDAR_DURACIO, 1
    RLCF GUARDAR_DURACIO, 1
    RLCF GUARDAR_DURACIO, 1
    RLCF GUARDAR_DURACIO, 1
    
    MOVLW b'11110000'
    ANDWF GUARDAR_DURACIO, 1
    
    MOVF PORTA, 0
    ADDWF GUARDAR_DURACIO, 0
    
    MOVWF POSTINC0, 0 ; Les notes es guarden en camps diferents
    
    ;Després s'envia el ACK
    BSF	    LATB,2,0   ; Configurem el ACK a 1
    CALL STOPACK
    BCF	    LATB,2,0   ; Configurem el ACK a 0
    
    INCF NNOTES, 1 ; nNotes++
    RETURN
    
STOPACK
    
    BTFSC   PORTB,0,0  ; Es mira si el newNote no està activat
    RETURN       ; Si el newNote està activat, El ACK pararà
    
    GOTO STOPACK
    
     
    
    ;
    ; DINTRE DE EL JOC
    ;
    
STARTGAME   ;El joc comença
    
    SETF inGame, 0    ;Ja es fan els periferics de la part del joc amb inGame
    MOVLW .0          ;Si no hi ha cap nota, s'acaba el joc directament
    SUBWF NNOTES, W   ;Aquest cas no era necessari tenir-lo en compte
    BTFSC STATUS, Z, 0
    SETF gameEnd, 0

    CALL READNOTA ;Es llegeix la primera nota i es mostra
	
    ;s'ha d'esperar per acabar el joc
INGAME
    
    BTFSS   PORTB,3,0  ; Si en algun moment s'activa el PCI, es reinicia tot
    GOTO MAIN          ; (logica negativa, PCI = 0)
    
    BTFSS gameEnd, 1, 0
    GOTO INGAME
    
    CALL CLOSEGAME ;Quan s'acaba el joc
    GOTO ENDPROGRAM  ;Quan el joc acabi s'anirà aqui
    
READNOTA   ; Funció per llegir les notes

    MOVF POSTINC1, W       ;Llegeix la nota apuntada per POSTINC1
    MOVWF notaActual, 0

    CALL TREURE_DUR
    
    MOVLW b'00001111'
    ANDWF  notaActual, 1   ;guardar nota
    
    CALL DISPLAY_NOTA    ; Crida la subrutina per processar la nota
   
    CALL DISPLAY_DURACIO    ; Crida la subrutina per processar la duracio

    RETURN 
    
TREURE_DUR
    
    MOVWF durActual, 0     ;guardar duracio
    MOVLW b'11110000'
    ANDWF durActual, 1
    
    RRCF durActual, 1
    RRCF durActual, 1
    RRCF durActual, 1
    RRCF durActual, 1

    RETURN
    
DISPLAY_NOTA 
    ;Rutina per a incrementar el 7S i esperar que es des-premi el polsador (controlant els rebots).
    
    MOVF  notaActual, W
    ADDLW TAULA7S
    MOVFF WREG, TBLPTRL
    TBLRD* ;READ
    MOVFF TABLAT, LATD
    RETURN
    
DISPLAY_DURACIO
    
     BTFSC durActual, 0, 0
     BSF	LATA,4,0
     BTFSS durActual, 0, 0
     BCF	LATA,4,0
     BTFSC durActual, 1, 0
     BSF	LATA,3,0  
     BTFSS durActual, 1, 0
     BCF	LATA,3,0 
     RETURN

    	
     ;
     ; AL ACABAR EL JOC
     ;
    
    
CLOSEGAME
    
    BCF	LATA,3,0 
    BCF	LATA,4,0 
    
    BCF	LATC,6,0 
    BCF	LATC,7,0 ;Apagar tots els LEDs
    
    SETF PORTD, 0
    BCF  PORTD, 1, 0 ; posar '-' al 7 seg
    
    SETF ESTAT_SENSOR, 0 ;Posar la maquina d'estats en 
			    ;un estat on es queda bloquejat
    CLRF inGame, 1	;Els periferics del joc paren
    
    RETURN
    
ENDPROGRAM   ;Aquesta funcio anira quan s'acabi el joc
    
    BTFSS   PORTB,3,0  ; Si en algun moment s'activa el PCI, es reinicia tot
    GOTO MAIN          ; (logica negativa, PCI = 0)
    
    GOTO ENDPROGRAM
    

    END