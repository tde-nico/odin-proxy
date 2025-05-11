package main

import "core:os"
import "core:fmt"
import "core:net"
import "core:thread"
import "core:flags"

addr: net.IP4_Address
to_port: int

transfer_data :: proc(src, dst: net.TCP_Socket) {
	buf: [1024]byte
	for {
		n, err := net.recv(src, buf[:])
		if err != nil {
			fmt.println("Error receiving data:", err)
			return
		}
		if n == 0 {
			break
		}

		_, err = net.send(dst, buf[:n])
		if err != nil {
			fmt.println("Error sending data:", err)
			return
		}
	}
}

handle_conn :: proc(conn: net.TCP_Socket) {
	defer net.close(conn)

	dest, err := net.dial_tcp_from_address_and_port(addr, to_port)
	if err != nil {
		fmt.println("Failed to connect to destination:", err)
		return
	}
	defer net.close(dest)
	fmt.printf("Connected to %s:%d\n", net.address_to_string(addr), to_port)

	thread.create_and_start_with_poly_data2(dest, conn, transfer_data)
	transfer_data(conn, dest)

	fmt.println("Connection closed")
}

start_loop :: proc(from_addr: string, from_port: int) {
	local_addr, ok := net.parse_ip4_address(from_addr)
	if !ok {
		fmt.println("Failed to parse local address")
		return
	}
	
	endpoint := net.Endpoint{
		address = local_addr,
		port = from_port,
	}
	sock, err := net.listen_tcp(endpoint)
	if err != nil {
		fmt.println("Failed to create socket:", err)
		return
	}
	defer net.close(sock)
	
	fmt.printf("Listening on 0.0.0.0:%d\n", from_port)
	for {
		conn, from, err := net.accept_tcp(sock)
		if err != nil {
			fmt.println("Failed to accept connection:", err)
			continue
		}
		fmt.printf("Accepted connection from %s:%d\n", net.address_to_string(from.address), from.port)
		thread.create_and_start_with_poly_data(conn, handle_conn)
	}
}

main :: proc() {
	ok: bool
	local_addr: net.IP4_Address

	Options :: struct {
		to_port: int `usage:"the port to send data to."`,
		from_port: int `usage:"the port to listen on."`,
		hostname: string `usage:"the hostname to connect to."`,
		local_addr: string `usage:"the local address to bind to."`,
		varg: [dynamic]string `usage:"Any extra arguments go here."`,
	}
	opt := Options{
		to_port = 1338,
		from_port = 1337,
		hostname = "127.0.0.1",
		local_addr = "0.0.0.0",
	}
	style : flags.Parsing_Style = .Odin
	flags.parse_or_exit(&opt, os.args, style)

	to_port = opt.to_port
	addr, ok = net.parse_ip4_address(opt.hostname)
	if !ok {
		fmt.println("Failed to parse address:", opt.hostname)
		return
	}

	start_loop(opt.local_addr, opt.from_port)
}
