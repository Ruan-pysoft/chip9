package chip9

import "core:fmt"
import "core:io"
import "core:os"
import "core:strconv"
import "core:strings"

main :: proc() {
	init_stdin()

	cpu := make_cpu()

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
