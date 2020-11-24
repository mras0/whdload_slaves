;*---------------------------------------------------------------------------
;  :Program.	BoppinHD.asm
;  :Contents.	Slave for "Boppin"
;  :Author.	JOTD, from Wepl sources
;  :Original	v1 
;  :Version.	$Id: BoppinHD.asm 1.2 2002/02/08 01:18:39 wepl Exp wepl $
;  :History.	%DATE% started
;  :Requires.	-
;  :Copyright.	Public Domain
;  :Language.	68000 Assembler
;  :Translator.	Devpac 3.14, Barfly 2.9
;  :To Do.
;---------------------------------------------------------------------------*

	INCDIR	Include:
	INCLUDE	whdload.i
	INCLUDE	whdmacros.i
	INCLUDE	lvo/dos.i

CHIP_ONLY
	IFD BARFLY
	OUTPUT	"FinalAssault.slave"
	IFND	CHIP_ONLY
	BOPT	O+				;enable optimizing
	BOPT	OG+				;enable optimizing
	ENDC
	BOPT	ODd-				;disable mul optimizing
	BOPT	ODe-				;disable mul optimizing
	BOPT	w4-				;disable 64k warnings
	BOPT	wo-			;disable optimizer warnings
	SUPER
	ENDC

;============================================================================


	IFD	CHIP_ONLY
HRTMON
CHIPMEMSIZE	= $100000
FASTMEMSIZE	= $0000
	ELSE
BLACKSCREEN
CHIPMEMSIZE	= $100000
FASTMEMSIZE	= $100000
	ENDC

NUMDRIVES	= 1
WPDRIVES	= %0000

;DISKSONBOOT
DOSASSIGN
;INITAGA
HDINIT
IOCACHE		= 10000
;MEMFREE	= $200
;NEEDFPU
;SETPATCH
;STACKSIZE = 10000
BOOTDOS
CACHECHIPDATA
SEGTRACKER


slv_Version	= 17
slv_Flags	= WHDLF_NoError|WHDLF_Examine
slv_keyexit	= $5D	; num '*'

	include	kick13.s

;============================================================================

	IFD BARFLY
	DOSCMD	"WDate  >T:date"
	ENDC

DECL_VERSION:MACRO
	dc.b	"1.0"
	IFD BARFLY
		dc.b	" "
		INCBIN	"T:date"
	ENDC
	IFD	DATETIME
		dc.b	" "
		incbin	datetime
	ENDC
	ENDM
	dc.b	"$","VER: slave "
	DECL_VERSION
	dc.b	0

assign1:
	dc.b	"Final Assault",0

slv_name		dc.b	"FinalAssault"
	IFD	CHIP_ONLY
	dc.b	" (DEBUG/CHIP MODE)"
	ENDC
			dc.b	0
slv_copy		dc.b	"1987-1988 Inforgrames / Epyx",0
slv_info		dc.b	"adapted by JOTD",10,10
		dc.b	"Version "
		DECL_VERSION
		dc.b	0
slv_CurrentDir:
	dc.b	"data",0

program:
	dc.b	"biv",0
args		dc.b	10
args_end
	dc.b	0
slv_config
;	dc.b    "C1:X:Trainer Infinite lives:0;"
	dc.b	0

; version xx.slave works

	dc.b	"$","VER: slave "
	DECL_VERSION
	dc.b	0
	EVEN

_bootdos
		clr.l	$0.W

	; saves registers (needed for BCPL stuff, global vector, ...)

		lea	(_saveregs,pc),a0
		movem.l	d1-d7/a1-a2/a4-a6,(a0)
		lea	_stacksize(pc),a2
		move.l	4(a7),(a2)

		move.l	_resload(pc),a2		;A2 = resload

	
	;open doslib
		lea	(_dosname,pc),a1
		move.l	(4),a6
		jsr	(_LVOOldOpenLibrary,a6)
		move.l	d0,a6			;A6 = dosbase
	;assigns
		lea	assign1(pc),a0
		sub.l	a1,a1
		bsr	_dos_assign

    IFD CHIP_ONLY
    move.l  a6,-(a7)
    move.l  4,a6
    move.l  #$20000-$0001BBA8-$138,d0
    move.l  #MEMF_CHIP,d1
    jsr     _LVOAllocMem(a6)
    move.l  (a7)+,a6
    ENDC
    
	;load exe
		lea	program(pc),a0
		lea	args(pc),a1
		moveq	#args_end-args,d0
		lea	patch_main(pc),a5
		bsr	load_exe
	;quit
_quit		pea	TDREASON_OK
		move.l	(_resload,pc),a2
		jmp	(resload_Abort,a2)

; < d7: seglist (BPTR)

patch_main
	bsr	get_version
	lea	patch_table(pc),a1
    cmp.l   #2,d0
    beq.b   .us_encrypted
	add.w   d0,d0
    lea patch_table(pc),a0
    add.w  (a1,d0.w),a0
        
    move.l  d7,a1
    move.l  _resload(pc),a2
    jsr resload_PatchSeg(a2)
    rts
.us_encrypted
    ; save segment (encrypted version will need it)
    lea first_segment(pc),a2
    add.l   d7,d7
    add.l   d7,d7
    addq.l  #4,d7
    move.l  d7,(a2)
    IFD CHIP_ONLY
    move.l  d7,$100.W
    ENDC
    

DECRYPT_PASS:MACRO
us_encrypted_start_\1:
	MOVEA.L	first_segment(pc),A0		;2fa86: 206d0024    ; start ($20000)
    move.l  a0,d0
    add.l   #\2,d0
    move.l  d0,(2,a0)       ; adjust jump/jsr
    ; now decrypt the rest of the executable
	lea decrypt_offset_len_table_\1(pc),A2		;2fa78: this table isn't in clear at start, we ripped it
	MOVE.W	#\3,D2			;2fa7c: this key was ripped too
	MOVEQ	#0,D0			;2fa7e: 7000
	MOVEQ	#0,D3			; changes nothing...
    
    ; final decryption of the code (A500 std config code at $1FBF8, start $10178)
    ; D2 = $66CB
.LAB_000B:
	MOVE.W	(A2)+,D0		;2fa80: 301a
	MOVE.W	(A2)+,D3		;2fa82: 361a
	BEQ.S	.LAB_000D		;2fa84: 671e
	MOVEA.L	first_segment(pc),A0		;2fa86: 206d0024    ; start ($20000)
	ADDA.L	D0,A0			;2fa8a: d1c0
	ADDA.L	D0,A0			;2fa8c: d1c0
	lea decrypt_keys_\1(pc),A1		;2fa86: 206d0024    ; start ($20000)
	SUBQ.W	#2,D3			;2fa92: 5543
.LAB_000C:
	MOVE.W	(A0)+,D0		;2fa94: 3018
	MOVE.B	(A1)+,D1		;2fa96: 1219
	EOR.W	D2,D0			;2fa98: b540
	EOR.B	D1,D0			;2fa9a: b300
	EOR.W	D0,(A0)			;2fa9c: b150
	DBF	D3,.LAB_000C		;2fa9e: 51cbfff4
	BRA.S	.LAB_000B		;2faa2: 60dc
.LAB_000D
    ENDM

; executable is encrypted, and the encrypted executable is
; encrypted a second time (same tool), so it needs 2 almost identical
; passes to decrypt

    DECRYPT_PASS    1,$F130,$66CB
    DECRYPT_PASS    2,$E99C,$5D7C
    move.l  d7,a1
    lea pl_us_encrypted(pc),a0
    move.l  _resload(pc),a2
    jsr resload_PatchSeg(a2)
    rts
    
	;MOVEA.L	first_segment(pc),-(a7)		;2fa86: 206d0024    ; start ($20000)
    ;rts
    
patch_table:
    dc.w    pl_english_noprotection-patch_table
    dc.w    pl_french_noprotection-patch_table

pl_english_noprotection
    PL_START
    PL_PSS  $0e51e,dma_sound_wait_1,2
    PL_PSS  $0e530,dma_sound_wait_2,2
    PL_END
    
pl_french_noprotection
    PL_START
    PL_PSS  $0e2f2,dma_sound_wait_1,2
    PL_PSS  $0e304,dma_sound_wait_2,2
    PL_END
    
pl_us_encrypted
    PL_START
    ;PL_PS    $0,us_encrypted_start
    PL_END
    


dma_sound_wait_1:
	move.w  d0,-(a7)
	move.w	#4,d0
.bd_loop1
	move.w  d0,-(a7)
    move.b	$dff006,d0	; VPOS
.bd_loop2
	cmp.b	$dff006,d0
	beq.s	.bd_loop2
	move.w	(a7)+,d0
	dbf	d0,.bd_loop1
	move.w	(a7)+,d0
    rts
dma_sound_wait_2:
	move.w  d0,-(a7)
	move.w	#2,d0
.bd_loop1
	move.w  d0,-(a7)
    move.b	$dff006,d0	; VPOS
.bd_loop2
	cmp.b	$dff006,d0
	beq.s	.bd_loop2
	move.w	(a7)+,d0
	dbf	d0,.bd_loop1
	move.w	(a7)+,d0
    rts
get_version:
	movem.l	d1/a1,-(a7)
	lea	program(pc),A0
	move.l	_resload(pc),a2
	jsr	resload_GetFileSize(a2)

	cmp.l	#85804,D0
	beq.b	.english_noprotection

	cmp.l	#85156,d0
	beq.b	.french_noprotection

	cmp.l	#88524,d0
	beq.b	.us_encrypted


	pea	TDREASON_WRONGVER
	move.l	_resload(pc),-(a7)
	addq.l	#resload_Abort,(a7)
	rts

.english_noprotection
	moveq	#0,d0
	bra.b	.out
.french_noprotection
	moveq	#1,d0
	bra.b	.out
.us_encrypted
	moveq	#2,d0
	bra	.out
.out
	movem.l	(a7)+,d1/a1
	rts



; < a0: program name
; < a1: arguments
; < d0: argument string length
; < a5: patch routine (0 if no patch routine)


load_exe:
	movem.l	d0-a6,-(a7)
	move.l	d0,d2
	move.l	a0,a3
	move.l	a1,a4
	move.l	a0,d1
	jsr	(_LVOLoadSeg,a6)

	move.l	d0,d7			;D7 = segment
	beq	.end			;file not found

	;patch here
	cmp.l	#0,A5
	beq.b	.skip
	movem.l	d2/d7/a4,-(a7)


	jsr	(a5)
	bsr	_flushcache
	movem.l	(a7)+,d2/d7/a4
.skip
	;call
	move.l	d7,a3
	add.l	a3,a3
	add.l	a3,a3

	move.l	a4,a0

	movem.l	d7/a6,-(a7)

	move.l	d2,d0			; argument string length
	move.l	_stacksize(pc),-(a7)	; original stack format
	movem.l	(_saveregs,pc),d1-d7/a1-a2/a4-a6	; original registers (BCPL stuff)
	jsr	(4,a3)		; call program
	addq.l	#4,a7

	movem.l	(a7)+,d7/a6

	;remove exe

	move.l	d7,d1
	jsr	(_LVOUnLoadSeg,a6)

	movem.l	(a7)+,d0-a6
	rts

.end
	jsr	(_LVOIoErr,a6)
	move.l	a3,-(a7)
	move.l	d0,-(a7)
	pea	TDREASON_DOSREAD
	move.l	(_resload,pc),-(a7)
	add.l	#resload_Abort,(a7)
	rts

_saveregs
		ds.l	16,0
_stacksize
		dc.l	0

first_segment
    dc.l    0
    
decrypt_offset_len_table_1:
     dc.w   $0003,$0536,$0539,$0536,$0A6F,$0536,$0FA5,$0536
     dc.w   $14DB,$0536,$1A11,$0536,$1F47,$0536,$247D,$0536
     dc.w   $29B3,$0536,$2EE9,$0536,$341F,$0536,$3955,$0536
     dc.w   $3E8B,$0536,$43C1,$0536,$48F7,$0536,$4E2D,$0536
     dc.w   $5363,$0536,$5899,$0536,$5DCF,$0536,$6305,$0428
     dc.w   $6735,$000D,$674B,$0058,$67A5,$012C,$68D7,$000A
     dc.w   $68E6,$0011,$68F9,$0006,$6907,$001E,$6927,$0014
     dc.w   $6940,$013A,$6A80,$0005,$6A8D,$0046,$6AD5,$0006
     dc.w   $6ADD,$0008,$6AED,$0011,$6B00,$0007,$6B09,$0049
     dc.w   $6B54,$000F,$6B69,$0029,$6B94,$0019,$6BAF,$008C
     dc.w   $6C3D,$0005,$6C44,$001A,$6C64,$000B,$6C71,$0006
     dc.w   $6C79,$0008,$6C8C,$0009,$6CA0,$0015,$6CBE,$0006
     dc.w   $6CCE,$0010,$6CE0,$000F,$6CF1,$001B,$6D26,$000F
     dc.w   $6D37,$0025,$6D5E,$0007,$6D6A,$0010,$6D7C,$0012
     dc.w   $6D99,$005F,$6E18,$0056,$6E73,$0021,$6E9B,$0119
     dc.w   $6FC7,$0101,$70CA,$0008,$70D4,$0097,$716D,$001D
     dc.w   $718C,$0006,$7194,$0006,$719C,$0006,$71A4,$000B
     dc.w   $71B1,$001D,$71D3,$000C,$71E1,$0058,$723B,$000F
     dc.w   $724C,$0033,$7281,$00FF,$7382,$0040,$73C4,$0031
     dc.w   $73F7,$0536,$792D,$01FA,$7B29,$000F,$0000,$0000

decrypt_offset_len_table_2:
     dc.w   $0003,$0536,$0539,$0536,$0A6F,$0536,$0FA5,$0536
     dc.w   $14DB,$0536,$1A11,$0536,$1F47,$0536,$247D,$0536
     dc.w   $29B3,$0536,$2EE9,$0536,$341F,$0536,$3955,$0536
     dc.w   $3E8B,$0536,$43C1,$0536,$48F7,$0536,$4E2D,$0536
     dc.w   $5363,$0536,$5899,$0536,$5DCF,$0536,$6305,$0428
     dc.w   $6735,$000D,$674B,$0058,$67A5,$012C,$68D7,$000A
     dc.w   $68E6,$0011,$68F9,$0006,$6907,$001E,$6927,$0014
     dc.w   $6940,$013A,$6A80,$0005,$6A8D,$0046,$6AD5,$0006
     dc.w   $6ADD,$0008,$6AED,$0011,$6B00,$0007,$6B09,$0049
     dc.w   $6B54,$000F,$6B69,$0029,$6B94,$0019,$6BAF,$008C
     dc.w   $6C3D,$0005,$6C44,$001A,$6C64,$000B,$6C71,$0006
     dc.w   $6C79,$0008,$6C8C,$0009,$6CA0,$0015,$6CBE,$0006
     dc.w   $6CCE,$0010,$6CE0,$000F,$6CF1,$001B,$6D26,$000F
     dc.w   $6D37,$0025,$6D5E,$0007,$6D6A,$0010,$6D7C,$0012
     dc.w   $6D99,$005F,$6E18,$0056,$6E73,$0021,$6E9B,$0119
     dc.w   $6FC7,$0101,$70CA,$0008,$70D4,$0097,$716D,$001D
     dc.w   $718C,$0006,$7194,$0006,$719C,$0006,$71A4,$000B
     dc.w   $71B1,$001D,$71D3,$000C,$71E1,$0058,$723B,$000F
     dc.w   $724C,$0033,$7281,$00FF,$7382,$0040,$73C4,$0031
     dc.w   $73F7,$0491,$0000,$0000
    
; this is the data+code that the program starts to decrypt (2 passes)
; when it starts. those bytes are used as a key for the final decryption    
; we could have let the code run but that involved a lot of system calls
; including trackdisk shit and all so under whdload not sure how it would
; have reacted. Better rip it from a running emulated session with real
; IPF file with protection on a A500 emulated system.
; big kudos to the people who cracked that with real amigas. Not impossible
; but damn tricky.

decrypt_keys_1:
    incbin  "decrypt_keys_1.bin"
decrypt_keys_2:
    incbin  "decrypt_keys_2.bin"
    