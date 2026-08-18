package chip9

Chip9 :: struct {
	cpu: Cpu,

	clock: Clock,
}

init_chip9 :: proc(chip9: ^Chip9) {
	chip9^ = {}
	init_cpu(&chip9.cpu)
}

make_chip9 :: proc() -> Chip9 {
	res := Chip9 {}
	init_chip9(&res)
	return res
}

load_rom :: proc(chip9: ^Chip9, rom: []u16) -> (ok: bool) {
	return cpu_load_rom(&chip9.cpu, rom)
}
