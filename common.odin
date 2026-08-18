package chip9

import "core:io"
import "core:os"
import "core:strings"

Device_Proc :: #type proc(ptr: rawptr, register: ^u16, command_nibble: u8)

Device :: struct {
	device_proc: Device_Proc,
	data: rawptr,
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
