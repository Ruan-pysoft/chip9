package chip9

import "core:fmt"
import "core:os"
import "core:strconv"

rom_registry := [?]struct { name: string, setup: Rom_Setup_Proc, rom: [1<<16]u16 } {
	{ "Commandline fibonacci number calculator", fib_rom_setup_proc, fibonacci_calculator_rom },
	{ "Graphics device test", nil, pixel_test_rom },
}

Rom_Setup_Proc :: #type proc(rom: ^[1<<16]u16)

fib_rom_setup_proc :: proc(rom: ^[1<<16]u16) {
	n: u8
	for {
		fmt.print("n? > ")

		line, lerr := read_line()
		if lerr == .EOF {
			fmt.printfln("\nNo user input given, quitting program.")
			os.exit(0)
		}
		if lerr != nil do fmt.panicf("error reading line: {}", lerr)
		defer delete(line)

		n_uint, ok := strconv.parse_uint(line)
		if !ok {
			fmt.printfln("Please enter a single positive integer.")
			continue
		} else if n_uint >= 256 {
			fmt.printfln("Please enter an integer between 0 and 255.")
			continue
		} else {
			n = u8(n_uint)
			break
		}
	}

	rom[0] |= u16(n)
}

fibonacci_calculator_rom :: [1<<16]u16 {
	0x000 = 0x1000 /*| u16(n)*/, // V0 = %n
	0x001 = 0x0031, // switch screen off
	0x002 = 0x8100, // CALL $100 (fib)
	0x003 = 0x0000, // HALT

	// proc fib(V0)
	// clobbers V1, V2
	// returns via V0
	0x100 = 0x1100, // V1 = 0
	0x101 = 0x1201, // V2 = 1

	// while V0 > 0
	0x102 = 0xB00C, // SKIP IF V0 > 0
	0x103 = 0x4005, // JMP PC+5

	// --V0
	0x104 = 0x7FFF, // V0 = V0 - 1

	// V1, V2 = V2, V1 + V2
	0x105 = 0x6210, // V2 = V2 + V1
	0x106 = 0x6122, // V1 = V2 - V1

	// endwhile
	0x107 = 0x40FB, // JMP PC-5

	// return V1
	0x108 = 0x2010, // V0 = V1
	0x109 = 0x0010, // RET
}
pixel_test_rom :: [1<<16]u16 {
	0x000 = 0x1201, // V2 = $01
	0x001 = 0x8200, // CALL $200 (draw_pixel)
	0x002 = 0x1005, // V1 = $05
	0x003 = 0x8100, // CALL $100 (sleep)
	0x004 = 0x0000, // HALT

	// proc sleep(V0)
	// clobbers V0
	0x100 = 0x1F3C, // VF = $3C (60)
	0x101 = 0x60F3, // V0 = V0 * VF

	// while V0 > 0
	0x102 = 0xB00C, // SKIP IF V0 > 0
	0x103 = 0x4004, // JMP PC+4

	// --V0
	0x104 = 0x7FFF, // V0 = V0 - 1

	// suspend until the end of the frame
	0x105 = 0x00D4,

	// endwhile
	0x106 = 0x40FC, // JMP PC-4

	// return
	0x108 = 0x0010, // RET

	// proc draw_pixel(x=V0, y=V1, color=V2)
	0x200 = 0x0020, // PUSH V0
	0x201 = 0x0120, // PUSH V1
	0x202 = 0x0220, // PUSH V2

	// V0 = x + y*96
	0x203 = 0x1260, // V2 = $60
	0x204 = 0x6123, // V1 = V1 * V2
	0x205 = 0x6010, // V0 = V0 + V1

	// V1 = $8000
	0x206 = 0x1109, // V1 = $9
	0x207 = 0x2113, // V1 = [0x210]

	// screen[pos] = color
	0x208 = 0x0230, // POP V2
	0x209 = 0x3122, // [V0 + V1] = V2

	// restore V0 & V1
	0x20A = 0x0130, // POP V1
	0x20B = 0x0030, // POP V0

	0x20C = 0x0010, // RET

	0x210 = 0x8000, // video memory offset

	// return
	0x20F = 0x0010,

	0x8000 = 0xFFFF,
	0x8060 = 0xFFFF,
	0x80C0 = 0xFFFF,
	0x8001 = 0xF000,
	0x8061 = 0xF000,
	0x80C1 = 0xF000,
	0x8002 = 0x0F00,
	0x8062 = 0x0F00,
	0x80C2 = 0x0F00,
	0x8003 = 0x00F0,
	0x8063 = 0x00F0,
	0x80C3 = 0x00F0,
	0x8004 = 0x000F,
	0x8064 = 0x000F,
	0x80C4 = 0x000F,
	0x8005 = 0xAAAB,
	0x8065 = 0xAAAB,
	0x80C5 = 0xAAAB,
	0x8006 = 0xF801,
	0x8066 = 0xF801,
	0x80C6 = 0xF801,
	0x8007 = 0x07C1,
	0x8067 = 0x07C1,
	0x80C7 = 0x07C1,
	0x8008 = 0x003F,
	0x8068 = 0x003F,
	0x80C8 = 0x003F,
}
