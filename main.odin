package chip9

import "core:fmt"
import "core:io"
import "core:os"
import "core:strconv"
import "core:strings"

main :: proc() {
	init_stdin()

	cpu: Cpu

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
		// a, b, n, one := 0, 1, 10, 1
		0  = 0x1000, // V0 = 0
		1  = 0x1101, // V1 = 1
		2  = 0x1200 | u16(n), // V2 = %n
		3  = 0x1301, // V3 = 1

		// while --n >= 0
		4  = 0x6231, // V2 = V2 - V3 // V2 -= 1
		5  = 0xB20D, // SKIP IF V2 >= 0
		6  = 0x4005, // JMP PC+5

		7  = 0x2400, // V4 = V0
		8  = 0x2010, // V0 = V1
		9  = 0x6140, // V1 = V1 + V4

		// endwhile
		10 = 0x40FA, // JMP PC-6

		11 = 0,
	}

	{
		fmt.println()
		fmt.println("PROGRAM:")
		col := 0
		for instr in program {
			if col != 0 do fmt.print(" ")
			fmt.printf("%04X", instr)
			col += 1
			if col == 8 {
				fmt.println()
				col = 0
			}
		}
		if col != 0 do fmt.println()
		fmt.println()
	}

	load_rom(&cpu, program[:])

	fmt.println("ROM LOADED")
	fmt.printfln("  V0=%04X", cpu.registers[.V0])

	i := 0
	fmt.printfln("pc=%04X [pc]=%04X", cpu.pc, cpu.memory[cpu.pc])
	for cycle(&cpu) {
		fmt.printfln("  i=%03d V0=%04X", i, cpu.registers[.V0])
		when ODIN_DEBUG do fmt.printfln("  Registers: {}", transmute([16]u16) cpu.registers)
		i += 1
		fmt.printfln("pc=%04X [pc]=%04X", cpu.pc, cpu.memory[cpu.pc])

		if i == 100 do break
	}

	fmt.println("CPU HALTED")

	fmt.printfln("  i=%03d V0=%04X=%d", i, cpu.registers[.V0], cpu.registers[.V0])

	fmt.println()
	fmt.printfln("The %dth fibonacci number was calculated to be %d", n, cpu.registers[.V0])
}

read_line :: proc(file := stdin, allocator := context.allocator) -> (line: string, err: io.Error) {
	builder := strings.builder_make(allocator=allocator)
	defer if err != nil do strings.builder_destroy(&builder)

	for {
		c: u8
		n := io.read(file, (transmute(^[1]u8)&c)[:]) or_return

		if n == 0 do break
		if c == '\n' do break
		strings.write_byte(&builder, c)
	}

	return strings.to_string(builder), nil
}

stdin: io.Reader
init_stdin :: proc() { stdin = os.to_reader(os.stdin) }
