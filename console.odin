package chip9

Chip9 :: struct {
	cpu: Cpu,

	clock: Clock,
	graphics: Graphics_Chip,
}

init_chip9 :: proc(chip9: ^Chip9) {
	chip9^ = {}
	init_cpu(&chip9.cpu)
	chip9.cpu.clock_chip = clock_as_device(&chip9.clock)
	init_graphics(&chip9.graphics)
	chip9.cpu.graphics_chip = graphics_as_device(&chip9.graphics)
}

load_rom :: proc(chip9: ^Chip9, rom: []u16) -> (ok: bool) {
	return cpu_load_rom(&chip9.cpu, rom)
}
