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
sr = 44100
ksmps = 128
nchnls = 1

instr 1
   kamp = 10000
   kcps = 440
   ifn = 1
   k1 linseg 0, p3*0.4, 1, p3*0.6, 0
   k2 linseg 0, p3*0.3, 1, p3*0.7, 0.5
   arand rand 22050
   a1 butterhp arand * k1, 2000 * (1+k2)
   k3 linseg 0, p3*0.05, 3, p3*0.1, 0.3, p3*0.8, 0
   out a1*k3*0.5
endin
</CsInstruments>

<CsScore>

; Play instrument 1 for 0.5 seconds
i 1 0 0.5
</CsScore>

</CsoundSynthesizer>
