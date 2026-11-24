"""Fourteen shooting-gallery sets. Coordinates are visible Spectrum pixels."""
import math


def polygon(s, points, colour):
    for a,b in zip(points,points[1:]+points[:1]):
        s.line(*a,*b,colour)


def gear(s,x,y,r):
    points=[]
    for i in range(32):
        a=i*math.tau/32
        k=r if i%4 in (1,2) else r-3
        points.append((round(x+k*math.cos(a)),round(y+k*math.sin(a))))
    polygon(s,points,5)
    s.circle(x,y,r//2,1)
    s.circle(x,y,2,6)


def gallery(s,stage):
    xs=[152,24,216,152]
    ys=[32,72,112,152]
    if stage==0:   # Carnival stall: scalloped awning and individual can plinths
        for x in range(0,256,16):
            s.box(x,10,15,6,2 if x%32 else 6)
            for i in range(6):
                s.line(x+i,16+i,x+15-i,16+i,3 if x%32 else 6)
        for x in (3,250):
            for y in range(22,174,8):
                s.line(x,y,x+3,y+4,2)
                s.line(x+3,y+4,x+3,y+7,6)
        for x,y in zip(xs,ys):
            s.box(x-18,y+16,52,3,6)
            polygon(s,[(x-14,y+20),(x+28,y+20),(x+21,y+26),(x-6,y+26)],3)
    elif stage==3: # Clock tower, linked chain descending between bell stations
        for x,y in zip(xs,ys):
            s.circle(x+8,y+8,17,6)
            s.line(x+8,y-14,x+8,y-9,5)
        for (x,y),(xx,yy) in zip(zip(xs,ys),zip(xs[1:],ys[1:])):
            for i in range(2,13):
                cx=round(x+8+(xx-x)*i/14); cy=round(y+8+(yy-y)*i/14)
                s.outline(cx-3,cy-1,7,4,5 if i%2 else 1)
        gear(s,61,145,18); gear(s,90,131,15)
    elif stage==4: # Armoured train in a foundry
        for x,y in zip(xs,ys):
            polygon(s,[(x-32,y-3),(x-23,y-8),(x+32,y-8),(x+41,y),(x+41,y+19),(x-32,y+19)],5)
            for k in (-18,0,19): s.circle(x+k,y+23,4,1)
            for k in range(-22,34,9): s.dot(x+k,y-5,6)
            s.line(max(0,x-43),y+28,min(255,x+50),y+28,1)
        for x in (72,90,103):
            s.outline(x,113,7,53,1);s.box(x-1,112,9,3,2)
        s.line(63,168,125,168,2)
    elif stage==5: # Switchboard with circuit traces and sockets
        for i,(x,y) in enumerate(zip(xs,ys)):
            s.outline(x-4,y-4,24,24,5)
            bus=85+8*i
            s.line(bus,20,bus,y+8,1);s.line(bus,y+8,x-5,y+8,5)
            s.circle(bus,18,3,6)
            for dx in range(3,18,6): s.line(x+dx,y+21,x+dx,y+25,6)
        for x in (6,243):
            for y in (15,172): s.circle(x,y,3,1)
    elif stage==6: # Four bell-tower arches, steps and slate roofs
        for x,y in zip(xs,ys):
            polygon(s,[(x-12,y-2),(x+8,y-19),(x+28,y-2)],3)
            s.line(x-8,y,x-8,y+16,5);s.line(x+23,y,x+23,y+16,5)
            for k in range(3): s.line(x-12-k*2,y+17+2*k,x+26+k*2,y+17+2*k,1)
            # Slate courses widen towards the eaves. A finial and the exposed
            # bell rope give the tower a silhouette even when its bell is down.
            for depth in (4,8,12):
                span=depth+1
                s.line(x+8-span,y-18+depth,x+8+span,y-18+depth,1)
            s.line(x+8,y-22,x+8,y-19,6)
            s.box(x-12,y-2,40,2,3)
            for pier in (x-9,x+22):
                s.box(pier,y,3,16,1)
                for offset in (2,8,14): s.line(pier,y+offset,pier+2,y+offset,5)
            s.line(x+19,y+1,x+19,y+12,6)
            s.circle(x+19,y+14,2,6)
        # Roofline below the towers, with chimneys and lit attic windows.
        for x,h in ((0,10),(22,15),(46,9),(72,13),(98,11),(197,12),(223,16)):
            peak=176-h
            polygon(s,[(x,176),(x+10,peak),(x+21,176)],1)
            s.box(x+15,peak+1,3,7,1)
            s.box(x+9,peak+6,3,3,6)
        for x in range(0,256,16): s.outline(x,178,15,4,1)
    elif stage==7: # Cups and ball table with felt rails and inlaid diamonds
        for y in ys:
            s.box(0,y+17,256,3,4);s.line(0,y+22,255,y+22,1)
            for x in range(8,250,32): polygon(s,[(x,y+19),(x+3,y+22),(x,y+25),(x-3,y+22)],6)
        for x in (2,250): s.line(x,11,x,176,4)
        for i in range(4): s.circle(106+12*i,17,4,3 if i%2 else 6)
    elif stage==8: # Castle gatehouses with portcullises and battlements
        for x,y in zip(xs,ys):
            s.outline(x-14,y-6,44,26,1)
            for k in range(-14,30,8): s.outline(x+k,y-11,5,6,5)
            for k in (-11,-6,21,26): s.line(x+k,y-4,x+k,y+17,5)
            s.line(x-13,y+18,x+29,y+18,6)
        for x in range(0,256,16): s.outline(x,176,16,6,1)
    elif stage==9: # Observatory: distant constellations and a telescope
        for x,y in [(13,24),(37,32),(57,19),(78,26),(191,42),(208,29),(231,36)]:
            s.line(x-2,y,x+2,y,6);s.line(x,y-2,x,y+2,5)
        for x,y,xx,yy in [(13,24,37,32),(37,32,57,19),(57,19,78,26),(191,42,208,29),(208,29,231,36)]: s.line(x,y,xx,yy,1)
        polygon(s,[(15,151),(45,133),(51,141),(20,159)],5)
        for x in (9,32,49): s.line(29,153,x,177,6)
        # Keep the complete ring system between the reserved actor rows.
        cx,cy=202,58
        for dy in range(-8,9):
            width=math.isqrt(64-dy*dy)
            s.line(cx-width,cy+dy,cx+width,cy+dy,3 if dy in (-5,-4,2,3) else 1)
        polygon(s,[(183,66),(191,60),(218,51),(221,51),(214,57),(186,67)],5)
        # Low observatory dome on the horizon, with a two-piece shutter.
        for dy in range(16):
            width=math.isqrt(15*15-(15-dy)**2)
            s.line(230-width,128+dy,230+width,128+dy,1)
        s.line(230,129,220,143,5)
        s.line(234,131,225,143,5)
        s.box(213,144,34,2,5)
        s.outline(216,146,28,6,1)
        for dx in (219,226,233): s.box(dx,148,3,2,6)
        s.line(246,151,255,156,1)
        for x,y in ((9,65),(68,96),(110,52),(156,94),(246,29),(80,140),(138,164)):
            s.dot(x,y,5)
            s.dot(x+1,y,1)
    elif stage==10: # Hall of mirrors: paired gilt frames, bevels, glints
        for i,(x,y) in enumerate(zip(xs,ys)):
            for pad,c in [(5,6 if i in (0,3) else 5),(8,1)]:
                s.outline(x-pad,y-pad,16+2*pad,16+2*pad,c)
            for k in (3,6,9): s.line(x-4,y+k,x+k,y-4,1)
        for x in (60,189):
            for y in range(16,172,16): polygon(s,[(x,y),(x+4,y+7),(x,y+14),(x-4,y+7)],3)
    elif stage==11: # Clockmaker's workshop: pivot rails, arc marks and gears
        for i,y in enumerate(ys):
            cx=(95,158)[i%2]
            s.line(cx-48,y-13,cx+48,y-13,1)
            s.circle(cx,y-12,4,6)
            for dx in range(-48,49,8): s.line(cx+dx,y+19,cx+dx,y+21+(dx%16==0)*2,5)
        gear(s,23,165,13);gear(s,46,153,10);gear(s,225,66,15)
    elif stage==12: # Mechanical slot cabinet with reel boxes and payout tray
        for x,y in zip(xs,ys):
            s.outline(x-11,y-8,38,33,3);s.outline(x-8,y-5,32,26,6)
            for k in (-6,1,8,15,22): s.dot(x+k,y-7,6)
        s.outline(80,19,41,19,6)
        for x in (84,96,108):
            s.line(x,23,x+7,23,3);s.line(x+7,23,x+2,32,3)
        s.line(236,122,245,99,5);s.circle(245,96,4,2)
        s.outline(65,170,70,8,1)
    elif stage==13: # Photographic darkroom: hanging clip line and film edges
        for x in (2,246):
            s.outline(x,12,8,167,1)
            for y in range(15,174,9): s.box(x+2,y,4,3,5)
        for y in ys:
            s.line(14,y-7,240,y-7,1)
            for x in (29,93,157,221):
                s.outline(x,y-11,4,8,6)
            s.line(16,y+18,239,y+18,1)
        s.box(104,12,46,3,2)
    elif stage==14: # Quarry powder charges and connected sparking fuse
        for i,(x,y) in enumerate(zip(xs,ys)):
            s.outline(x-8,y-3,32,22,2)
            for k in (-6,20): s.line(x+k,y-2,x+k,y+17,6)
            for dx in range(0,42):
                s.dot((x+22+dx)%256,y+12+round(3*math.sin(dx/6)),6)
        for x in range(0,256,24): polygon(s,[(x,180),(x+7,170),(x+16,173),(x+24,180)],1)
    elif stage==15: # Cashier window, brass trays, coin stacks and row values
        for i,(x,y) in enumerate(zip(xs,ys)):
            s.line(x-12,y+17,x+28,y+17,6)
            polygon(s,[(x-12,y+18),(x-8,y+23),(x+24,y+23),(x+28,y+18)],3)
            for k in range(i+1): s.outline(102+k*9,y+4,7,7,6)
        for x in (6,247): s.box(x,12,3,162,3)
        for x in range(65,145,12): s.outline(x,171,9,5,6)
    else:
        raise ValueError(stage)

    # The two screen bytes for each sprite are opaque. Reserve exactly the
    # reachable columns, including the initial position before the first tick.
    for x,y in zip(xs,ys):
        cols={x//8}
        if stage in (7,13): cols.update((3,11,19,27))
        if stage in (9,11): cols.update(range(4,28))
        for col in cols: s.box(col*8,y,16,16,0)
    return s
