"""Preview the compiled NIRVANA+ backdrops with standard Python."""
import argparse
import base64
import re
import struct
import tempfile
import zlib
from html import escape
from pathlib import Path

from fair_scenery import write_scenery
from expansion import LEVELS

ROOT = Path(__file__).resolve().parents[1]


def chunk(kind, data):
    return (struct.pack(">I", len(data)) + kind + data
            + struct.pack(">I", zlib.crc32(kind + data)))


def render(tiles):
    # The stage map starts below the eight-pixel HUD. Atlas records hold
    # eight bitmap rows, then one attribute for each pair of rows.
    rows = [bytearray(256) for _ in range(192)]
    for cell, index in enumerate(tiles[:704]):
        start = 704 + index * 12
        top = 8 + cell // 32 * 8
        left = cell % 32 * 8
        for dy, bits in enumerate(tiles[start:start+8]):
            attr = tiles[start+8+dy//2]
            bright = (attr >> 3) & 8
            ink, paper = bright | (attr & 7), bright | ((attr >> 3) & 7)
            for x in range(8):
                rows[top+dy][left+x] = ink if bits & (128 >> x) else paper
    palette = bytearray()
    for i in range(16):
        for mask in (2, 4, 1):
            palette.append((255 if i & 8 else 205) if i & mask else 0)
    header = struct.pack(">IIBBBBB", 256, 192, 8, 3, 0, 0, 0)
    data = b"".join(b"\0" + row for row in rows)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"PLTE", palette)
            + chunk(b"IDAT", zlib.compress(data)) + chunk(b"IEND", b""))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT/"build/scenery-preview.html")
    args = parser.parse_args()
    titles = dict(re.findall(r'^titles_(\d+): db "([^"]+)"', (ROOT/"src/fair_modes.asm").read_text(), re.M))
    titles.update({str(i):title for i,(title,rule) in enumerate(LEVELS,16)})
    with tempfile.TemporaryDirectory() as directory:
        scenes = write_scenery(Path(directory), ROOT)
    html = ['''<!doctype html><html lang="en"><meta charset="utf-8">
<title>Raster Fair scenery</title><style>
*{box-sizing:border-box}body{background:#141419;color:#eee;font:16px system-ui;margin:24px}
main{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,256px),1fr));gap:20px}
figure{margin:0}img{display:block;width:100%;image-rendering:pixelated}figcaption{margin:.4em 0}
dialog{background:#15151a;color:white;border:0;max-width:98vw}dialog img{width:min(768px,88vw)}
button{background:#272731;color:white;border:1px solid #777;padding:.4em;cursor:pointer}
figure button{padding:0;border:0;width:100%}dialog::backdrop{background:#000b}
</style><h1>Raster Fair scenery</h1><main>''']
    for i, tiles in enumerate(scenes):
        title = escape(titles[str(i)])
        src = base64.b64encode(render(tiles)).decode("ascii")
        html.append(f'<figure><button aria-label="Enlarge {title}"><img alt="{title}" src="data:image/png;base64,{src}"></button><figcaption>{i+1:02} · {title}</figcaption></figure>')
    html.append('''</main><dialog><form method="dialog"><button>Close</button></form>
<h2></h2><img alt=""></dialog><script>
const dialog=document.querySelector("dialog");
document.querySelectorAll("figure button").forEach(button=>button.onclick=()=>{
  const image=button.firstChild;
  dialog.querySelector("img").src=image.src;
  dialog.querySelector("h2").textContent=image.alt;
  dialog.showModal();
});
</script></html>''')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(html), encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
