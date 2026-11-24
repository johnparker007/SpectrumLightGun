"""Native Spectrum artwork for the wooden challenge board and its enamel signs."""


def briefing_screen():
    screen = bytearray(6912)

    def tile(col, row, attr, pattern):
        screen[6144 + row * 32 + col] = attr
        address = (row // 8) * 2048 + (row % 8) * 32 + col
        for line, bits in enumerate(pattern):
            screen[address + line * 256] = bits

    # Recessed timber slats, staggered grain, and brass studs on the side rails.
    for row in range(3, 24):
        for col in range(32):
            if col in (0, 31):
                pattern = [0x24, 0x34, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24]
                if row % 6 == 3:
                    pattern[2:6] = [0x3c, 0x76, 0x66, 0x3c]
            else:
                pattern = [0xff, 0xff, 0xaa, 0, 0, 0, 0, 0]
                if (col + row * 3) % 7 < 2:
                    pattern[4] = 0x3e if col % 2 else 0x81
            tile(col, row, 6 if col in (0, 31) else 2, pattern)

    def panel(x, y, w, h, colour, bright=True):
        # Each edge cell uses black ink on coloured paper. Carve the outer
        # silhouette and an inset bevel directly into the Spectrum bitmap.
        for row in range(h):
            for col in range(w):
                pattern = []
                for py in range(8):
                    v = row * 8 + py
                    dy = min(v, h * 8 - 1 - v)
                    cut = (6, 4, 2, 2, 1, 1)[dy] if dy < 6 else 0
                    bits = 0
                    for px in range(8):
                        u = col * 8 + px
                        dx = min(u, w * 8 - 1 - u)
                        border = dx < cut
                        shadow = v == h * 8 - 3 or u == w * 8 - 3
                        lip = v == 3 and 6 <= u < w * 8 - 6
                        bits = bits * 2 + int(border or shadow or lip)
                    pattern.append(bits)
                tile(x + col, y + row, colour * 8 + 64 * bright, pattern)
        # Specular streaks on the top lip and down the left shoulder.
        for col in range(1, min(w - 1, 5)):
            tile(x + col, y, colour * 8 + 7 + 64 * bright,
                 [0, 0xff, 0xff if col < 3 else 0, 0, 0, 0, 0, 0])

    panel(1, 4, 30, 5, 7, False)
    panel(1, 10, 14, 9, 2)
    panel(17, 10, 14, 9, 3)
    panel(4, 20, 24, 3, 1)
    return screen



def briefing_figures(font):
    """Pack 24x24 glyphs row-by-row within each character band for the Z80."""
    figures = bytearray()
    for letter in "0123456789NO":
        offset = (ord(letter) - 32) * 8
        for row in font[offset:offset + 8]:
            pixels = "".join(bit * 3 for bit in f"{row:08b}")
            figures.extend(int(pixels, 2).to_bytes(3, "big") * 3)
    return figures
