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
  kaverageamp init 100
  kaveragefreq init 5
  ifn = 1
  kvamp vibr kaverageamp, kaveragefreq, ifn
  kvf vibr 30, 22, ifn

  ; Generate a tone including the vibrato.
  kf linseg 440, p3*0.25, 550, p3*0.75, 800
  ka xadsr p3*0.1, p3*0.2, 0.4, p3*0.3
  a1 oscili 20000*ka+kvamp, kf+kvf, 2

  out a1
endin


</CsInstruments>
<CsScore>

; Table #1, a sine wave for the vibrato.
f 1 0 256 10 1
; Table #1, a sine wave for the oscillator.
f 2 0 16384 10 1

; Play Instrument #1 for 0.25 seconds.
i 1 0 0.25
e


</CsScore>
</CsoundSynthesizer>
