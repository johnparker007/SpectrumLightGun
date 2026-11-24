# Timing and memory

Startup selects ordinary +2A/+3 paging with 1FFD=4, then 7FFD=16 on all models. Bank 5 is displayed, bank 0 is at C000 and the 48 BASIC font is visible. Code, private stack, IM2 vector and capture buffers are in fixed bank 2. During top border only, the attribute fill temporarily uses SP in screen RAM with interrupts disabled. Ink and paper are equal, so the previous bitmap cannot show through white or black.

AY register 7 is read/modified/written through FFFD/BFFD with bit 6 clear for input, then read back. The program saves R0, tests two complementary patterns ($59/$A6) using ten actual INIs, restores R0 and selects R14. Light is bit 4 high; trigger is bit 5 low. INI reads BC before decrementing B and stores the full byte. Reloading B=$FF each line produces FFFD, FEFD, FDFD, FCFD, FBFD, FAFD, F9FD, F8FD, F7FD, F6FD. A15/A14 remain set and A1 clear. On the grey +2 these odd-port addresses correspond to uncontended bank 0. I=$81 keeps the internal I:R cycle uncontended too. Bank 0 and bank 2 are also uncontended on the black machines.

| One raster line | T-states |
|---|---:|
| LD B,$FF | 7 |
| Ten unrolled INI instructions | 160 |
| LD A,0 and nine NOPs | 43 |
| DEC IXH and JP NZ,line (either outcome) | 18 |
| **Total** | **228** |

INI takes 16 T at approximately 3.5469 MHz, or 4.51 µs / 32 pixel periods. Its sequence is two 4T fetches, one internal T, four T for I/O and three T for the RAM write. The input latch at the start of I/O T3 is **12 T after instruction start**. The result write occurs later.

| From interrupt acceptance to line-zero first input latch | T-states |
|---|---:|
| IM2 entry and ISR including flag preservation | 83 |
| DI, save SP, set SP, 384 pushes, restore SP | 4 + 20 + 10 + 4224 + 10 |
| Set BC, dispatch, phase path, JP coarse | 10 + 10 + (12 + phase) + 10 |
| Two 256-iteration DJNZ loops, one 250-iteration loop, six NOPs | 6660 + 3252 + 24 |
| Reload B and reach INI input latch | 7 + 12 |
| **Total** | **14348 + phase** |

The nominal digital origin is 14364 T (63×228) after frame interrupt. There are 311 lines per frame and 128 T of active pixels per picture line. A halted CPU can add 0–3 T of interrupt acceptance latency. On scanline Y, sample I occurs at nominal **14364 + 228Y − 16 + phase + 16I** plus that latency. The 84T line-to-line sample gap is never used as a 16T edge. Late phases can put sample zero inside the first few picture pixels; a high there gives HIGH.

For an adjacent low/high edge, U = 2×(−16 + phase + 16I). The nominal interval is [U−32,U]. The display bounds [U−32,U+6] include the three-T latency allowance. Intersect with [0,255] before taking the midpoint. At phase zero, index nine gives [224,262] and raw X=239. No right-edge timestamp wraps to the left. These are digital sampling bounds; the physical CRT origin and sensor latency require measurement.

The sweep reads contended display RAM on its last result frame before the blank preframe to stabilise the next HALT phase. The memory access starts at T=14435 plus acceptance jitter, in the first line's contention window. In ZEsarUX the sweep's first INI instruction starts at 14339..14354 on P2 and 14337..14352 on P2A41/P341. The last line ends 43,769 T after the first INI starts (192×228−7). Compare the gun light signal, AY read strobe and video sync/active onset on real hardware to check the physical alignment.

## Assembled footprint

The counted line body is **38 bytes**. Repeating it 192 times plus a 1,920-byte frame would take **9,216 bytes**. The actual counted body plus one frame is **1,958 bytes**. Six buffers fit in bank 2 for consecutive tracking captures.

| Inclusive addresses | Use |
|---|---|
| $8000�$8E12 | 3,603 bytes of vectors, code, UI, state and sweep history |
| $8E13�$8E92 | 128-byte private stack |
| $8E93�$BB92 | Six 1,920-byte raw frames |

The CODE payload is 15,251 bytes including reserved RAM. Use `python tools/build.py --symbols magnum.sym` for exact addresses. Raw byte offset = 10×Y+I. The white shot starts at `samples` and its black preframe at `samples+1920`. In tracking, slot zero is the first white raster. High-run lengths and adjacent low samples can bound an observed pulse; a pulse completely between reads leaves no high byte. CRT persistence, phosphor, brightness, distance and aiming motion all affect the experiment.

References include the [Magnum AUX assignments](https://k1.spdns.de/Develop/Projects/zxsp/Info/nocash%20Sinclair%20ZX%20Specs.html), [128K-family timing and paging](https://rk.nvg.ntnu.no/sinclair/faq/tech_128.html), [contention and INI cycle breakdown](https://sinclair.wiki.zxnet.co.uk/wiki/Contended_memory), [Zilog I/O timing](https://www.zilog.com/docs/z80/um0080.pdf) and MAME's [128K](https://github.com/mamedev/mame/blob/master/src/mame/sinclair/spec128.cpp) and [+3](https://github.com/mamedev/mame/blob/master/src/mame/sinclair/specpls3.cpp) port maps.




### Grid shot timing

The grid build uses ten reads of the canonical AY port per line. Each 12T input plus its 4T register operation occupies one 16T slot. The loop stores two bytes per line (first level and bitwise OR of all ten reads) in fixed bank 2. Its 7T reload, 160T polling, 43T storage/padding and 18T loop control total 228T. A high on the very first read invalidates the shot. Otherwise, the first line with bit 4 set selects the lane. An empty capture examines all 192 summaries.

The lane decision runs immediately after the last line. At the next interrupt the game clears the flash attributes, restores the board colours and ammo, and updates the bitmap only for changed slots. Run `python tools/verify_grid.py` for the MAME timing regression. On the +2, +2A and +3 models, the empty-capture decision finished at 66,525T after the flash frame's ISR counter write. The latest board completion measured was 10,275T after the next counter write (bottom-lane hit), about 1.1 ms before nominal active picture. The probe checks all 1,920 port-read times and all 768 result attributes for each shot. These are emulated timings with synthetic gun signals.
