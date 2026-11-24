"""Expansion scenery. Each landmark is drawn on a 16 by 16 design grid.
Polygons are painted back to front; coordinates are hexadecimal x,y pairs.
"""

# Title, gameplay rule, landmark layers. Digits 1..4 index the world's inks.
WORLDS = [
    ("Harbour", (1,5,7,6), [
        ("LIGHTHOUSE RUN",3,"1:4f5cbcacbf 3:5b63a3ab 2:5968a8a9 4:5260a0b2 3:5362a2b3"),
        ("TUGBOAT BAY",4,"1:0a3af8dc4e 2:38368a98b8ba 3:62648183 4:64639193"),
        ("ANCHOR WATCH",8,"2:7173a392 3:747b9b94 2:4969a9c8bd8f5e2b19 4:344597a7a546"),
        ("SAIL LOFT",7,"1:0cbbeacd4e 3:737b1b 2:858aaa 4:71818979"),
        ("CRANE SIGNAL",6,"2:2e4e4a9aa8b8 1:404b6b62 4:4060e3e451 3:dadccdcb"),
        ("DRY DOCK",14,"1:1b3af9dd4e 2:3a4887a8baba 4:57549798 3:5c9cab6d")]),
    ("Orchard", (4,2,6,5), [
        ("HONEY HOUSE",12,"1:1fdfff 3:4c3a386674a4c6d9cbdc 2:393adac9 2:5b5cccbc 1:8789a9a7"),
        ("WINDMILL ROW",11,"2:4e64a4ce 3:77676a79 4:76011066 4:87c1e297 4:98eecec8 4:797d3e2c"),
        ("CIDER PRESS",4,"2:1e1dcdce 1:323c4c42 1:b2bcddc2 3:2241c1d3 4:72778782 2:5868a8b9bcca4c"),
        ("APPLE CART",7,"2:1858e7c96949 3:3a4bcbda 1:4c5b6c5d 1:acbbccbd 4:55647485 2:8695a5b7"),
        ("WATERING TIME",10,"1:4867b6caac5d 4:b6d4f5e8c9 3:482421173a5b 2:5c9baa6d"),
        ("SILO SUNSET",9,"1:2e255298ae 2:254292a5 3:254595a5 4:67779787 1:aeabd9ebee")]),
    ("Polar", (1,5,7,3), [
        ("ICEBREAKER",4,"1:0a5ac8f7cbbd4d 2:4654a4b8 3:62528183 4:64749484"),
        ("IGLOO ECHO",3,"2:1d2a4756a6c8eafe 3:2a3857a7c9 1:4868b8c9 1:5b79a9bcbd5d"),
        ("AURORA DISH",11,"2:1849a57444 3:193a7a9857 1:7987aecd5e 4:72738381"),
        ("GLACIER PASS",14,"1:0e24685298aec7fe 2:24685158976a 3:5268516886 2:9caac8d9eabc"),
        ("SNOW GOGGLES",10,"1:1443b3e4d99585794929 2:2545a5d6c89685794939 4:3655865948 3:a6c6b8a8"),
        ("WALRUS WHARF",6,"1:0d2a374696a4b4c6d8f9ec9e 2:34438294a7c8da9b 3:97a7a998 3:b8c8bca9")]),
    ("Spaceport", (1,3,5,7), [
        ("LUNAR LANDER",8,"1:4774a4c7899b6b 2:557593a4b7 3:67659898 4:5a3e1e49 4:9abaeece"),
        ("ORBITAL ARRAY",5,"2:0744aadc 3:0845aadc 1:355183a5 4:637192a384 1:95b5d8b9 3:7987b89a"),
        ("ROCKET GANTRY",14,"1:3e3132626ebc 3:8c8855a0c4cbab 2:9996c6c9 4:8b9b8e"),
        ("RING STATION",10,"1:1754b4e7e9cb5c28 3:2855a5d7c9a97449 1:4756a6b78768 2:75738799"),
        ("MARS ROVER",7,"1:274794d7e9ba5b29 3:53648485 2:62628383 4:2b3a4b3d 4:6c7b8c7e 4:abbbccbd"),
        ("COMET TRAIL",9,"1:1b6795e2c69abbbd7e4e 2:2b69a6c5a8899a6c 4:3c4a6a8c7d5e")]),
    ("Citadel", (1,3,6,7), [
        ("DRAWBRIDGE",8,"1:1e151443537574a3b4d3e4ee 2:252647a6b5d6 3:5d586798acbd 1:6d6978a9ad"),
        ("CROWN VAULT",15,"3:295b554674a4b8e4cc5c 2:3a5cbbca 4:67658588"),
        ("DRAGON ROOST",4,"1:1c4565549482a0b3e4d6b7997a5d 2:4957657496a68789 3:c5e6c6 4:a4b4b5"),
        ("JOUST RELAY",3,"1:4e4956899698ba9c 3:463568a7b869 2:698a9b6c 4:1d2cdaeb"),
        ("TOWER KEY",12,"3:18364667864a5c3c 1:294747583a 2:5969dbebdccdacca 4:9bacbcbb"),
        ("MOON GRIMOIRE",13,"1:154374a3d4eead8e5d2d 3:2544758b8d5c3b 2:8594c5dcaa8c 4:47758768")]),
    ("Wild west", (2,6,1,7), [
        ("MESA EXPRESS",11,"3:0a1888c7d8eabd4c 1:2734566888 2:a4c4c8a8 4:3c4b5c4d 4:9cabcbad"),
        ("CACTUS GULCH",6,"1:6574949e6e 2:294949476748694b3b 3:9498b8b5d5da9b"),
        ("SPUR AND SADDLE",7,"1:2836576979b8c5d6dccd8d5b 2:39576989b8c7bb9b 3:686b8b89"),
        ("SILVER MINE",14,"3:1e1432c2e4eececa96664ace 2:1432c2e4d533 1:5e6876a7bbbe 4:3c4b5c4d"),
        ("SHERIFF STAR",9,"2:707495d5b898aaad899b594b56533264 3:647393a6a9977667 4:75748687"),
        ("WAGON WHEEL",10,"1:1742a1d4e9bc6e3c 2:2843a2c4d9bc6d4b 3:4763a3b5b9aaba795a49 1:586494a6a8977869")]),
    ("Undersea", (1,5,3,6), [
        ("NAUTILUS",4,"1:194573a3c4e7da9c6c3a 2:284664a4c6b9986a 3:687594a6987877 4:68788a6a"),
        ("CORAL GARDEN",5,"2:5e69584453466579769793a3a8c7d5e6d9aaaaae 3:3a294736485a 4:9290a0a3"),
        ("PEARL DIVER",12,"2:1a365493c4d6e89c6d 1:2a4554a4c6d8b9a8 3:3b5a7aa9cacc9e6e 4:686779898a6a"),
        ("OCTOPUS DEN",3,"3:284562a2b4c7c9eafbda9b8979695c3d4a2b1a 2:455494b5b847 4:57677767 4:97a7a897"),
        ("MANTA GLIDE",11,"2:0927557393c4e5f79788abcd8a685948 3:2746648494c5e6b6 1:8999bdbe"),
        ("WRECK SIGNAL",13,"1:0c3cbbf8dc9e5e 2:4974a5b9 3:63738979 4:97b6c8a9")]),
    ("Workshop", (1,6,5,2), [
        ("STEAM HAMMER",4,"1:2e2232b2c49a6a6e 2:32339993 3:7478a8a4 4:5868b8b959"),
        ("VALVE PUZZLE",5,"3:1a3889a7d7e9cbaaaa4c2b 2:656286959968 4:554593a475"),
        ("GEAR SHIFT",7,"1:4e4b5a9aaaac8e 2:6879b4a3 3:9391b0d2c4a5 4:a2b1c2b3"),
        ("COPPER COILS",10,"1:1c1957878ac9d7e9ec 2:354374a5b7a9896947 1:465484958798 4:35437494"),
        ("PRESSURE TEST",8,"2:2542a2d5d9ab5b28 3:3543a3c5c8aa5a38 1:4544a4b6b89a5968 4:7866a578"),
        ("FINAL FOUNDRY",14,"1:1e1937a6c8dbde 2:3c4966a7bbbc 4:5b697888a9aabb6c 3:2e3dcdde")])
]

LEVELS = [(title,rule) for _,_,group in WORLDS for title,rule,_ in group]


def stamp(scene, layers, palette, x, y, scale):
    """Scan convert original polygon artwork, including horizontal edges."""
    for layer in layers.split():
        ink, path = layer.split(":")
        pts = [(x+round(scale*int(path[i],16)), y+round(scale*int(path[i+1],16)))
               for i in range(0,len(path),2)]
        colour = palette[int(ink)-1]
        for row in range(min(b for a,b in pts),max(b for a,b in pts)+1):
            cuts = []
            for (ax,ay),(bx,by) in zip(pts,pts[1:]+pts[:1]):
                if min(ay,by)<=row<max(ay,by):
                    cuts.append(ax+(row-ay)*(bx-ax)/(by-ay))
            cuts.sort()
            for l,r in zip(cuts[::2],cuts[1::2]):
                scene.line(round(l),row,round(r),row,colour)
        for a,b in zip(pts,pts[1:]+pts[:1]):
            scene.line(*a,*b,colour)
def layout(index):
    # Each tour stop changes the rack layout on its four vertical lanes.
    return [8*(3+8*((n+index//4+(index%4)*lane)%4))
            for lane,n in enumerate((2,0,3,1))]


def expansion_scene(scene, index):
    world, variant = divmod(index,6)
    _,palette,group = WORLDS[world]
    _,rule,layers = group[variant]
    xs = layout(index)
    ys = [32,72,112,152]
    low, mid, light, glint = palette
    vista(scene,world,variant,palette)
    # Silhouettes at the foot of each world anchor the screen. Repeatable
    # tile-sized structures keep the NIRVANA atlas small.
    for x in range(-8,256,24):
        if world==0:
            scene.line(x,175,x+9,175,mid)
            scene.line(x+10,176,x+18,176,low)
            scene.line(x+19,175,x+23,173,mid)
            scene.line(x+3,181,x+11,181,low)
        elif world==1:
            scene.line(x,175,x,181,mid)
            scene.line(x-8,179,x+15,176,low)
            scene.line(x+5,181,x+9,176,low)
        elif world==2:
            scene.line(x,181,x+8,169,mid)
            scene.line(x+8,169,x+19,180,low)
            scene.line(x+8,170,x+7,176,light)
        elif world==3:
            scene.outline(x,174,23,7,low)
            scene.box(x+3,176,6,2,mid)
            scene.line(x+15,176,x+20,176,light)
        elif world==4:
            scene.outline(x,175,24,8,low)
            scene.box(x,172,6,4,mid)
            scene.box(x+12,172,6,4,mid)
        elif world==5:
            scene.line(x,181,x+7,177,low)
            scene.line(x+7,177,x+15,178,mid)
            scene.line(x+15,178,x+21,174,low)
        elif world==6:
            for dx,h in ((2,6),(6,10),(10,4)):
                scene.line(x+6,181,x+dx,181-h,mid)
                scene.dot(x+dx-1,181-h,light)
        else:
            scene.box(x,174,24,3,low)
            scene.outline(x+4,178,13,4,mid)
            scene.dot(x+7,180,light)
    # Compose the landmark beside the firing lanes. Mobile levels put it
    # entirely between lanes to avoid clipping it during opaque sprite erases.
    mobile = rule in (7,9,11,13)
    lane = (1,2,0,1,2,1)[variant]
    if mobile:
        x,y,scale=(60,49,1) if variant%2 else (171,89,1)
        stamp(scene,layers,palette,x,y,1.4)
    else:
        x=154 if xs[lane]<104 else 38
        y=ys[lane]-12
        stamp(scene,layers,palette,x,y,3)
    # Each rack sits on a fixture built for its setting.
    for i,(x,y) in enumerate(zip(xs,ys)):
        y+=17
        if world in (0,1):
            scene.box(x-5,y,26,2,mid)
            for post in (x-3,x+17): scene.box(post,y+2,2,5,low)
        elif world in (2,5):
            scene.line(x-8,y+3,x+1,y,light)
            scene.line(x+1,y,x+19,y,mid)
            scene.line(x+19,y,x+24,y+4,low)
        elif world in (3,7):
            scene.outline(x-4,y,24,5,low)
            scene.line(x,y+2,x+9,y+2,mid)
            scene.dot(x+16,y+2,glint)
        else:
            scene.line(x-5,y,x+20,y,mid)
            scene.line(x-3,y+1,x+1,y+5,low)
            scene.line(x+18,y+1,x+14,y+5,low)
    # A lintel unique to each world with the small emblem inset.
    stamp(scene,layers,palette,8+variant*36,10,1)
    for x in range(0,256,16):
        scene.line(x,8,x+12,8,low)
        if world in (0,3,7): scene.dot(x+13,10,mid)
    for x,y in zip(xs,ys):
        cols={x//8}
        if rule in (7,13): cols.update((3,11,19,27))
        if rule in (9,11): cols.update(range(4,28))
        for col in cols: scene.box(8*col,y,16,16,0)
    return scene
def vista(s, world, variant, inks):
    """A middle-distance skyline and a foreground silhouette for each setting."""
    dark, accent, light, hot = inks
    horizon = (69,109,149)[variant%3]
    shift = 8*(variant%3)
    for x in range(-32+shift,256,32):
        if world==0:                       # stepped gables and dockside windows
            h=10 if (x-shift)%64 else 16
            s.box(x+2,horizon-h,25,h,dark)
            for j in range(4): s.box(x+4+2*j,horizon-h-2*j,21-4*j,2,dark)
            for dx in (6,13,20):
                s.box(x+dx,horizon-7,3,4,accent)
            s.line(x,horizon+2,x+18,horizon+2,accent)
            s.line(x+6,horizon+5,x+14,horizon+5,dark)
        elif world==1:                     # alternating espalier and apple trees
            for cy,r in ((-9,6),(-14,6),(-10,8)):
                cx=x+14+(cy%4)*2
                for dy in range(-r,r+1):
                    w=int((r*r-dy*dy)**.5)
                    s.line(cx-w,horizon+cy+dy,cx+w,horizon+cy+dy,dark)
            s.box(x+16,horizon-5,3,8,accent)
            for dx,dy in ((10,-13),(18,-18),(21,-9)):
                s.box(x+dx,horizon+dy,2,2,accent)
            s.line(x,horizon+3,x+30,horizon+3,dark)
        elif world==2:                     # asymmetric slopes with snow and facets
            peak=horizon-14-(8 if (x-shift)%64 else 0)
            for dx in range(32):
                ridge=peak+abs(dx-10)*(horizon-peak)//(10 if dx<=10 else 21)
                s.line(x+dx,ridge,x+dx,horizon,dark)
                if dx<14: s.dot(x+dx,ridge,light)
                if 9<dx<18: s.line(x+dx,ridge+1,x+dx,ridge+4,accent)
            s.line(x+6,horizon+3,x+19,horizon+3,accent)
        elif world==3:                     # spaceport pressure locks, ducts and antennae
            s.outline(x,horizon-9,32,11,dark)
            s.box(x+3,horizon-8,15,7,dark)
            for dx in (5,9,13): s.line(x+dx,horizon-7,x+dx,horizon-4,accent)
            s.outline(x+22,horizon-6,6,7,accent)
            s.line(x+16,horizon-10,x+16,horizon-18,dark)
            s.dot(x+16,horizon-19,hot)
            s.line(x+3,horizon+5,x+27,horizon+5,dark)
        elif world==4:                     # curtain wall, arrow slits and conical roofs
            s.box(x,horizon-6,32,8,dark)
            s.box(x+7,horizon-17,11,19,dark)
            for dy in range(7):
                s.line(x+12-dy,horizon-23+dy,x+12+dy,horizon-23+dy,accent)
            s.line(x+12,horizon-12,x+12,horizon-8,light)
            for dx in (1,20,26): s.box(x+dx,horizon-9,3,3,dark)
            s.line(x+1,horizon+3,x+27,horizon+3,dark)
        elif world==5:                     # layered sandstone buttes
            for dx in range(32):
                h=(3,4,6,14,17,17,18,16,9,8,6,5,5,3,3,3)[dx//2]
                s.line(x+dx,horizon-h,x+dx,horizon,dark)
                if 8<=dx<14:s.dot(x+dx,horizon-h,accent)
            s.line(x+7,horizon-7,x+15,horizon-7,accent)
            s.line(x+17,horizon+4,x+25,horizon+4,dark)
        elif world==6:                     # branching sea fans, bubbles and sand ripples
            for side in (-1,1):
                for h in (5,10,15):
                    s.line(x+16,horizon-h+4,x+16+side*6,horizon-h,dark)
                    s.line(x+16+side*6,horizon-h,x+16+side*8,horizon-h-5,accent)
            s.line(x+16,horizon,x+16,horizon-20,dark)
            s.circle(x+3,horizon-13,2,dark)
            s.line(x+2,horizon+2,x+11,horizon+2,dark)
        else:                              # shop-floor belt with bolted pipe flanges
            s.box(x,horizon-6,32,4,dark)
            s.outline(x+3,horizon-8,5,8,accent)
            s.line(x+10,horizon-5,x+26,horizon-5,accent)
            s.outline(x+13,horizon-19,7,12,dark)
            for k in (0,4): s.line(x+13,horizon-17+k,x+19,horizon-17+k,hot)
            s.line(x,horizon+3,x+31,horizon+3,dark)
