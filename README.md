# Spectrum Lightgun

Play **[Raster Fair](build/arcade.tap)** for the gun-controlled 64-challenge arcade. Every challenge has its own NIRVANA+ playfield. [See all 64 stages](build/screenshots/arcade-gallery.png). **Play-Arcade.bat** starts the MAME mouse version. [Controls, frontend plan and CRT test](ARCADE.md).

Load **[magnum.tap](build/magnum.tap)** on a PAL grey +2, black +2A or +3 connected to a CRT. The tape starts in uncalibrated trigger mode with a black preframe (PRE 1). The experiment measures whether one raster can distinguish aim points 40 pixels apart. On one real +2A/CRT setup the operator reported reliable off-screen misses, over 75% HIGH on-screen, and widely separated X estimates at fixed aim. These are initial observations; no raw traces or exact attempt counts accompanied the report.

## Real-hardware follow-up: capture transitions across the whole scanline

Load **[edges.tap](build/edges.tap)** on the PAL +2A and CRT. The tape starts in EDGE TEST with a dim aim dot at A (108,96). Key **5** switches between A and B (148,96). Take five individual trigger shots per point with the gun supported. Keep CRT controls, distance and height fixed. Record the target, FIRST+, LAST-, EDGES, START and END from each shot **before switching targets**. A handwritten list is enough. If EDGE TEST is replaced by PORT!, record the failing port and stop interpreting results.

Each press gives one black frame then one uniformly white frame. The capture starts at nominal picture line 48 and ends partway through line 144. It takes 1,368 samples including the horizontal borders and retrace. A normal sample gap is 16 T; reloading B after every 57 reads makes that one gap 23 T. The program tests all 57 AY port aliases on startup.

All readings are hex. FIRST+ and LAST- are the first observed rise and last observed fall, each printed as **scanline:horizontal T-state**. Horizontal phase runs from 00 to E3 across all 228 T, including blanking. Each timestamp names the first sample at the new level. Key **8** pages through individual transitions in chronological order; W is the time since the preceding sample (10 or 17 hex). START and END give the actual first and final light bits. A high level at the start is not counted as a rise. Dashes mean no observed transition of that kind. A flat high capture and a flat low capture both have zero transitions.

At equal height a 40-pixel move predicts a nominal +14 hex (20 T) displacement for an edge locked to the aimed beam position. Compare the same transition type across repeated shots before interpreting a difference between targets; phase wraps at E4, and both sample spacing and interrupt latency limit precision. No correction or smoothing is applied. To rebuild use `python tools/build.py --edges`; to verify use `python tools/verify_edges.py --mame PATH --rompath ROMS`. The emulator check measures every within-capture read interval and exercises multi-edge, flat and alternating synthetic waveforms.

## Mouse test on this PC

Double-click **Mouse-Test.bat** in the repository. It launches the installed MAME 0.270 in a +2A window and loads the diagnostic directly. Aim inside the picture and left-click once. EDGE and a cyan cross show a hit; a click in the border gives MISS. Escape closes MAME. The launcher uses installed ROMs and SjASMPlus automatically. On another installation, pass `--mame PATH --rompath ROMS --assembler PATH` to the batch file.

The mouse adapter supplies the trigger and a synthetic 16T light pulse at the cursor on white scanlines. The Spectrum program performs the capture and plots the result. This checks input handling and presentation; CRT performance still requires the physical Magnum.

## First shots

1. With power off, connect the stock Sinclair Magnum to AUX/keypad. Use the tape loader from the normal 128K startup menu. On a +3 leave the drive empty and acknowledge the tape prompt. Alternatively, from +3 BASIC enter `LOAD "t:"` then `LOAD ""`.
2. Release the trigger. **READY** and **P--** indicate that the port test passed. **PORT!** invalidates a measurement. The two digits after P identify the first failing port high byte, for example PFE for FEFD.
3. Aim and press once. One white playfield frame is followed by black. **EDGE** plots a dark-blue 8×8 marker. **MISS** clears it. Hold the trigger to verify there is no second flash, then release to rearm.
4. Press **5** to select aim point **4** (108,96) or **5** (148,96). Alternate the points, keeping distance and brightness fixed. Record at least 20 fresh shots per point, including misses. Classify raw X below 128 as left, otherwise right. Count wrong-side readings and dropouts separately, using all attempts as the denominator. Repeat with **1 PRE** toggled off and on each target machine.

| Control | Diagnostic |
|---|---|
| Trigger | Capture a single white frame. Set PRE 0 for the first white frame after the normal display. The result holds until another shot or mode selection. |
| 1 PRE | Toggle a completely black, sampled frame immediately before white. BLACK counts high readings out of 1,920 on that frame. Both captures retain their own raw bytes. |
| 2 SWP | Hold the gun fixed for 16 flashes. Phases 0–F advance one T-state per flash, with one blank black frame, one white capture frame and 25 black result frames per step. |
| 4 LOG | Step through the last sweep starting at phase zero. V identifies review. Repeat full sweeps to distinguish persistent phase dropouts from shot-to-shot variation. |
| 3 TRK | Move the gun during six consecutive white frames (about 120 ms). All six raw frames replay once on black, each held for at least ten frames. Missing readings remain visible. |
| 9 BITMAP | After a normal trigger shot, replay the saved white frame as 192 separate bitmap lines. A high sample paints a white horizontal strip over the preceding sampling interval (normally 32 pixels); a low sample paints black. Press 9 again to restore the result. |
| 0 COLOUR | After a trigger shot, show the white-frame light activity on the full attribute screen. Each 32-by-8-pixel patch uses eight bit-4 samples at one horizontal time across eight lines. Black means zero highs, white means eight, intermediate colours show the fraction high. Each patch covers the 32 pixels preceding its sample time. The leftmost patch also includes the clipped left-edge sample, with at most one vote per scanline. Press 0 again to return. |
| 6 MAP | After a trigger shot, freeze the full sensor record. Left grid = white capture, right grid = black preframe when captured. Each grid has ten sample columns in time order and 192 scanlines top to bottom. A thin vertical rule marks each slot; a filled strip is high. Press 6 again to restore the shot display. |
| 5 AIM | Cycle through no guide, top-left (32,32), bottom-right (224,160), centre (128,96), and the two 40-pixel test points. A result square can cover the guide. |

HUD numbers are hexadecimal. **Y** is the first high scanline, **I** its sample index, **LO/HI** signed 16-bit horizontal timing bounds, **X** the midpoint after clipping to the picture, and **CORR X:Y** the plotted coordinates. FFE0 means −32. **PH** is the polling phase, **F** the replay frame. **HIGH** means sample zero on a line was already high; it supplies Y/I only. **BORDR** denotes an interval outside the picture. Dashes indicate unavailable fields. The border stays black in every mode.

## Comparing runs and optional calibration

Use a separate CSV per machine, CRT and setup. The header is:

```csv
target_x,target_y,mode,phase,status,x,y,black
```

Target coordinates are decimal. Copy numeric HUD readings in hex. Use modes `direct`, `pre` or `sweep`, and statuses `E` (EDGE), `H` (HIGH), `-` (MISS), `B` (BORDR). Leave unavailable fields empty. Include BLACK for every preframe shot. Run `python tools/report.py shots.csv` for detection counts, wrong-side counts, black activity, medians and position ranges.

For offset calibration, take five or more shots at each inset corner and the centre in the same trigger mode. With at least three valid edges per corner, the report averages the two corner median offsets and reports the independent centre error. Use its offsets with `python tools/build.py --offset-x N --offset-y M --output build/calibrated.tap`. Raw readings stay visible. Tracking replays raw positions. Consider independent axis scales only if corner residuals exceed repeat-shot spread and additional check points support them.

## Build and checks

Rebuild with Python 3 and SjASMPlus 1.20.2 using `python tools/build.py` or `Build-TAP.bat`. Put SjASMPlus on PATH, set `SJASMPLUS`, or pass `--assembler PATH`. The TAP contains an auto-start BASIC loader and CODE at $8000. Reset to exit.

| Command | Coverage |
|---|---|
| `python tools/verify.py` | Reproducible tape, checksums, assembled decoder on 176 synthetic frames, bounds, marker clearing, black counts and trigger gating with z88dk-ticks. |
| `python tools/verify_emulator.py --emulator PATH` | ZEsarUX TAP boot, phase and frame timing, tracking cadence and an independent port readback on three models. |
| `python tools/verify_mame.py --mame PATH --rompath ROMS` | MAME reads all ten port addresses on every line. Synthetic input exercises a held press, direct hit, black preframe, white miss and marker clearance through the normal application. |

ZEsarUX 10.2 fails the alias check at FEFD. MAME 0.270 passes on the +2, +2A and +3. Neither measures optical pulse width or aiming accuracy. See [timing and memory](TIMING.md).

## Four-lane target game

Load [grid.tap](build/grid.tap) on a PAL +2, +2A or +3 with the AUX Magnum and a CRT. For a PC run, double-click **Play-Grid.bat** with the same MAME setup as Mouse-Test.bat. Rebuild with **Build-TAP.bat --grid**.

Sixteen blue squares appear for about one second. Three or four then turn green together. Shoot the green squares in any order. Each trigger press spends one of the four yellow ammunition pips. Release the trigger between shots. A hit turns its target blue. Clearing the board gives a green border; running out of ammunition with live targets gives a red border. The next layout starts automatically.

For a same-column CRT check, start round 1. The top and bottom targets both occupy column 3 (counting from the left). Shoot the bottom one, check that the top stays green, then shoot the top one. Round 2 has an adjacent pair in the top two rows of column 2. Round 6 puts all four targets in column 2. Try shooting those from bottom to top without moving sideways.

The flash lasts one frame. Only live 16×16 targets become white. The program takes the first detected scanline, splits the 192 lines into four lanes of 48, and removes the live target in that lane. An initially high capture or an empty capture scores no hit. Targets sit in the middle of their lanes. For a hardware check, shoot a blue square level with a green one, then the green one. Check whether the blue shot only uses ammunition and the green shot clears the intended target. Repeat near the green square’s edges to measure optical spill.

The hit decision finishes in the flash frame’s bottom border. The next visible picture already shows the updated targets and ammunition. See [grid shot timing](TIMING.md#grid-shot-timing) for the MAME checks.
