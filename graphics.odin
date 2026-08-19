package chip9

import "core:fmt"
import "core:thread"

import "vendor:sdl3"

#assert(thread.IS_SUPPORTED)

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
	pixels_memory: [6144]u16,
	old_pixels_memory: [6144]u16,
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
	graphics.old_pixels_memory = graphics.pixels_memory
	copy_slice(graphics.pixels_memory[:], chip9.cpu.memory[0x8000:0x9800])
	graphics.screen_draw_thread = thread.create_and_start_with_poly_data(graphics, graphics_draw_pixels)
}

graphics_draw_pixels :: proc(graphics: ^Graphics_Chip) {
	for sprite_y in 0..<(512/8) {
		for sprite_x in 0..<(768/8) {
			pos := sprite_y*(768/8) + sprite_x
			color_raw := graphics.pixels_memory[pos]
			if color_raw == graphics.old_pixels_memory[pos] do continue
			color := [4]u8 {
				u8((color_raw&0b1111_1000_0000_0000)>>11),
				u8((color_raw&0b0000_0111_1100_0000)>>6 ),
				u8((color_raw&0b0000_0000_0011_1110)>>1 ),
				u8( color_raw&0b0000_0000_0000_0001     ),
			}
			color_float := [3]f32 {
				f32(color.r)/31,
				f32(color.g)/31,
				f32(color.b)/31,
			}

			for pixel_y in 0..<8 {
				for pixel_x in 0..<8 {
					abs_x := sprite_x*8 + pixel_x
					abs_y := sprite_y*8 + pixel_y

					r := sdl3.Uint8(color_float.r * 255)
					g := sdl3.Uint8(color_float.g * 255)
					b := sdl3.Uint8(color_float.b * 255)
					a := sdl3.Uint8(color      .a * 255) // cursed spacing, lol

					sdl3.WriteSurfacePixel(
						sdl3.GetWindowSurface(graphics.window),
						i32(abs_x), i32(abs_y),
						r, g, b, a,
					)
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
