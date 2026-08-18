package chip9

import "core:fmt"

import "vendor:sdl3"

Graphics_Mode :: enum {
}
Graphics_Chip :: struct {
	window: ^sdl3.Window
}

graphics_device_proc :: proc(ptr: rawptr, register: ^u16, command_nibble: u8) {
	graphics := cast(^Graphics_Chip) ptr

	invalid :: #force_inline proc(command: u8, loc := #caller_location) -> ! {
		fmt.panicf("Invalid graphics chip command %02X", command)
	}

	switch command_nibble {
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
	GRAPHICS_OFFSET := 0x8000

	for sprite_y in 0..<(768/8) {
		for sprite_x in 0..<(512/8) {
			pos := sprite_y*(512/8) + sprite_x
			color_raw := chip9.cpu.memory[GRAPHICS_OFFSET + pos]
			color := [3]u8 {
				u8((color_raw&0b1111_1000_0000_0000)>>11),
				u8((color_raw&0b0000_0111_1100_0000)>>6 ),
				u8( color_raw&0b0000_0000_0011_1111     ),
			}
			color_float := [3]f32 {
				f32(color.r)/31,
				f32(color.g)/31,
				f32(color.b)/63,
			}

			for pixel_y in 0..<8 {
				for pixel_x in 0..<8 {
					abs_x := sprite_x*8 + pixel_x
					abs_y := sprite_y*8 + pixel_y

					r := sdl3.Uint8(color_float.r * 255)
					g := sdl3.Uint8(color_float.g * 255)
					b := sdl3.Uint8(color_float.b * 255)

					sdl3.WriteSurfacePixel(
						sdl3.GetWindowSurface(graphics.window),
						i32(abs_y), i32(abs_x),
						r, g, b, 255,
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

	graphics.window = sdl3.CreateWindow("CHIP9", 768, 512, { .TRANSPARENT })
	assert(graphics.window != nil)
	fmt.eprintln(graphics.window)
	fmt.eprintln(sdl3.ShowWindow(graphics.window))

	sdl3.GetWindowSurface(graphics.window)
	sdl3.UpdateWindowSurface(graphics.window)
}

destroy_graphics :: proc(graphics: ^Graphics_Chip) {
	sdl3.DestroyWindow(graphics.window)
}
