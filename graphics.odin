package chip9

import "core:fmt"
import "core:mem"
import "core:thread"
import "core:sync"
import "core:sync/chan"

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

@(private="file")
Render_Command :: enum {
	Draw,
	Quit,
	HideWindow,
}
@(private="file")
Render_Frame :: struct {
	cmd: Render_Command,
	mode: Graphics_Mode,
}
@(private="file")
Render_Thread :: struct {
	window: ^sdl3.Window,
	surface: ^sdl3.Surface,

	thread: ^thread.Thread,
	memory_lock: sync.Mutex,

	screen_on: bool,
	mode: Graphics_Mode,

	screen_colours: [SCREEN_HEIGHT][SCREEN_WIDTH]Color,

	pixels: [SCREEN_HEIGHT/4][SCREEN_WIDTH/4]Color,

	sprites_bg_sprites: Sprite_Set,
	sprites_fg_sprites: Sprite_Set,
	sprites_bg: Sprite_Index_Screen,
	sprites_fg: Sprite_Index_Screen,
}
@(private="file")
render_thread: Render_Thread

Graphics_Mode :: enum {
	Pixel = 0,
	Sprite = 1,
	IndexedPixel = 2,
	IndexedSprite = 3,
}
Graphics_Chip :: struct {
	render_chan: chan.Chan(Render_Frame),

	screen_on: bool,
	mode: Graphics_Mode,
}

@(private="file")
_to_raw_words :: proc($num_words: int, pixels: ^[$H][$W]$T) -> (raw: ^[num_words]u16) {
	#assert(size_of(pixels^) == size_of(raw^))
	return transmute(^[num_words]u16)pixels
}

@(private="file")
_draw_pixel :: proc(ctx: ^Render_Thread, x: int, y: int, color: Color) #no_bounds_check {
	if ctx.screen_colours[y][x] == color do return
	ctx.screen_colours[y][x] = color

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
				ctx.surface,
				i32(abs_x), i32(abs_y),
				sdl3.Uint8(full_color.r),
				sdl3.Uint8(full_color.g),
				sdl3.Uint8(full_color.b),
				sdl3.Uint8(full_alpha),
			)
		}
	}
}

@(private="file")
render_thread_proc :: proc(c: chan.Chan(Render_Frame, .Recv)) {
	{
		sync.lock(&render_thread.memory_lock)
		defer sync.unlock(&render_thread.memory_lock)

		render_thread.window = sdl3.CreateWindow("CHIP9", SCREEN_WIDTH*2, SCREEN_HEIGHT*2, { .TRANSPARENT, .HIDDEN })
		assert(render_thread.window != nil)
		render_thread.surface = sdl3.GetWindowSurface(render_thread.window)
		assert(render_thread.surface != nil)
	}

	defer {
		sync.lock(&render_thread.memory_lock)
		defer sync.unlock(&render_thread.memory_lock)

		sdl3.DestroyWindow(render_thread.window)
	}

	render_loop: for {
		frame, ok := chan.recv(c)
		if !ok do break

		switch frame.cmd {
		case .Draw:
			defer sdl3.ShowWindow(render_thread.window)

			sync.lock(&render_thread.memory_lock)
			defer sync.unlock(&render_thread.memory_lock)

			switch frame.mode {
			case .Pixel: graphics_draw_pixels(&render_thread)
			case .Sprite: graphics_draw_sprites(&render_thread)
			case .IndexedPixel: graphics_draw_indexed_pixels(&render_thread)
			case .IndexedSprite: graphics_draw_indexed_sprites(&render_thread)
			case: graphics_draw_pixels(&render_thread)
			}
		case .Quit: break render_loop
		case .HideWindow: sdl3.HideWindow(render_thread.window)
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
		chan.send(graphics.render_chan, Render_Frame { cmd = .HideWindow })
		return
	}

	sync.lock(&render_thread.memory_lock)
	defer sync.unlock(&render_thread.memory_lock)

	#partial switch graphics.mode {
	case .Pixel:
		copy_slice(
			_to_raw_words(6144, &render_thread.pixels)[:],
			chip9.cpu.memory[0x8000:0x9800]
		)
	case: fmt.panicf("Graphics mode {} is not implemented yet!", graphics.mode)
	}
	chan.send(graphics.render_chan, Render_Frame { .Draw, graphics.mode })
}

graphics_draw_pixels :: proc(ctx: ^Render_Thread) {
	for pixel_row, y in ctx.pixels {
		for pixel, x in pixel_row {
			#unroll for sub_y in 0..<4 {
				abs_y := y*4 + sub_y
				#unroll for sub_x in 0..<4 {
					abs_x := x*4 + sub_x
					_draw_pixel(ctx, abs_x, abs_y, pixel)
				}
			}
		}
	}

	sdl3.UpdateWindowSurface(ctx.window)
}

graphics_draw_sprites :: proc(ctx: ^Render_Thread) {
	panic("TODO")
}

graphics_draw_indexed_pixels :: proc(ctx: ^Render_Thread) {
	panic("TODO")
}

graphics_draw_indexed_sprites :: proc(ctx: ^Render_Thread) {
	panic("TODO")
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
	assert(render_thread == {})

	graphics^ = {}

	err: mem.Allocator_Error
	graphics.render_chan, err = chan.create(chan.Chan(Render_Frame), context.allocator)
	assert(err == nil)

	render_thread.thread = thread.create_and_start_with_poly_data(
		chan.as_recv(graphics.render_chan),
		render_thread_proc,
	)

	graphics.screen_on = true
}

destroy_graphics :: proc(graphics: ^Graphics_Chip) {
	chan.send(graphics.render_chan, Render_Frame { cmd = .Quit })
	thread.join(render_thread.thread)

	chan.destroy(graphics.render_chan)
	thread.destroy(render_thread.thread)
}
