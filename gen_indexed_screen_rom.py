from aseprite_reader import AsepriteFile
from aseprite_reader import utils
from aseprite_reader.chunks import CelChunk, ColorProfileChunk, LayerChunk, PaletteChunk

import itertools

## PREPARE THE IMAGE

file = AsepriteFile("./indexed_screen.aseprite")

assert file.header.colors == 16
assert file.header.width == 192
assert file.header.height == 128
assert file.header.frame_count == 1

assert len(file.layers) == 1

color_profile: ColorProfileChunk = None
color_palette: PaletteChunk = None
layer: LayerChunk = None
cel: CelChunk = None

for chunk in file.frames[0].chunks:
    print(chunk)
    if isinstance(chunk, CelChunk):
        cel = chunk
    if isinstance(chunk, ColorProfileChunk):
        color_profile = chunk
    if isinstance(chunk, LayerChunk):
        layer = chunk
    if isinstance(chunk, PaletteChunk):
        color_palette = chunk

assert color_profile.profile_type == 1 # sRGB

assert color_palette.palette_size == 16

assert layer.layer_type == 0 # normal

assert cel.cel_type == 2 # image cel

image_indices: tuple[int] = utils.decompress_image_data(cel.compressed_image_data)
packed_image_indices = list((a<<12)|(b<<8)|(c<<4)|d for (a, b, c, d) in itertools.batched(image_indices, 4))

image_colors: list[int] = []
for color in color_palette.palette_colors:
    # 0 to 255
    r, g, b, a = color.r, color.g, color.b, color.a
    # convert to 0 to 31 for rgb and 0 or 1 for alpha
    r, g, b, a = r//8, g//8, b//8, a//128
    word = (r<<11)|(g<<6)|(b<<1)|a
    image_colors.append(word)

## PREPARE THE PROGRAM

main_code = [
    # set graphics mode to indexed pixel
    0x1002,
    0x0011,

    # start while loop
    0x2000,

    # sleep for 1 second
    0x1001,
    0x8100,

    # rotate palette
    0x8200,

    # loop forever
    0x40FC,

    # halt
    0x0000,
]

sleep_proc = [
    0x1F3C,
    0x60F3,

    0xB00C,
    0x4004,

    0x7FFF,

    0x00D4,

    0x40FC,

    0x0010,
]

rotate_palette_proc = [
    # V0  = $9800
    0x1098,
    0x1F10,
    0x6FF3,
    0x60F3,

    0x1100,
    0x2412,

    0x1100,
    0x1201,
    0x2322,
    0x3132,

    0x1101,
    0x1202,
    0x2322,
    0x3132,

    0x1102,
    0x1203,
    0x2322,
    0x3132,

    0x1103,
    0x1204,
    0x2322,
    0x3132,

    0x1104,
    0x1205,
    0x2322,
    0x3132,

    0x1105,
    0x1206,
    0x2322,
    0x3132,

    0x1106,
    0x1207,
    0x2322,
    0x3132,

    0x1107,
    0x1208,
    0x2322,
    0x3132,

    0x1108,
    0x1209,
    0x2322,
    0x3132,

    0x1109,
    0x120A,
    0x2322,
    0x3132,

    0x110A,
    0x120B,
    0x2322,
    0x3132,

    0x110B,
    0x120C,
    0x2322,
    0x3132,

    0x110C,
    0x120D,
    0x2322,
    0x3132,

    0x110D,
    0x120E,
    0x2322,
    0x3132,

    0x110E,
    0x120F,
    0x2322,
    0x3132,

    0x110F,
    0x3142,

    # return
    0x0010,
]

## PREPARE ROM

rom: list[int] = [0]*65536

for i, word in enumerate(main_code):
    rom[i] = word

for i, word in enumerate(sleep_proc):
    rom[0x100 + i] = word

for i, word in enumerate(rotate_palette_proc):
    rom[0x200 + i] = word

for i, word in enumerate(packed_image_indices):
    rom[0x8000 + i] = word

for i, word in enumerate(image_colors):
    rom[0x9800 + i] = word

## WRITE ROM

with open("indexed_screen_rom.bin", "wb") as f:
    # I believe numbers should be store least-significant-bit-first for Odin?

    for word in rom:
        f.write(bytes([word&0xFF, word>>8]))
