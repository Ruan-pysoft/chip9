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
}

// HALT with ok = false
cycle :: proc(cpu: ^Cpu) -> (ok: bool) {
	instr := cpu.memory[cpu.pc]
	old_pc := cpu.pc
	cpu.pc += 1

	sub_instr :=  (instr&0xF000)>>(8*3)
	r := Register((instr&0x0F00)>>(8*2))
	y := Register((instr&0x00F0)>>(8*2))
	X :=          (instr&0x000F)>>(8*0)
	XX :=         (instr&0x00FF)>>(8*0)
	XXX :=        (instr&0x0FFF)>>(8*0)

	V0 := &cpu.registers[.V0]
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
		case 0x0: switch XX>>8 {
			case 0x0: return false // halt
			case 0x1: panic("TODO: RET")
			case: invalid(instr, old_pc)
		}
		case 0x1: panic("TODO: graphics chip")
		case 0x2: panic("TODO: sound chip")
		case 0x3: panic("TODO: input chip")
		case 0x4: panic("TODO: clock chip")
		case: invalid(instr, old_pc)
	}
	case 0x1: Vr^ = XX
	case 0x2: switch X {
		case 0x0: Vr^ = Vy^
		case 0x1: Vr^ = cpu.memory[Vy^]
		case 0x2: Vr^ = cpu.memory[V0^ + Vy^]
		case 0x3: Vr^ = cpu.memory[old_pc + Vy^]
		case: invalid(instr, old_pc)
	}
	case 0x3: switch X {
		case 0x0: cpu.memory[Vr^] = 0
		case 0x1: cpu.memory[Vr^] = Vy^
		case 0x2: cpu.memory[V0^ + Vr^] = Vy^
		case 0x3: cpu.memory[old_pc + Vr^] = Vy^
		case: invalid(instr, old_pc)
	}
	case 0x4: if XXX&0xF00 == 0 {
		signed_offset := i16(transmute(i8) u8(XX))
		cpu.pc = transmute(u16)(transmute(i16)cpu.pc + signed_offset)
	} else {
		cpu.pc = XXX
	}
	case 0x5: switch XX {
		case 0x00: cpu.pc = Vr^
		case 0x01: cpu.pc = cpu.memory[Vr^]
		case 0x02: cpu.pc = cpu.memory[V0^ + Vr^]
		case 0x03: cpu.pc = cpu.memory[old_pc + Vr^]

		case 0x10, 0x11: cpu.pc = Vr^
		case 0x12: cpu.pc = V0^ + Vr^
		case 0x13: cpu.pc = old_pc + Vr^
	}
	case 0x6: switch X {
		case 0x0:
			res := sVr^ + sVy^
			if res < sVr^ do sVF^ = -1
			else do sVF^ = 0
			sVr^ = res
		case 0x1:
			res := sVr^ - sVy^
			if transmute(i16)res > transmute(i16)sVr^ do sVF^ = -1
			else do sVF^ = 0
			sVr^ = res
		case 0x2:
			res := sVr^ * sVy^
			bigRes := i64(sVr^) * i64(sVy^)
			if i64(res) != bigRes do sVF^ = -1
			else do sVF^ = 0
			sVr^ = res
		case 0x3:
			// for x and y if q = x/y and r = x%y then:
			//     x = q*y + r AND
		        //     |r| < |y|
			if sVy^ == 0 do return false
			q := sVr^ / sVy^
			r := sVr^ % sVy^
			sVr^ = q
			sVF^ = r
		case 0x4: panic("TODO: shift overflow logic")
		case 0x5: panic("TODO: shift overflow logic")
		case: invalid(instr, old_pc)
	}
	case: invalid(instr, old_pc)
	}

	return true
}
