package chip9

import "core:fmt"
import "core:slice"
import "core:strconv"

main :: proc() {
	init_stdin()

	chip9: Chip9
	init_chip9(&chip9)

	n: u8
	for {
		fmt.print("n? > ")

		line, lerr := read_line()
		if lerr == .EOF {
			fmt.printfln("\nNo user input given, quitting program.")
			return
		}
		if lerr != nil do fmt.panicf("error reading line: {}", lerr)
		defer delete(line)

		n_uint, ok := strconv.parse_uint(line)
		if !ok {
			fmt.printfln("Please enter a single positive integer.")
			continue
		} else if n_uint >= 256 {
			fmt.printfln("Please enter an integer between 0 and 255.")
			continue } else { n = u8(n_uint)
			break
		}
	}

	program := [?]u16 {
		0x000 = 0x1000 | u16(n), // V0 = %n
		0x001 = 0x8100, // CALL $100 (fib)
		0x002 = 0x0000, // HALT

		// proc fib(V0)
		// uses: V1, V2, VF
		0x100 = 0x1100, // V1 = 0
		0x101 = 0x1201, // V2 = 1

		// while V0 > 0
		0x102 = 0xB00C, // SKIP IF V0 > 0
		0x103 = 0x400B, // JMP PC+11

		// --V0
		0x104 = 0x7FFF, // V0 = V0 - 1

		// V1, V2 = V2, V1 + V2
		0x105 = 0x6210, // V2 = V2 + V1
		0x106 = 0x6122, // V1 = V2 - V1

		0x107 = 0x00D4, // suspend until the end of the frame
		0x108 = 0x00D4, // suspend until the end of the frame
		0x109 = 0x00D4, // suspend until the end of the frame
		0x10A = 0x00D4, // suspend until the end of the frame
		0x10B = 0x00D4, // suspend until the end of the frame
		0x10C = 0x00D4, // suspend until the end of the frame

		// endwhile
		0x10D = 0x40F5, // JMP PC-11

		// return V1
		0x10E = 0x2010, // V0 = V1
		0x10F = 0x0010, // RET
	}

	{
		fmt.println()
		fmt.println("PROGRAM:")

		fmt.println("      ...0 ...1 ...2 ...3 ...4 ...5 ...6 ...7  ...8 ...9 ...A ...B ...C ...D ...E ...F")
		prev_skipped := false
		empty_row: [16]u16
		last_row := 0
		for row in 0..<(1<<12) {
			if (row+1)*16 > len(program) do break
			last_row = row+1

			if slice.simple_equal(program[row*16:(row+1)*16], empty_row[:]) {
				if !prev_skipped do fmt.println("      ***************************************  ***************************************")
				prev_skipped = true
				continue
			}

			fmt.printf("%03X. ", row)
			for col in 0..<16 {
				if col == 8 do fmt.print(" ")
				fmt.printf(" %04X", program[row*16 + col])
			}
			fmt.println()
		}
		disp_last_row: if last_row*16 < len(program) {
			row_len := len(program) - last_row*16

			if slice.simple_equal(program[last_row*16:], empty_row[:row_len]) {
				if !prev_skipped do fmt.println("      ****")
				prev_skipped = true
				break disp_last_row
			}

			fmt.printf("%03X. ", last_row)
			for col in 0..<row_len {
				if col == 8 do fmt.print(" ")
				fmt.printf(" %04X", program[last_row*16 + col])
			}
			for col in row_len..<16 {
				if col == 8 do fmt.print(" ")
				fmt.print(" 0000")
			}
			fmt.println()
		}

		fmt.println()
	}

	load_rom(&chip9, program[:])

	fmt.println("ROM LOADED")
	fmt.printfln("  V0=%04X", chip9.cpu.registers[.V0])

	i := 0
	fmt.printfln("pc=%04X [pc]=%04X", chip9.cpu.pc, chip9.cpu.memory[chip9.cpu.pc])
	for clock_tick(&chip9.clock, &chip9) {
		fmt.printfln("  i=%03d V0=%04X", i, chip9.cpu.registers[.V0])
		when ODIN_DEBUG do fmt.printfln("  Registers: {}", transmute([16]u16) chip9.cpu.registers)
		i += 1
		fmt.printfln("pc=%04X [pc]=%04X", chip9.cpu.pc, chip9.cpu.memory[chip9.cpu.pc])
	}

	fmt.println("CPU HALTED")

	fmt.printfln("  i=%03d V0=%04X=%d", i, chip9.cpu.registers[.V0], chip9.cpu.registers[.V0])

	fmt.println()
	fmt.printfln("The %dth fibonacci number was calculated to be %d", n, chip9.cpu.registers[.V0])
}
