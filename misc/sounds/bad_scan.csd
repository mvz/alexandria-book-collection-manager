; Copyright (C) 2009 Cathal Mc Ginley
;
; This file is part of Alexandria, a book collection manager.
;
; Alexandria is free software; you can redistribute it and/or
; modify it under the terms of the GNU General Public License as
; published by the Free Software Foundation; either version 2 of the
; License, or (at your option) any later version.
;
; Alexandria is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; General Public License for more details.
;
; You should have received a copy of the GNU General Public
; License along with Alexandria; see the file COPYING.  If not,
; write to the Free Software Foundation, Inc., 51 Franklin Street,
; Fifth Floor, Boston, MA 02110-1301 USA.

<CsoundSynthesizer>

<CsInstruments>

; Initialize the global variables.
sr = 44100
kr = 4410
ksmps = 10
nchnls = 1

; Instrument #1.
instr 1
  kaverageamp init 200
  kaveragefreq init 20
  ifn = 1
  kvamp vibr kaverageamp, kaveragefreq, ifn
  kvf vibr 40, 25, ifn
  kvfenv linseg 1, p3*0.5, 0.3, p3*0.5, 0

  ; Generate a tone including the vibrato.
  kf linseg 540, p3*0.15, 700, p3*0.3, 380, p3*0.55, 400
  ka xadsr p3*0.1, p3*0.1, 0.7, p3*0.25
  a1 oscili 10000*ka+kvamp, kf+kvf*kvfenv, 2

  out a1
endin


</CsInstruments>
<CsScore>

; Table #1, a sine wave for the vibrato.
f 1 0 256 10 1
; Table #1, a sine wave for the oscillator.
f 2 0 16384 10 1

; Play Instrument #1 for 0.45 seconds.
i 1 0 0.45
e


</CsScore>
</CsoundSynthesizer>
