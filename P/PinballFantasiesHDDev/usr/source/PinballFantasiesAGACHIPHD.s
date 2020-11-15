;*---------------------------------------------------------------------------
;  :Program.	PinballFantasiesHD.asm
;  :Contents.	Slave for "PinballFantasies"
;  :Author.	JOTD, from Wepl sources
;  :Original	v1 
;  :Version.	$Id: PinballFantasiesHD.asm 1.2 2002/02/08 01:18:39 wepl Exp wepl $
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

	IFD BARFLY
	OUTPUT	"PinballFantasiesCHIPONLY.slave"
	BOPT	O+				;enable optimizing
	BOPT	OG+				;enable optimizing
	BOPT	ODd-				;disable mul optimizing
	BOPT	ODe-				;disable mul optimizing
	BOPT	w4-				;disable 64k warnings
	BOPT	wo-			;disable optimizer warnings
	SUPER
	ENDC

;============================================================================

CHIPMEMSIZE	= $1FF000
FASTMEMSIZE	= $20000	; just for OS memory
NUMDRIVES	= 1
WPDRIVES	= %0000

;BLACKSCREEN
;DISKSONBOOT
;DOSASSIGN
;DEBUG	: with it nonvolatile.lib fails
HDINIT
;HRTMON
IOCACHE		= 10000
;MEMFREE	= $200
;NEEDFPU
;SETPATCH
BOOTDOS
CACHE
CBDOSLOADSEG
FONTHEIGHT = 8

;============================================================================


slv_Version	= 16
slv_Flags	= WHDLF_NoError|WHDLF_ReqAGA|WHDLF_Req68020|WHDLF_Examine
slv_keyexit	= $5D	; num '*'

;============================================================================

	INCLUDE	kick31.s

;============================================================================

	IFD BARFLY
	DOSCMD	"WDate  >T:date"
	ENDC

	IFD BARFLY
	IFND	.passchk
	DOSCMD	"WDate  >T:date"
.passchk
	ENDC
	ENDC

DECL_VERSION:MACRO
	dc.b	"3.0"
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

slv_name		dc.b	"Pinball Fantasies CD��/AGA (CHIPONLY)",0
slv_copy		dc.b	"1994 21st Century Entertainment",0
slv_info		dc.b	"adapted by JOTD",10
		dc.b	"Version "
		DECL_VERSION
		dc.b	0
slv_CurrentDir:
	dc.b	"data",0


	dc.b	"$","VER: slave "
	DECL_VERSION
	dc.b	0
	EVEN

_program:
	dc.b	"Pinball",0
_args		dc.b	10
_args_end
	dc.b	0


	EVEN

;============================================================================

	;initialize kickstart and environment

_bootdos
	clr.l	$0.W

	bsr	_flushcache

	move.l	(_resload,pc),a2		;A2 = resload

	;open doslib
	lea	(_dosname,pc),a1
	move.l	(4),a6
	jsr	(_LVOOldOpenLibrary,a6)
	move.l	d0,a6			;A6 = dosbase


	;load exe
		lea	_program(pc),a0
		move.l	a0,d1
		jsr	(_LVOLoadSeg,a6)
		move.l	d0,d7			;D7 = segment
		beq	_end			;file not found


	;patch here

	;call
		move.l	d7,a1
		add.l	a1,a1
		add.l	a1,a1
		lea	(_args,pc),a0
		move.l	(4,a7),d0		;stacksize
		sub.l	#5*4,d0			;required for MANX stack check
		movem.l	d0/d7/a2/a6,-(a7)
		moveq	#_args_end-_args,d0
		jsr	(4,a1)
		movem.l	(a7)+,d1/d7/a2/a6

	;remove exe
		move.l	d7,d1
		jsr	(_LVOUnLoadSeg,a6)

	;quit
_quit		pea	TDREASON_OK
		move.l	(_resload,pc),a2
		jmp	(resload_Abort,a2)

_end
	jsr	(_LVOIoErr,a6)
	pea	_program(pc)
	move.l	d0,-(a7)
	pea	TDREASON_DOSREAD
	move.l	(_resload,pc),-(a7)
	add.l	#resload_Abort,(a7)
	rts

; < D0: BSTR filename
; < D1: seglist

_cb_dosLoadSeg:
	move.l	d1,a3
	add.l	a3,a3
	add.l	a3,a3
	move.l	d0,a0
	add.l	a0,a0
	add.l	a0,a0

	cmp.b	#'p',1(a0)
	beq.b	.1
	cmp.b	#'P',1(a0)
	bne.b	.out		; not a patchable file
.1
	cmp.b	#7,(a0)
	bne.b	.nopinball
	cmp.w	#$4EB9,$224(a3)
	bne.b	.nopinball
	cmp.w	#$4E75,$22A(a3)
	bne.b	.nopinball
	move.w	#$4E75,$224(a3)	; skip protection on AGA version
.nopinball
	bsr	.remove_vbr

	cmp.l	#'FILE',4(a0)
	bne.b	.notable


	move.w	#$0000,$DFF1FC		; fixes gfx bugs on tables
	move.w	#$0044,$DFF10C		; fixes gfx bugs on sprite (ball)
	move.w	#$0000,$DFF106		; fixes gfx bugs on tables
	cmp.b	#'D',8(a0)
	beq.b	.table4			; skulls
	cmp.b	#'B',8(a0)
	bne.b	.table1
	move.w	#$00BB,$DFF10C		; fixes gfx bugs on sprite (ball, level 2)
	bra.b	.table1


.notable:
.out
	rts

; tables 1 2 and 3 are similarly patched

ID_LONG = $0881001E
.table1:
	addq.l	#4,a3
	cmp.l	#ID_LONG,$42EA(a3)
	beq.b	.pal

	; ntsc: shifted by 6 bytes

	addq.l	#6,a3
	cmp.l	#ID_LONG,$42EA(a3)
	bne.b	.wrong_version
.pal
	rts

.wrong_version
	pea	TDREASON_WRONGVER
	move.l	_resload(pc),-(a7)
	addq.l	#resload_Abort,(a7)
	rts

.table4:
	addq.l	#4,a3

	cmp.l	#ID_LONG,$42F0(a3)
	beq.b	.pal4

	; ntsc: shifted by 6 bytes

	addq.l	#6,a3
	cmp.l	#ID_LONG,$42F0(a3)
	bne.b	.wrong_version
.pal4

	; change position of the #30 bit

	rts

; remove VBR read on first segment of files pinball, PINFILE?.DAT

.remove_vbr:
	movem.l	d0-d1/a0-a1,-(a7)
	move.l	a3,a0
	lea	$1000(a0),a1
	move.l	#$4E7A0801,D0
	move.l	#$4E717000,D1
	bsr	_hexreplacelong
	movem.l	(a7)+,d0-d1/a0-a1
	rts




_hexreplacelong:
	movem.l	A0-A1/D0-D1,-(A7)
.srch
	cmp.l	(A0),D0
	beq.b	.found
.next
	addq.l	#2,A0
	cmp.l	A1,A0
	bcc.b	.exit
	bra.b	.srch
.found
	move.l	D1,(A0)+
	bra	.next
.exit
	movem.l	(A7)+,A0-A1/D0-D1
	rts

;< A0: start
;< A1: end
;< A2: bytes
;< D0: length
;> A0: address or 0 if not found

_hexsearch:
	movem.l	D1/D3/A1-A2,-(A7)
.addrloop:
	moveq.l	#0,D3
.strloop:
	move.b	(A0,D3.L),D1	; gets byte
	cmp.b	(A2,D3.L),D1	; compares it to the user string
	bne.b	.notok		; nope
	addq.l	#1,D3
	cmp.l	D0,D3
	bcs.b	.strloop

	; pattern was entirely found!

	bra.b	.exit
.notok:
	addq.l	#1,A0	; next byte please
	cmp.l	A0,A1
	bcc.b	.addrloop	; end?
	sub.l	A0,A0
.exit:
	movem.l	(A7)+,D1/D3/A1-A2
	rts

;============================================================================

	END
