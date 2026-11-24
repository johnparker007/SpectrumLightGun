"""Summarise transcribed instrument readings (target coordinates decimal, HUD hex)."""
import argparse
import csv
from collections import defaultdict
from statistics import median

CORNERS = ((32, 32), (224, 160))
CENTRE = (128, 96)
PAIR = ((108, 96), (148, 96))


def read_log(stream):
    groups = defaultdict(list)
    for line, row in enumerate(csv.DictReader(stream), 2):
        try:
            target = (int(row["target_x"]), int(row["target_y"]))
            mode = row["mode"].strip().lower()
            phase = int(row["phase"], 16)
            state = row["status"].strip()
            if mode not in ("direct", "pre", "sweep") or state not in ("E", "H", "-", "B"):
                raise ValueError("unknown mode or status")
            if not (0 <= target[0] < 256 and 0 <= target[1] < 192 and 0 <= phase < 16):
                raise ValueError("target or phase out of range")
            pos = None
            if state == "E":
                pos = (int(row["x"], 16), int(row["y"], 16))
                if not (0 <= pos[0] < 256 and 0 <= pos[1] < 192):
                    raise ValueError("reading outside picture")
            black = int(row["black"], 16) if mode == "pre" else None
            if black is not None and not 0 <= black <= 1920:
                raise ValueError("black high count outside 0..1920")
        except (KeyError, ValueError) as error:
            raise ValueError(f"CSV line {line}: {error}") from error
        groups[mode, target, phase].append((state, pos, black))
    return groups


def report(groups):
    points = {}
    for (mode, target, phase), rows in sorted(groups.items()):
        positions = [p for _, p, _ in rows if p]
        counts = {s: sum(state == s for state, _, _ in rows) for s in ("-", "H", "B")}
        prefix = f"{mode} {target} phase {phase:X}: {len(positions)}/{len(rows)} edges"
        print(f"{prefix}, misses {counts['-']}, already high {counts['H']}, border {counts['B']}")
        if mode == "pre":
            print(f"  black active in {sum(bool(b) for _, _, b in rows)}/{len(rows)} frames")
        if positions:
            axes = list(zip(*positions))
            mid = tuple(median(a) for a in axes)
            bounds = [f"{min(a)}..{max(a)}" for a in axes]
            print(f"  median {mid}, X {bounds[0]}, Y {bounds[1]} pixels")
            if phase == 0:
                points[mode, target] = positions
        if target in PAIR:
            correct = sum((x < 128) == (target == PAIR[0]) for x, _ in positions)
            print(f"  raw side correct {correct}/{len(rows)} attempts, "
                  f"{len(positions)-correct} on the other side")
    for mode in ("direct", "pre"):
        corners = [points.get((mode, t), []) for t in CORNERS]
        if min(map(len, corners)) < 3:
            continue
        offsets = [tuple(t[i]-median(p[i] for p in hits) for i in range(2))
                   for t, hits in zip(CORNERS, corners)]
        dx, dy = (round(median(axis)) for axis in zip(*offsets))
        print(f"{mode} corner offsets {offsets}; offset-only build: --offset-x {dx} --offset-y {dy}")
        centre = points.get((mode, CENTRE), [])
        if centre:
            residuals = [(x+dx-CENTRE[0], y+dy-CENTRE[1]) for x, y in centre]
            print("  held-out centre median error", tuple(median(a) for a in zip(*residuals)),
                  "pixels (unclipped)")
        else:
            print("  centre check pending")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=argparse.FileType("r"))
    args = parser.parse_args()
    report(read_log(args.csv))
