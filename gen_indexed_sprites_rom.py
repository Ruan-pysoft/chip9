from aseprite_reader import AsepriteFile
from aseprite_reader import utils
from aseprite_reader.chunks import CelChunk, ColorProfileChunk, LayerChunk, PaletteChunk

import itertools

def spritesheet_to_words(filename: str) -> list[int]:
    file = AsepriteFile(filename)

    assert file.header.colors <= 16
    assert file.header.width == 64
    assert file.header.height == 64
    assert file.header.frame_count == 1

    assert len(file.layers) == 1

    color_profile: ColorProfileChunk = None
    color_palette: PaletteChunk = None
    layer: LayerChunk = None
    cel: CelChunk = None

    for chunk in file.frames[0].chunks:
        if isinstance(chunk, CelChunk):
            cel = chunk
        if isinstance(chunk, ColorProfileChunk):
            color_profile = chunk
        if isinstance(chunk, LayerChunk):
            layer = chunk
        if isinstance(chunk, PaletteChunk):
            color_palette = chunk

    assert color_profile.profile_type == 1 # sRGB

    #assert color_palette.palette_size <= 16

    assert layer.layer_type == 0 # normal

    assert cel.cel_type == 2 # image cel

    color_indices: tuple[int] = utils.decompress_image_data(cel.compressed_image_data)
    color_indices = list(color_indices) + [0]*(4096-len(color_indices))
    packed_color_indices = list((a<<12)|(b<<8)|(c<<4)|d for (a, b, c, d) in itertools.batched(color_indices, 4))

    return packed_color_indices

layer1_sprites = spritesheet_to_words("./layer1_spriteset.aseprite")
layer2_sprites = spritesheet_to_words("./layer2_spriteset.aseprite")
layer3_sprites = spritesheet_to_words("./layer3_spriteset.aseprite")
layer4_sprites = spritesheet_to_words("./layer4_spriteset.aseprite")

screen1_layer1_colors = [
    0x0000, 0x0001, 0xFFFF, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,
]
assert len(screen1_layer1_colors) == 16
screen1_layer2_colors = [
    0x0000, 0x0001, 0xC043, 0xC557,
    0xB491, 0x2903, 0x3069, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,
]
assert len(screen1_layer2_colors) == 16
screen1_layer3_colors = [
    0x0000, 0xF2F5, 0x1BC3, 0xEFC1,
    0x94A5, 0x6319, 0x5AD7, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,
]
assert len(screen1_layer3_colors) == 16
screen1_layer4_colors = [
    0xFF81, 0x210D, 0x414F, 0x61CD,
    0xDB89, 0xDD19, 0x9F15, 0x6DCD,
    0x4B4B, 0x349B, 0x3321, 0x5B79,
    0x64FF, 0x5E79, 0xCEFF, 0xFFFF,
]
assert len(screen1_layer4_colors) == 16

screen2_layer1 = screen1_layer1_colors
screen2_layer2 = screen1_layer2_colors
screen2_layer3 = screen1_layer3_colors
screen2_layer4 = screen1_layer4_colors

screen3_layer1 = screen1_layer1_colors
screen3_layer2 = screen1_layer2_colors
screen3_layer3 = screen1_layer3_colors
screen3_layer4 = screen1_layer4_colors

screen4_layer1 = screen1_layer1_colors
screen4_layer2 = screen1_layer2_colors
screen4_layer3 = screen1_layer3_colors
screen4_layer4 = screen1_layer4_colors

## CREATE SCREEN

hex = '0123456789ABCDEF'

screen1_layer1 = [hex.index(c) for c in ''.join('''
000000000000000000000000
010000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
'''.strip().splitlines())]
screen1_layer2 = [hex.index(c) for c in ''.join('''
000000000000000000000000
000100000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
'''.strip().splitlines())]
screen1_layer3 = [hex.index(c) for c in ''.join('''
000000000000000000000000
000100000000000100000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000001000001000000
000001000000000000000000
000000000000000000000000
000000000000000000000000
000000010000000001000000
000000000000000000000000
000000000100000000000000
000000000000000000000000
000000000000000001000000
000010000000000000000000
022222222222222222222220
'''.strip().splitlines())]
screen1_layer4 = [hex.index(c) for c in ''.join('''
88888889A8888889A8888B89
006222100000000000000000
003125000000000000000000
003003000000000000000000
007224000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
000000000000000000000000
'''.strip().splitlines())]

def pack_layer(layer: list[int]) -> list[int]:
    return [(a<<12)|(b<<8)|(c<<4)|d for (a, b, c, d) in itertools.batched(layer, 4)]

screen_selectors = ['1234'.index(c) for c in ''.join('''
111111111111111111111111
111111111111111111111111
111111111111111111111111
111111111111111111111111
111111111111111111111111
111111111111111111111111
111111111111111111111111
111111111111111111111111
111111111111111111111111
111111111111111111111111
111111111111111111111111
111111111111111111111111
111111111111111111111111
111111111111111111111111
111111111111111111111111
111111111111111111111111
'''.strip().splitlines())]

packed_screen_selectors = [(a<<14)|(b<<12)|(c<<10)|(d<<8)|(e<<6)|(f<<4)|(g<<2)|h for (a, b, c, d, e, f, g, h) in itertools.batched(screen_selectors, 8)]
assert len(packed_screen_selectors) == 48

## PREPARE THE PROGRAM

main_code = [
    # set graphics mode to indexed sprite
    0x1003,
    0x0011,

    # sleep for 5 second
    0x1005,
    0x8100,

    # start while loop
    0x2000,

    # rotate palette
    0x8200,

    # sleep for 1 second
    0x1001,
    0x8100,

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

#for i, word in enumerate(rotate_palette_proc):
    #rom[0x200 + i] = word

for i, word in enumerate(layer1_sprites + layer2_sprites + layer3_sprites + layer4_sprites):
    rom[0x8000 + i] = word

for i, word in enumerate(pack_layer(screen1_layer1) + pack_layer(screen1_layer2) + pack_layer(screen1_layer3) + pack_layer(screen1_layer4)):
    rom[0x9000 + i] = word
# skip screens 2 through 4 for now...

for i, word in enumerate(screen1_layer1_colors + screen1_layer2_colors + screen1_layer3_colors + screen1_layer4_colors):
    rom[0x9600 + i] = word
# skip screens 2 through 4 for now...

for i, word in enumerate(packed_screen_selectors):
    rom[0x9700 + i] = word

## WRITE ROM

with open("indexed_sprites_rom.bin", "wb") as f:
    # I believe numbers should be store least-significant-bit-first for Odin?

    for word in rom:
        f.write(bytes([word&0xFF, word>>8]))
