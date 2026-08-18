package chip9

import "core:fmt"
import "core:time"

CYCLES_PER_FRAME  :: 50_000
FRAMES_PER_SECOND :: 60

GRAPHICS_CYCLES :: 512
COMPUTE_CYCLES  :: CYCLES_PER_FRAME - GRAPHICS_CYCLES

FRAME_DURATION :: (1e9/FRAMES_PER_SECOND) * time.Nanosecond

Clock :: struct {
	cycle: u16,
	frame: u16,
	second: u16,
	epoch: u16,

	timer: u16,
	frame_timer: u16,

	suspend_cycles: u16,
	end_frame: bool,
}

clock_device_proc :: proc(ptr: rawptr, register: ^u16, command_nibble: u8) {
	clock := cast(^Clock) ptr

	invalid :: #force_inline proc(command: u8, loc := #caller_location) -> ! {
		fmt.panicf("Invalid clock command %02X", command)
	}

	switch command_nibble {
	case 0x0: register^ = clock.cycle
	case 0x1: register^ = clock.frame
	case 0x2: register^ = clock.second
	case 0x3: register^ = clock.epoch

	case 0x8: register^ = clock.timer
	case 0x9: clock.timer = register^
	case 0xA: register^ = clock.frame_timer
	case 0xB: clock.frame_timer = register^

	case 0xC: clock.suspend_cycles = register^
	case 0xD: clock.end_frame = true

	case: invalid(command_nibble)
	}
}

clock_as_device :: proc(clock: ^Clock) -> Device {
	return Device {
		device_proc = clock_device_proc,
		data = clock,
	}
}
clock_tick :: proc(clock: ^Clock, chip9: ^Chip9) -> (not_halted: bool) {
	assert(clock.cycle < CYCLES_PER_FRAME)
	assert(clock.suspend_cycles == 0)
	assert(!clock.end_frame)

	frame_ended := false

	cpu_should_run := clock.cycle < COMPUTE_CYCLES

	if cpu_should_run {
		cycle(&chip9.cpu) or_return
	} else {
		// TODO: graphics
		clock.end_frame = true
	}

	clock.cycle += 1
	if clock.timer > 0 do clock.timer -= 1
	cycles_till_end := CYCLES_PER_FRAME - clock.cycle

	assert(!clock.end_frame || clock.suspend_cycles == 0)

	if clock.end_frame {
		clock.end_frame = false
		frame_ended = true

		clock.cycle = 0
		clock.frame += 1
		if clock.timer <= cycles_till_end do clock.timer = 0
		else do clock.timer -= cycles_till_end
	} else if clock.suspend_cycles != 0 && clock.suspend_cycles >= cycles_till_end {
		clock.suspend_cycles -= cycles_till_end
		frame_ended = true

		clock.cycle = 0
		clock.frame += 1
		if clock.timer <= cycles_till_end do clock.timer = 0
		else do clock.timer -= cycles_till_end
	} else if cycles_till_end == 0 {
		frame_ended = true

		clock.cycle = 0
		clock.frame += 1
	}

	sleep_time: time.Duration

	if frame_ended {
		if clock.frame == FRAMES_PER_SECOND {
			clock.frame = 0
			clock.second += 1
			if clock.second == 0 do clock.epoch += 1
		}

		sleep_time += FRAME_DURATION

		for clock.suspend_cycles >= CYCLES_PER_FRAME {
			clock.suspend_cycles -= CYCLES_PER_FRAME
			if clock.timer <= CYCLES_PER_FRAME do clock.timer = 0
			else do clock.timer = 0

			clock.frame += 1
			if clock.frame == FRAMES_PER_SECOND {
				clock.frame = 0
				clock.second += 1
				if clock.second == 0 do clock.epoch += 1
			}

			sleep_time += FRAME_DURATION
		}

		if cpu_should_run {
			// TODO: graphics
		}
	}

	if clock.suspend_cycles != 0 {
		clock.cycle += clock.suspend_cycles
		assert(clock.cycle < CYCLES_PER_FRAME)

		if clock.timer <= CYCLES_PER_FRAME do clock.timer = 0
		else do clock.timer = 0
	}

	time.sleep(sleep_time)

	return true
}
