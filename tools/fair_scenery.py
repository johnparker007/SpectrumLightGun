"""Compile the 64 fairground backdrops into 8x8 bitmap / 8x2 colour tiles."""
import math
from collections import Counter
from gallery_sets import gallery
from expansion import expansion_scene, LEVELS


class Scene:
    def __init__(self):
        self.pixels = [bytearray(256) for _ in range(192)]

    def dot(self, x, y, ink):
        if 0 <= x < 256 and 8 <= y < 184:
            self.pixels[y][x] = ink

    def line(self, x, y, xx, yy, ink):
        steps = max(abs(xx-x), abs(yy-y), 1)
        for i in range(steps+1):
            self.dot(round(x+(xx-x)*i/steps), round(y+(yy-y)*i/steps), ink)

    def box(self, x, y, w, h, ink):
        for row in range(y, y+h):
            self.line(x, row, x+w-1, row, ink)

    def outline(self, x, y, w, h, ink):
        self.line(x,y,x+w-1,y,ink)
        self.line(x,y+h-1,x+w-1,y+h-1,ink)
        self.line(x,y,x,y+h-1,ink)
        self.line(x+w-1,y,x+w-1,y+h-1,ink)

    def circle(self, x, y, r, ink):
        for degrees in range(360):
            a = math.radians(degrees)
            self.dot(x+round(r*math.cos(a)), y+round(r*math.sin(a)), ink)

    def tile(self, x, y):
        bitmap, palette = [], []
        for dy in range(0,8,2):
            pair = [self.pixels[y+dy+i][x:x+8] for i in (0,1)]
            colours = Counter(value for row in pair for value in row if value)
            palette.append(colours.most_common(1)[0][0] if colours else 0)
            for row in pair:
                bitmap.append(sum(128>>bit for bit,value in enumerate(row) if value))
        return bytes(bitmap+palette)


def powder_yard():
    s = Scene()
    # Four load-bearing shelves. Each can/bomb stands directly on its top lip.
    for y in (48,88,128,168):
        s.box(4,y,248,2,5)
        s.line(4,y+3,251,y+3,1)
        for x in range(8,250,16):
            s.line(x,y+2,x+5,y+2,1)
            s.line(x,y+4,x,y+7,1)
            s.line(x,y+7,x+4,y+4,1)
        # Recessed brick pilasters and shutter vents between loading bays.
        for x in (7,63,127,191,247):
            s.line(x,y-28,x,y-1,1)
            s.line(x+2,y-28,x+2,y-1,1)
            for dy in (-24,-12,-2):
                s.line(x-1,y+dy,x+3,y+dy,5)
        for x in (48,112,176):
            s.outline(x,y-23,11,10,1)
            for dy in (-21,-18,-15):
                s.line(x+2,y+dy,x+8,y+dy,1)
    # Overhead delivery rail, striped end stops and hanging enamel lamps.
    s.box(0,9,256,2,1)
    s.line(0,13,255,13,5)
    for x in range(4,256,16):
        s.line(x,10,x+3,13,5)
    for x in (32,96,160,224):
        s.line(x,14,x,18,5)
        for i in range(4):
            s.line(x-i-2,19+i,x+i+2,19+i,6)
        s.line(x-3,24,x+3,24,6)
    # Hazard-striped sill and inset rivets at the foot of the magazine.
    s.line(2,180,253,180,1)
    for x in range(4,252,12):
        for i in range(3):
            s.line(x+i,176,x+4+i,172,6)
    for row in (4,9,14,19):
        for col in (3,11,19,27):
            for dy in (0,8):
                for dx in (0,8):
                    assert not any(s.tile(8*col+dx,8*row+dy)), "occupied rack slot"
    return s


def midway(xs):
    s = Scene()
    # Distant clouds and a crescent above the midway.
    for x,y in ((6,30),(51,23),(83,46),(218,30),(134,12)):
        for dx,dy,w in ((0,3,20),(3,1,6),(8,0,7),(13,2,9)):
            s.line(x+dx,y+dy,x+dx+w,y+dy,1 if dy==3 else 5)
    for y in range(-7,8):
        for x in range(-7,8):
            if x*x+y*y<49 and (x-3)**2+(y+2)**2>32:
                s.dot(31+x,58+y,6)
    # A striped pavilion and pennant on the left bank.
    s.line(19,119,19,134,5)
    for i in range(4):
        s.line(20,119+i,28-2*i,119+i,3)
    for y in range(15):
        radius = (y+1)*19//15
        for dx in range(-radius,radius+1):
            stripe = (dx+radius)*5//(2*radius+1)
            if stripe%2==0 or y in (0,14):
                s.dot(19+dx,133+y,3 if y<13 else 6)
    for x in (2,9,29,36):
        s.line(x,148,x,172,5 if x in (2,36) else 1)
    s.box(2,163,35,3,3)
    for x in range(4,36,4):
        s.line(x,166,x,171,1)
    # Ferris wheel. Double rim, spokes, suspended gondolas and A-frame.
    cx,cy,r=207,121,29
    for side in (-1,1):
        s.line(cx,cy,cx+side*18,170,1)
        s.line(cx+side,cy,cx+side*15,170,5)
    s.line(191,166,222,166,1)
    for radius in (r-3,r):
        s.circle(cx,cy,radius,1 if radius<r else 5)
    for i in range(10):
        a=2*math.pi*i/10
        x,y=cx+round(r*math.cos(a)),cy+round(r*math.sin(a))
        s.line(cx,cy,x,y,1)
        s.line(x,y,x,y+3,5)
        s.outline(x-3,y+3,7,5,3 if i%2 else 6)
        s.line(x-2,y+8,x+2,y+8,3)
    s.circle(cx,cy,3,6)
    # Pier planks, railings and the waterline below the wrap point.
    for x in list(range(0,91,12))+list(range(150,256,12)):
        s.line(x,166,x,175,1)
    for a,b in ((0,91),(150,255)):
        s.line(a,168,b,168,5)
    s.box(0,176,256,2,5)
    for x in range(0,256,16):
        s.line(x,178,x+5,183,1)
        s.line(x+6,181,x+12,181,1)
    # Reject scenery in any 24x16 draw/erase footprint, including blank
    # padding in a shifted tile. The reserved pixels must stay black.
    for phase,x in enumerate(xs):
        y=16+2*phase
        col=x//8*8
        assert not any(any(row[col:col+24]) for row in s.pixels[y:y+16]), f"balloon path {phase}"
    return s


def compile_scene(scene):
    blank=bytes(12)
    ids={blank:0}
    atlas=bytearray(blank)
    grid=bytearray()
    for y in range(8,184,8):
        for x in range(0,256,8):
            tile=scene.tile(x,y)
            if tile not in ids:
                ids[tile]=len(ids)
                atlas.extend(tile)
            grid.append(ids[tile])
    return grid+atlas


def write_scenery(work, root):
    # Consume the actual wave path so art changes and motion stay compatible.
    path=(root/"src/parade.asm").read_text().split("parade_x:",1)[1].splitlines()[1]
    xs=[int(value) for value in path.split("db",1)[1].split(",")]
    scenes=[]
    for stage in range(16+len(LEVELS)):
        if stage==1:
            name,scene="yard",powder_yard()
        elif stage==2:
            name,scene="midway",midway(xs)
        elif stage>=16:
            name,scene=f"stage{stage:02}",expansion_scene(Scene(),stage-16)
        else:
            name,scene=f"stage{stage:02}",gallery(Scene(),stage)
        data=compile_scene(scene)
        (work/(name+".tiles")).write_bytes(data)
        scenes.append(data)
    return scenes

