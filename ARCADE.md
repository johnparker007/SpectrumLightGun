# Raster Fair

## Playing on a CRT

Load [arcade.tap](build/arcade.tap) from the normal tape loader on a PAL grey +2, black +2A or +3 with an AUX Magnum. Shoot a blue ticket and release the trigger between shots. The whole ticket is selectable. **Play All 64** starts a tour. Shoot **More Games** to cycle through 17 pages of practice tickets. Page one includes the original three games. Every ticket shows the objective and ammunition count when the challenge begins.

Every practice selection, replay and tour stage opens a challenge briefing. Read the objective, check the shot allowance and time limit, then fire at **Shoot Here to Start**. You can take as long as you like. The start shot is free and the play clock begins with the challenge.

In practice, shoot **Play Again** or **Choose a Challenge** on the results card. On tour, shoot **Next Challenge** to carry your score forward. A perfect tour scores 245 points. Release the trigger between cards and shots.

| Page | Challenge | How it plays |
| --- | --- | --- |
| 1 | Tin Can Alley | Clear four fixed cans, including a shared-column pair. |
| 1 | The Powder Yard | Hit green cans and avoid red bombs. A bomb detonates its row and costs two rounds. Loading shelves mark the four firing lanes. |
| 1 | Sine Parade | Hit three moving parade balloons with four rounds in 15 seconds. Their centres stay 48 scanlines apart around the loop. |
| 2 | Chain Relay | Each hit reveals the next bell further down the board. |
| 2 | Ironclad | Hit each shield twice. A damaged shield turns yellow. |
| 2 | Lights Out | Shooting a lit lamp switches it off and flips its neighbours. Score is the number of dark lamps. |
| 2 | Whack A Bell | One lane opens at a time. Catch each bell during its turn within 12 seconds. |
| 3 | Shell Shuffle | The surviving cups jump to new columns after every shot, including misses. |
| 3 | Shield Gate | Green shields can be hit. Blue shields block the shot and still spend ammunition. |
| 3 | Golden Shot | One moving star, one round. |
| 3 | Mirror Twins | One hit clears the matching colour pair, mirrored vertically. |
| 4 | Pendulum Range | Two pairs of weights swing across the board in opposing directions. |
| 4 | Jackpot Chase | The jackpot moves to another lane on each successful hit. Score four hits within 10 seconds. |
| 4 | Afterimage | Memorise the four locations during the preview. Fire once the lights go out. |
| 4 | Short Fuse | Clear four targets before the seven-second play clock expires. |
| 5 | Exact Change | Rows pay one through four from top to bottom. Make exactly five in two shots. Overshooting busts the round. |

Levels 17–64 revisit the gallery rules with new target layouts, time limits and scenery. Each briefing gives the objective, ammunition and clock.

| Levels | Setting | Challenge order |
| --- | --- | --- |
| 17–22 | Harbour | Lighthouse Run, Tugboat Bay, Anchor Watch, Sail Loft, Crane Signal, Dry Dock |
| 23–28 | Orchard | Honey House, Windmill Row, Cider Press, Apple Cart, Watering Time, Silo Sunset |
| 29–34 | Polar | Icebreaker, Igloo Echo, Aurora Dish, Glacier Pass, Snow Goggles, Walrus Wharf |
| 35–40 | Spaceport | Lunar Lander, Orbital Array, Rocket Gantry, Ring Station, Mars Rover, Comet Trail |
| 41–46 | Citadel | Drawbridge, Crown Vault, Dragon Roost, Joust Relay, Tower Key, Moon Grimoire |
| 47–52 | Wild west | Mesa Express, Cactus Gulch, Spur And Saddle, Silver Mine, Sheriff Star, Wagon Wheel |
| 53–58 | Undersea | Nautilus, Coral Garden, Pearl Diver, Octopus Den, Manta Glide, Wreck Signal |
| 59–64 | Workshop | Steam Hammer, Valve Puzzle, Gear Shift, Copper Coils, Pressure Test, Final Foundry |

Every round has a deadline, shown on its briefing and beside the shot counter during play. Short Fuse gives seven seconds for four hits. Lights Out gives 40 seconds to plan the switches, Exact Change gives 32 for the two-shot sum, and Afterimage gives 28 to memorise the layout and shoot. Repeat variants of a rule trim up to three seconds as the tour progresses. The digits turn red for the last three seconds. Capture and result transitions pause the play clock.

### First real-hardware run

1. Shoot the empty black space beside a menu ticket, then the ticket. Only the second shot should change the screen.
2. Open **The Powder Yard**. Shoot the green can in the top row. The shot counter should go from five to four and the red bombs should remain. Shoot a red bomb in the next row. The whole row should flare, its bombs should disappear, its green can should survive, and two shots should remain. Shoot the same empty bomb position again. Only one shot should be spent.
3. Open **Sine Parade**. Follow a target through a few steps and shoot it near the top, then repeat near the bottom. Watch for a neighbouring target disappearing, a missed shot near the wrap, or a trail behind a balloon. Record the machine family if any of these occur.

## Frontend design

The arcade reference pairs short challenges with explicit goals and a result between stages. Raster Fair uses a fairground ticket board to give those breaks a purpose on a Spectrum. The same aim, fire and release gesture selects practice, starts a tour, advances a result and replays a stage. Widely separated vertical choices allow every ticket to use the tested optical input. Each stage displays its objective and remaining shots during play. [Point Blank reference and screenshots](https://thekingofgrabs.com/2023/10/29/point-blank-arcade/)

## Timing, graphics and sound

Menu tickets, briefings, scores and the HUD use Blokius Arcade 8 from Spectrum Attribute Shmup. Its 512-byte bitmap adapts Cody Boisclair’s Press Start 2P. [Font source and SIL Open Font License](art/fonts/)

The game builds the scene on screen 5 and presents a separate optical mask on screen 7. The current target's entire 16×16 footprint is selectable. In the yard, set bitmap pixels on screen 7 belong exclusively to live bombs. The first mask lights live cans with attributes. After a dark capture, one fixed-cost attribute fill exposes the bomb bitmap on the very next frame. An already-high input at the start is ambiguous and consumes a shot. A first-pass hit ends acquisition immediately after that raster. A shot freezes animation, and each pass supplies its own Y reading.

During capture the ULA displays screen 7 while the CPU maps uncontended bank 0 at C000 and runs from bank 2. Neither renderer nor the AY player runs during acquisition. Each raster stores the first level and combined levels of ten reads per scanline. The input port is FFFD for all reads. R7 leaves the AUX port in input mode. The player emits precomputed tone periods on AY channels A/B and software-decayed noise on C for shots and blasts. It reselects R14 after every audio update. This uses the Shmup's division of AY channels and precompiled register approach with a new short score.

All 64 challenges use NIRVANA+ on screen 5. Each backdrop has its own 32 x 22 tile map between the score line and the hint. Each 8 x 8 tile carries four two-scanline colour entries. Stage entry retrieves one compressed set from its scenery bank (3, 1, 4 or 6) and paints it once. The 48 expansion stages have individual illustrations in tools/scenery_plates.py. Moving actors can cross the illustrations. The renderer restores the four underlying tiles, including their raster colours, when a target moves or disappears. Scenery exists only on the visible screen, so the gun sees just the active shot mask.

[View all 64 stages in MAME](build/screenshots/arcade-gallery.png)

NIRVANA+ runs from bank 0 on its own IM2 interrupt during play. The parade uses six scheduled 24×16 wide-tile slots. Three erase the previous positions and three draw the next ones. Eight pre-shifted balloon images provide single-pixel horizontal positioning inside the tile, and the vertical position advances two scanlines each PAL frame. The optical mask covers the 16×16 balloon footprint at the displayed pixel coordinates. Motion freezes during shot capture. AY music advances after the scan in a flash frame. [NIRVANA+](https://sinclair.wiki.zxnet.co.uk/wiki/NIRVANA%2B_Engine)

## Rebuild and verification

For artwork edits, run `python tools/preview_scenery.py` and open `build/scenery-preview.html` in a browser. Click a stage to enlarge it. After each edit rerun the command and refresh. The preview decodes the same compiled tiles used on tape, including the shared colour for each 8 x 2 region. It shows scenery alone. Use the MAME captures to check targets, HUD and motion in context.

Run **Build-TAP.bat --arcade**. The assembler and Python requirements match the diagnostic. The arcade build also needs z88dk's generated NIRVANA+ engine assembly, z80asm and z88dk-zx7. Each backdrop is compressed separately with Einar Saukas's ZX7 and expanded at stage entry. The 64 tile maps and atlases occupy 109,784 bytes before compression and 37,635 bytes after it, plus 256 bytes of bank directories. The NIRVANA+ engine image retains its earlier literal/back-reference packer. Set **Z88DK** to the installation root if it is outside C:/z88dk. Building assembles that source, checks the linked addresses, and packs the engine inside the BASIC-autostart tape. The BASIC tape loader stages three scenery blocks at $8000, copies each to a separate 16 KB bank, restores the BASIC paging state, and loads the game. Allow the tape to play through all blocks. All 64 levels are then resident. The prebuilt tape is self-contained. Run **Play-Arcade.bat** for the local mouse-to-Magnum MAME setup.

Run **python tools/verify_arcade.py** for the scripted MAME route, with additional briefing and start shots, on +2, +2A and +3. It loads the assembled tape payload, derives simulated light from the flashed bitmap and attributes at the aim point, and checks the outcome after every shot. It checks the AY register selection, audio writes, all ten read timings on every line, and consecutive target/bomb frames. The tests cover a detonated row becoming inert, a complete miss, replay, selection, the exact wave mask, a 245/245 sixty-four-stage tour, every stage�s starting deadline and HUD digits, five challenges expiring (including Lights Out at 40 seconds), an exact-change bust and a closed shield. The parade probe compares animation advances and AY note writes across 160 consecutive idle play frames. Use **--screens build/screenshots** to capture the menu, briefings, results and all 64 playable stages. The route checks the scenery bitmap against the source tiles during the tour.

The packaged TAP also booted through the tape loader to the ticket board in ZEsarUX on P2, P2A41 and P341. Optical performance for the new stages still needs a real Magnum and CRT.
