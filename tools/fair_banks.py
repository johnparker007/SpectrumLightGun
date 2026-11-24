"""Build the expansion directory, staging loader and emulator bank images."""
import struct
from expansion import LEVELS, layout

BANKS = (1, 4, 6)


def make_bank(scenes):
    directory = bytearray()
    offset = 4*len(scenes)
    for scene in scenes:
        directory.extend(struct.pack("<HH", 0xc000+offset, len(scene)))
        offset += len(scene)
    if offset>16384:
        raise ValueError(f"Scenery bank needs {offset} bytes")
    return bytes(directory)+b"".join(scenes)


def make_tables(work):
    lines=["extra_titles:"]
    lines.append("    dw "+",".join(f"extra_title_{i}" for i in range(len(LEVELS))))
    for i,(title,rule) in enumerate(LEVELS):
        assert len(title)<=15
        lines.append(f'extra_title_{i}: db "{title}",0')
    lines.append("extra_rules: db "+",".join(str(rule) for title,rule in LEVELS))
    # Gate and memory rounds need time for all four lanes. Higher tours
    # shorten the clock while leaving a fresh trigger opportunity per lane.
    limits=[]
    for i,(_,rule) in enumerate(LEVELS):
        base={4:18,6:18,8:16,9:10,10:12,11:16,12:14,13:18,14:11,15:15}.get(rule,16)
        limits.append(base-i//18-i%3)
    lines.append("extra_limits: db "+",".join(map(str,limits)))
    lines.append("extra_columns:")
    for i in range(len(LEVELS)):
        lines.append("    db "+",".join(str(x//8) for x in layout(i)))
    (work/"extra.inc").write_text("\n".join(lines))


def bank_loader(banks, tape_file):
    # USR routines at 0x7000, below CLEAR. Copy each exact length with
    # interrupts off and restore BASIC's top bank/ROM before returning.
    routines=bytearray()
    commands=[b'\xfd\xb0"28671"', b'\xef""\xaf']
    files=bytearray()
    for bank,data in zip(BANKS,banks,strict=True):
        addr=28672+len(routines)
        routines+=bytes.fromhex("f3 01 fd 7f 3a 5c 5b f5 e6 f8 f6")+bytes([bank])
        routines+=bytes.fromhex("ed 79 21 00 80 11 00 c0 01")+struct.pack("<H",len(data))
        routines+=bytes.fromhex("ed b0 f1 01 fd 7f ed 79 fb c9")
        commands.extend([b'\xef""\xaf',b'\xf9\xc0\xb0"'+str(addr).encode()+b'"'])
        files+=tape_file(3,f"SCENERY {bank}".encode(),data,32768,32768)
    commands.extend([b'\xef""\xaf',b'\xf9\xc0\xb0"32768"'])
    # Separate BASIC lines keep the ROM interpreter's edit buffer small.
    basic=bytearray()
    for i,command in enumerate(commands,1):
        line=command+b"\r"
        basic+=struct.pack(">H",10*i)+struct.pack("<H",len(line))+line
    return tape_file(0,b"RASTERFAIR",basic,10,len(basic))+tape_file(3,b"BANK COPY",routines,28672,28672)+files


def emulator_files(tape,work):
    """Extract the real TAP blocks for MAME's direct memory loader."""
    blocks=[]
    while tape:
        n,=struct.unpack_from("<H",tape)
        block,tape=tape[2:2+n],tape[2+n:]
        checksum=0
        for b in block: checksum^=b
        assert len(block)==n and checksum==0
        blocks.append(block[:-1])
    assert len(blocks)==12
    for i,bank in enumerate(BANKS):
        header,data=blocks[4+2*i:6+2*i]
        assert header[2:12].rstrip()==f"SCENERY {bank}".encode()
        assert data[0]==255 and len(data)-1==int.from_bytes(header[12:14],"little")
        (work/f"bank{bank}.bin").write_bytes(data[1:])
    return blocks[-1][1:]
