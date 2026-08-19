package chip9

import "core:fmt"

Register :: enum {
	V0 = 0x0,
	V1 = 0x1,
	V2 = 0x2,
	V3 = 0x3,
	V4 = 0x4,
	V5 = 0x5,
	V6 = 0x6,
	V7 = 0x7,
	V8 = 0x8,
	V9 = 0x9,
	VA = 0xA,
	VB = 0xB,
	VC = 0xC,
	VD = 0xD,
	VE = 0xE,
	VF = 0xF,
}

Cpu :: struct {
	memory:    [1<<16]   u16,
	registers: [Register]u16,
	pc:        u16,

	graphics_chip: Device,
	sound_chip: Device,
	input_chip: Device,
	clock_chip: Device,
}

init_cpu :: proc(cpu: ^Cpu) {
	cpu^ = {}
	cpu.registers[.VE] = 0xFFFF
}

make_cpu :: proc() -> Cpu {
	res := Cpu {}
	init_cpu(&res)
	return res
}

cpu_load_rom :: proc(cpu: ^Cpu, rom: []u16) -> (ok: bool) {
	if len(rom) > len(cpu.memory) do return false

	cpu.memory = {}
	copy_slice(cpu.memory[:], rom)

	return true
}

// HALT with ok = false
cycle :: proc(cpu: ^Cpu) -> (ok: bool) {
	instr := cpu.memory[cpu.pc]
	old_pc := cpu.pc
	cpu.pc += 1

	sub_instr :=  (instr&0xF000)>>(4*3)
	r := Register((instr&0x0F00)>>(4*2))
	y := Register((instr&0x00F0)>>(4*1))
	X :=          (instr&0x000F)>>(4*0)
	XX :=         (instr&0x00FF)>>(4*0)
	XXX :=        (instr&0x0FFF)>>(4*0)

	V0 := &cpu.registers[.V0]
	VE := &cpu.registers[.VE]
	VF := &cpu.registers[.VF]
	Vr := &cpu.registers[r]
	Vy := &cpu.registers[y]

	sV0 := cast(^i16) V0
	sVF := cast(^i16) VF
	sVr := cast(^i16) Vr
	sVy := cast(^i16) Vy

	invalid :: #force_inline proc(instr: u16, instr_loc: u16, loc := #caller_location) -> ! {
		fmt.panicf("Invalid instruction %04x at memory address 0x%04x", instr, instr_loc, loc=loc)
	}

	switch sub_instr {
	case 0x0: switch X {
		case 0x0: switch XX>>4 {
			case 0x0:
				when ODIN_DEBUG do fmt.eprintfln("<INSTR HALT>")
				return false // halt
			case 0x1:
				when ODIN_DEBUG do fmt.eprintf("<INSTR RET:")
				VE^ += 1
				if VE^ == 0 {
					when ODIN_DEBUG do fmt.eprintfln("call stack underflowed!>")
					return false // halt
				}
				cpu.pc = cpu.memory[VE^]
				when ODIN_DEBUG do fmt.eprintfln("$%04X>", cpu.pc)
			case 0x2:
				when ODIN_DEBUG do fmt.eprintf("<INSTR PUSH {} ($%04X)", r, Vr^)
				if VE^ == 0 {
					when ODIN_DEBUG do fmt.eprintln(";stack overflowed!>")
					return false // halt
				}
				when ODIN_DEBUG do fmt.eprintln(">")
				cpu.memory[VE^] = Vr^
				VE^ -= 1
			case 0x3:
				when ODIN_DEBUG do fmt.eprintf("<INSTR POP {}:", r)
				VE^ += 1
				if VE^ == 0 {
					when ODIN_DEBUG do fmt.eprintfln("stack underflowed!>")
				}
				Vr^ = cpu.memory[VE^]
				when ODIN_DEBUG do fmt.eprintfln("$%04X>", Vr^)
			case: invalid(instr, old_pc)
		}
		case 0x1:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR {} ($%04X), $%02X to graphics chip>", r, Vr^, XX>>4)
			if cpu.graphics_chip.device_proc == nil {
				panic("no graphics chip")
			}
			cpu.graphics_chip.device_proc(cpu.graphics_chip.data, Vr, u8(XX>>4))
		case 0x2:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR {} ($%04X), $%02X to sound chip>", r, Vr^, XX>>4)
			if cpu.sound_chip.device_proc == nil {
				panic("no sound chip")
			}
			cpu.sound_chip.device_proc(cpu.sound_chip.data, Vr, u8(XX>>4))
		case 0x3:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR {} ($%04X), $%02X to input chip>", r, Vr^, XX>>4)
			if cpu.input_chip.device_proc == nil {
				panic("no input chip")
			}
			cpu.input_chip.device_proc(cpu.input_chip.data, Vr, u8(XX>>4))
		case 0x4:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR {} ($%04X), $%02X to clock chip>", r, Vr^, XX>>4)
			if cpu.clock_chip.device_proc == nil {
				panic("no clock chip")
			}
			cpu.clock_chip.device_proc(cpu.clock_chip.data, Vr, u8(XX>>4))
		case: invalid(instr, old_pc)
	}
	case 0x1:
		when ODIN_DEBUG do fmt.eprintfln("<INSTR {} = $%02X>", r, XX)
		Vr^ = XX
	case 0x2: switch X {
		case 0x0:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR {} = {} ($%04X)>", r, y, Vy^)
			Vr^ = Vy^
		case 0x1:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR {} = [{}] ([$%04X]=$%04X)>", r, y, Vy^, cpu.memory[Vy^])
			Vr^ = cpu.memory[Vy^]
		case 0x2:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR {} = [.V0 + {}] ([$%04X + $%04X]=$%04X)>", r, y, V0^, Vy^, cpu.memory[V0^ + Vy^])
			Vr^ = cpu.memory[V0^ + Vy^]
		case 0x3:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR {} = [PC + {}] ([$%04X + $%04X]=$%04X)>", r, y, old_pc, Vy^, cpu.memory[old_pc + Vy^])
			Vr^ = cpu.memory[old_pc + Vy^]
		case: invalid(instr, old_pc)
	}
	case 0x3: switch X {
		case 0x0:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR [{}] ([$%04X]) = 0>", r, Vr^, 0)
			cpu.memory[Vr^] = 0
		case 0x1:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR [{}] ([$%04X]) = {} ($%04X)>", r, Vr^, y, Vy^)
			cpu.memory[Vr^] = Vy^
		case 0x2:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR [.V0 + {}] ([$%04X + $%04X]) = {} ($%04X)>", r, V0^, Vr^, y, Vy^)
			cpu.memory[V0^ + Vr^] = Vy^
		case 0x3:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR [PC + {}] ([$%04X + $%04X]) = {} ($%04X)>", r, old_pc, Vr^, y, Vy^)
			cpu.memory[old_pc + Vr^] = Vy^
		case: invalid(instr, old_pc)
	}
	case 0x4: if XXX&0xF00 == 0 {
		signed_offset := i16(transmute(i8) u8(XX))
		cpu.pc = transmute(u16)(transmute(i16)old_pc + signed_offset)
		when ODIN_DEBUG {
			if signed_offset >= 0 do fmt.eprintfln("<INSTR JMP PC + $%02X ($%04X)>", XX, cpu.pc)
			else do fmt.eprintfln("<INSTR JMP PC - $%02X ($%04X)>", 1+~XX, cpu.pc) // negate XX; theoretically -XX would work as well but can't be bothered to test if it does
		}
	} else {
		when ODIN_DEBUG do fmt.eprintfln("<INSTR JMP $%03X>", XXX)
		cpu.pc = XXX
	}
	case 0x5: switch XX {
		case 0x00:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR JMP {} ($%04X)>", r, Vr^)
			cpu.pc = Vr^
		case 0x01:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR JMP [{}] ([$%04X]=$%04X)>", r, Vr^, cpu.memory[Vr^])
			cpu.pc = cpu.memory[Vr^]
		case 0x02:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR JMP [.V0 + {}] ([$%04X + $%04X]=$%04X)>", r, V0^, Vr^, cpu.memory[V0^ + Vr^])
			cpu.pc = cpu.memory[V0^ + Vr^]
		case 0x03:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR JMP [PC + {}] ([$%04X + $%04X]=$%04X)>", r, old_pc, Vr^, cpu.memory[old_pc + Vr^])
			cpu.pc = cpu.memory[old_pc + Vr^]

		case 0x10, 0x11:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR JMP {} ($%04X)>", r, Vr^)
			cpu.pc = Vr^
		case 0x12:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR JMP .V0 + {} ($%04X + $%04X)>", r, V0^, Vr^)
			cpu.pc = V0^ + Vr^
		case 0x13:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR JMP PC + {} ($%04X + $%04X)>", r, old_pc, Vr^)
			cpu.pc = old_pc + Vr^
	}
	case 0x6: switch X {
		case 0x0:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR {} = {} + {} ($%04X + $%04X)>", r, r, y, Vr^, Vy^)
			res := sVr^ + sVy^
			if sVy^ > 0 && res < sVr^ do sVF^ = -1
			else if sVy^ < 0 && res > sVr^ do sVF^ = -1
			else do sVF^ = 0
			when ODIN_DEBUG do fmt.eprintfln("<FLAGS: {}>", sVF^)
			sVr^ = res
		case 0x1:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR {} = {} - {} ($%04X - $%04X)>", r, r, y, Vr^, Vy^)
			res := sVr^ - sVy^
			if sVy^ > 0 && res > sVr^ do sVF^ = -1
			else if sVy^ < 0 && res < sVr^ do sVF^ = -1
			else do sVF^ = 0
			when ODIN_DEBUG do fmt.eprintfln("<FLAGS: {}>", sVF^)
			sVr^ = res
		case 0x2:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR {} = {} - {} ($%04X - $%04X)>", r, y, r, Vy^, Vr^)
			res := sVy^ - sVr^
			if sVr^ > 0 && res > sVy^ do sVF^ = -1
			else if sVr^ < 0 && res < sVy^ do sVF^ = -1
			else do sVF^ = 0
			when ODIN_DEBUG do fmt.eprintfln("<FLAGS: {}>", sVF^)
			sVr^ = res
		case 0x3:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR {} = {} * {} ($%04X * $%04X)>", r, r, y, Vr^, Vy^)
			res := sVr^ * sVy^
			bigRes := i64(sVr^) * i64(sVy^)
			if i64(res) != bigRes do sVF^ = -1
			else do sVF^ = 0
			when ODIN_DEBUG do fmt.eprintfln("<FLAGS: {}>", sVF^)
			sVr^ = res
		case 0x4:
			// for x and y if q = x/y and r = x%y then:
			//     x = q*y + r AND
		        //     |r| < |y|
			when ODIN_DEBUG do fmt.eprintfln("<INSTR {} = {} / {} ($%04X / $%04X)>", r, r, y, Vr^, Vy^)
			if sVy^ == 0 do return false
			q := sVr^ / sVy^
			r := sVr^ % sVy^
			sVr^ = q
			sVF^ = r
			when ODIN_DEBUG do fmt.eprintfln("<FLAGS: {}>", sVF^)
		case 0x5: panic("TODO: shift overflow logic")
		case 0x6: panic("TODO: shift overflow logic")
		case: invalid(instr, old_pc)
	}
	case 0x7:
		sign_bit := XXX>>11
		if sign_bit != 0 {
			XXX |= 0xF000
		}
		when ODIN_DEBUG {
			if sign_bit == 0 do fmt.eprintfln("<INSTR .V0 = .V0 ($%04X) + $%03X>", V0^, XXX)
			else do fmt.eprintfln("<INSTR .V0 = .V0 ($%04X) - $%03X>", V0^, 1+~XXX) // negate XXX; theoretically -XXX would work as well but can't be bothered to test if it does
		}
		res := sV0^ + transmute(i16)XXX
		if XXX > 0 && res < sV0^ do sVF^ = -1
		else if XXX < 0 && res > sV0^ do sVF^ = -1
		else do sV0^ = 0
		sV0^ = res
	case 0x8:
		when ODIN_DEBUG do fmt.eprintf("<INSTR CALL $%03X", XXX)
		if VE^ == 0 {
			when ODIN_DEBUG do fmt.eprintln(";call stack overflowed!>")
			return false // halt
		}
		when ODIN_DEBUG do fmt.eprintln(">")
		cpu.memory[VE^] = cpu.pc
		VE^ -= 1
		cpu.pc = XXX
	case 0x9:
		sign_bit := XXX>>11
		if sign_bit != 0 {
			XXX |= 0xF000
		}
		when ODIN_DEBUG {
			if sign_bit == 0 do fmt.eprintln("<INSTR CALL PC + $%03X", XXX)
			else do fmt.eprintfln("<INSTR CALL PC - $%03X", 1+~XXX) // negate XXX; theoretically -XXX would work as well but can't be bothered to test if it does
		}
		if VE^ == 0 {
			when ODIN_DEBUG do fmt.eprintln(";call stack overflowed!>")
			return false // halt
		}
		when ODIN_DEBUG do fmt.eprintln(">")
		cpu.memory[VE^] = cpu.pc
		VE^ -= 1
		cpu.pc += XXX
	case 0xA: switch X {
		case 0x0:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR CALL {} ($%04X)", r, Vr^)
			if VE^ == 0 {
				when ODIN_DEBUG do fmt.eprintln(";call stack overflowed!")
				return false // halt
			}
			when ODIN_DEBUG do fmt.eprintln(">")
			cpu.memory[VE^] = cpu.pc
			VE^ -= 1
			cpu.pc = Vr^
		case 0x1:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR CALL [{}] ([$%04X]=$%04X)", r, Vr^, cpu.memory[Vr^])
			if VE^ == 0 {
				when ODIN_DEBUG do fmt.eprintln(";call stack overflowed!")
				return false // halt
			}
			when ODIN_DEBUG do fmt.eprintln(">")
			cpu.memory[VE^] = cpu.pc
			VE^ -= 1
			cpu.pc = cpu.memory[Vr^]
		case 0x2:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR CALL [.V0 + {}] ([$%04X + $%04X]=$%04X)", r, V0^, Vr^, cpu.memory[V0^ + Vr^])
			if VE^ == 0 {
				when ODIN_DEBUG do fmt.eprintln(";call stack overflowed!")
				return false // halt
			}
			when ODIN_DEBUG do fmt.eprintln(">")
			cpu.memory[VE^] = cpu.pc
			VE^ -= 1
			cpu.pc = cpu.memory[V0^ + Vr^]
		case 0x3:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR CALL [PC + {}] ([$%04X + $%04X]=$%04X)", r, old_pc, Vr^, cpu.memory[old_pc + Vr^])
			if VE^ == 0 {
				when ODIN_DEBUG do fmt.eprintln(";call stack overflowed!")
				return false // halt
			}
			when ODIN_DEBUG do fmt.eprintln(">")
			cpu.memory[VE^] = cpu.pc
			VE^ -= 1
			cpu.pc = cpu.memory[old_pc + Vr^]
		case: invalid(instr, old_pc)
	}
	case 0xB: switch X {
		case 0x0:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR SKIP IF {} == {} ($%04X == $%04X)>", r, y, Vr^, Vy^)
			if sVr^ == sVy^ do cpu.pc += 1
		case 0x1:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR SKIP IF {} != {} ($%04X != $%04X)>", r, y, Vr^, Vy^)
			if sVr^ != sVy^ do cpu.pc += 1
		case 0x2:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR SKIP IF {} < {} ($%04X < $%04X)>", r, y, Vr^, Vy^)
			if sVr^ < sVy^ do cpu.pc += 1
		case 0x3:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR SKIP IF {} <= {} ($%04X <= $%04X)>", r, y, Vr^, Vy^)
			if sVr^ <= sVy^ do cpu.pc += 1
		case 0x4:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR SKIP IF {} > {} ($%04X > $%04X)>", r, y, Vr^, Vy^)
			if sVr^ > sVy^ do cpu.pc += 1
		case 0x5:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR SKIP IF {} >= {} ($%04X >= $%04X)>", r, y, Vr^, Vy^)
			if sVr^ >= sVy^ do cpu.pc += 1

		case 0x8:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR SKIP IF {} == 0 ($%04X == 0)>", r, Vr^)
			if sVr^ == 0 do cpu.pc += 1
		case 0x9:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR SKIP IF {} != 0 ($%04X != 0)>", r, Vr^)
			if sVr^ != 0 do cpu.pc += 1
		case 0xA:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR SKIP IF {} < 0 ($%04X < 0)>", r, Vr^)
			if sVr^ < 0 do cpu.pc += 1
		case 0xB:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR SKIP IF {} <= 0 ($%04X <= 0)>", r, Vr^)
			if sVr^ <= 0 do cpu.pc += 1
		case 0xC:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR SKIP IF {} > 0 ($%04X > 0)>", r, Vr^)
			if sVr^ > 0 do cpu.pc += 1
		case 0xD:
			when ODIN_DEBUG do fmt.eprintfln("<INSTR SKIP IF {} >= 0 ($%04X >= 0)>", r, Vr^)
			if sVr^ >= 0 do cpu.pc += 1

		case: invalid(instr, old_pc)
	}
	case: invalid(instr, old_pc)
	}

	return true
}
