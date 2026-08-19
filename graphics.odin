package chip9

import "core:fmt"
import "core:thread"

import "vendor:sdl3"

#assert(thread.IS_SUPPORTED)

SCREEN_WIDTH  :: 384
SCREEN_HEIGHT :: 256

Color :: bit_field u16 {
	a: bool | 1,
	b: u8 | 5,
	g: u8 | 5,
	r: u8 | 5,
}

Sprite :: [16][16]Color

Sprite_Set :: [16]Sprite

Packed_Indices :: bit_field u16 {
	i0: u8 | 4,
	i1: u8 | 4,
	i2: u8 | 4,
	i3: u8 | 4,
}

get_index_single :: #force_inline proc(indices: Packed_Indices, i: int) -> u8 {
	assert(0 <= i && i < 4)
	switch i {
	case 0: return indices.i0
	case 1: return indices.i1
	case 2: return indices.i2
	case 3: return indices.i3
	case: panic("unreachable")
	}
}
get_index_multi :: #force_inline proc(indices: [$N]Packed_Indices, i: int) -> u8 {
	return get_index_single(indices[i/4], i%4)
}
get_index :: proc { get_index_single, get_index_multi }

Sprite_Index_Screen :: [SCREEN_HEIGHT/16][SCREEN_WIDTH/16/4]Packed_Indices

Graphics_Mode :: enum {
	Pixel = 0,
	Sprite = 1,
	IndexedPixel = 2,
	IndexedSprite = 3,
}
Graphics_Chip :: struct {
	window: ^sdl3.Window,

	screen_on: bool,
	mode: Graphics_Mode,

	screen_draw_thread: ^thread.Thread,
	screen_colours: [SCREEN_WIDTH][SCREEN_HEIGHT]Color,

	pixels: [SCREEN_HEIGHT/4][SCREEN_WIDTH/4]Color,

	sprites_bg_sprites: Sprite_Set,
	sprites_fg_sprites: Sprite_Set,
	sprites_bg: Sprite_Index_Screen,
	sprites_fg: Sprite_Index_Screen,
}

@(private="file")
_pixels_to_raw_words :: proc($num_words: int, pixels: ^[$H][$W]Color) -> (raw: ^[num_words]u16) {
	#assert(size_of(pixels^) == size_of(raw^))
	return transmute(^[num_words]u16)pixels
}

@(private="file")
_draw_pixel :: proc(graphics: ^Graphics_Chip, x: int, y: int, color: Color) #no_bounds_check {
	if graphics.screen_colours[y][x] == color do return
	graphics.screen_colours[y][x] = color

	full_color := [3]int {
		int(color.r), int(color.g), int(color.b),
	} * 255 / 31
	full_alpha := 255 if color.a else 0

	#unroll for sub_y in 0..<2 {
		abs_y := y*2 + sub_y
		#unroll for sub_x in 0..<2 {
			abs_x := x*2 + sub_x
			abs_pos := abs_y*SCREEN_WIDTH*2 + abs_x

			sdl3.WriteSurfacePixel(
				sdl3.GetWindowSurface(graphics.window),
				i32(abs_x), i32(abs_y),
				sdl3.Uint8(full_color.r),
				sdl3.Uint8(full_color.g),
				sdl3.Uint8(full_color.b),
				sdl3.Uint8(full_alpha),
			)
		}
	}
}

graphics_device_proc :: proc(ptr: rawptr, register: ^u16, command_nibble: u8) {
	graphics := cast(^Graphics_Chip) ptr

	invalid :: #force_inline proc(command: u8, loc := #caller_location) -> ! {
		fmt.panicf("Invalid graphics chip command %02X", command)
	}

	switch command_nibble {
	case 0: register^ = u16(graphics.mode)
	case 1: graphics.mode = Graphics_Mode(register^)
	case 2:
		if graphics.screen_on do register^ = ~u16(0)
		else do register^ = 0
	case 3: graphics.screen_on = register^ != 0
	case: invalid(command_nibble)
	}
}

graphics_as_device :: proc(graphics: ^Graphics_Chip) -> Device {
	return Device {
		device_proc = graphics_device_proc,
		data = graphics,
	}
}

graphics_draw :: proc(graphics: ^Graphics_Chip, chip9: ^Chip9) {
	if !graphics.screen_on {
		sdl3.HideWindow(graphics.window)
		return
	}
	defer sdl3.ShowWindow(graphics.window)

	if graphics.mode != .Pixel do fmt.panicf("Graphics mode {} is not implemented yet!", graphics.mode)

	if graphics.screen_draw_thread != nil {
		//before := time.tick_now()
		thread.join(graphics.screen_draw_thread)
		//dur := time.tick_diff(before, time.tick_now())
		//fmt.println(time.duration_milliseconds(dur))
	}
	copy_slice(
		_pixels_to_raw_words(6144, &graphics.pixels)[:],
		chip9.cpu.memory[0x8000:0x9800]
	)
	graphics.screen_draw_thread = thread.create_and_start_with_poly_data(graphics, graphics_draw_pixels)
}

graphics_draw_pixels :: proc(graphics: ^Graphics_Chip) {
	for pixel_row, y in graphics.pixels {
		for pixel, x in pixel_row {
			#unroll for sub_y in 0..<4 {
				abs_y := y*4 + sub_y
				#unroll for sub_x in 0..<4 {
					abs_x := x*4 + sub_x
					_draw_pixel(graphics, abs_x, abs_y, pixel)
				}
			}
		}
	}

	sdl3.UpdateWindowSurface(graphics.window)
}

@(init)
init_sdl :: proc "contextless" () {
	assert_contextless(sdl3.Init({ .VIDEO }))
}

@(fini)
fini_sdl :: proc "contextless" () {
	sdl3.Quit()
}

init_graphics :: proc(graphics: ^Graphics_Chip) {
	graphics^ = {}

	graphics.window = sdl3.CreateWindow("CHIP9", 768, 512, { .TRANSPARENT, .HIDDEN })
	assert(graphics.window != nil)
	graphics.screen_on = true
}

destroy_graphics :: proc(graphics: ^Graphics_Chip) {
	if graphics.screen_draw_thread != nil do thread.terminate(graphics.screen_draw_thread, 0)
	sdl3.DestroyWindow(graphics.window)
}
