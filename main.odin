package chip9

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"

import "vendor:sdl3"

chip9: Chip9

main :: proc() {
	init_stdin()

	fmt.println("Available programs:")
	for rom, ix in rom_registry {
		fmt.printfln(" [{}] {}", ix, rom.name)
	}

	rom_ix: int
	for {
		fmt.print("Enter program index: ")

		line, lerr := read_line()
		if lerr == .EOF {
			fmt.printfln("\nNo user input given, quitting program.")
			os.exit(0)
		}
		if lerr != nil do fmt.panicf("error reading line: {}", lerr)
		defer delete(line)

		ok: bool
		rom_ix, ok = strconv.parse_int(line)
		if !ok {
			fmt.println("Please enter a single whole number.")
		} else if rom_ix < 0 || len(rom_registry) <= rom_ix {
			fmt.printfln("Please enter a number between 0 and {}.", len(rom_registry)-1)
		} else do break
	}

	rom := rom_registry[rom_ix]

	init_chip9(&chip9)
	defer destroy_graphics(&chip9.graphics)

	if rom.setup != nil do rom.setup(&rom.rom)
	load_rom(&chip9, rom.rom[:])

	{
		fmt.println()
		fmt.println("PROGRAM:")

		fmt.println("      ...0 ...1 ...2 ...3 ...4 ...5 ...6 ...7  ...8 ...9 ...A ...B ...C ...D ...E ...F")
		prev_skipped := false
		empty_row: [16]u16
		last_row := 0
		for row in 0..<(1<<12) {
			last_row = row+1

			if slice.simple_equal(rom.rom[row*16:(row+1)*16], empty_row[:]) {
				if !prev_skipped do fmt.println("      ***************************************  ***************************************")
				prev_skipped = true
				continue
			} else do prev_skipped = false

			fmt.printf("%03X. ", row)
			for col in 0..<16 {
				if col == 8 do fmt.print(" ")
				fmt.printf(" %04X", rom.rom[row*16 + col])
			}
			fmt.println()
		}

		fmt.println()
	}

	fmt.println("ROM LOADED")
	fmt.printfln("  V0=%04X", chip9.cpu.registers[.V0])

	when ODIN_DEBUG do i := 0
	fmt.printfln("pc=%04X [pc]=%04X", chip9.cpu.pc, chip9.cpu.memory[chip9.cpu.pc])
	exec_loop: for executed in clock_tick(&chip9.clock, &chip9) {
		if !executed do continue

		event: sdl3.Event
		for sdl3.PollEvent(&event) {
			if event.type == .QUIT do break exec_loop
		}

		//fmt.printfln("  i=%03d V0=%04X", i, chip9.cpu.registers[.V0])
		when ODIN_DEBUG do fmt.eprintfln("  Registers: {}", transmute([16]u16) chip9.cpu.registers)
		when ODIN_DEBUG do i += 1
		//fmt.printfln("pc=%04X [pc]=%04X", chip9.cpu.pc, chip9.cpu.memory[chip9.cpu.pc])
	}

	fmt.println("CPU HALTED")

	when ODIN_DEBUG do fmt.eprintfln("  i=%03d V0=%04X=%d", i, chip9.cpu.registers[.V0], chip9.cpu.registers[.V0])

	if rom.setup == fib_rom_setup_proc {
		fmt.println()
		fmt.printfln("The nth fibonacci number was calculated to be %d", chip9.cpu.registers[.V0])
	}
}
