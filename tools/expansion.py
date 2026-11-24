"""Expansion stages, gameplay rules and rack layout."""
from scenery_plates import draw_plate

WORLDS = [
    ("Harbour", [
        ("LIGHTHOUSE RUN", 3),
        ("TUGBOAT BAY", 4),
        ("ANCHOR WATCH", 8),
        ("SAIL LOFT", 7),
        ("CRANE SIGNAL", 6),
        ("DRY DOCK", 14),
    ]),
    ("Orchard", [
        ("HONEY HOUSE", 12),
        ("WINDMILL ROW", 11),
        ("CIDER PRESS", 4),
        ("APPLE CART", 7),
        ("WATERING TIME", 10),
        ("SILO SUNSET", 9),
    ]),
    ("Polar", [
        ("ICEBREAKER", 4),
        ("IGLOO ECHO", 3),
        ("AURORA DISH", 11),
        ("GLACIER PASS", 14),
        ("SNOW GOGGLES", 10),
        ("WALRUS WHARF", 6),
    ]),
    ("Spaceport", [
        ("LUNAR LANDER", 8),
        ("ORBITAL ARRAY", 5),
        ("ROCKET GANTRY", 14),
        ("RING STATION", 10),
        ("MARS ROVER", 7),
        ("COMET TRAIL", 9),
    ]),
    ("Citadel", [
        ("DRAWBRIDGE", 8),
        ("CROWN VAULT", 15),
        ("DRAGON ROOST", 4),
        ("JOUST RELAY", 3),
        ("TOWER KEY", 12),
        ("MOON GRIMOIRE", 13),
    ]),
    ("Wild west", [
        ("MESA EXPRESS", 11),
        ("CACTUS GULCH", 6),
        ("SPUR AND SADDLE", 7),
        ("SILVER MINE", 14),
        ("SHERIFF STAR", 9),
        ("WAGON WHEEL", 10),
    ]),
    ("Undersea", [
        ("NAUTILUS", 4),
        ("CORAL GARDEN", 5),
        ("PEARL DIVER", 12),
        ("OCTOPUS DEN", 3),
        ("MANTA GLIDE", 11),
        ("WRECK SIGNAL", 13),
    ]),
    ("Workshop", [
        ("STEAM HAMMER", 4),
        ("VALVE PUZZLE", 5),
        ("GEAR SHIFT", 7),
        ("COPPER COILS", 10),
        ("PRESSURE TEST", 8),
        ("FINAL FOUNDRY", 14),
    ]),
]
LEVELS = [level for _, levels in WORLDS for level in levels]


def layout(index):
    # Each tour stop changes the rack layout on its four vertical lanes.
    return [8*(3+8*((n+index//4+(index%4)*lane)%4))
            for lane,n in enumerate((2,0,3,1))]


def expansion_scene(scene,index):
    title,_ = LEVELS[index]
    return draw_plate(scene,title)
