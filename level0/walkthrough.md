# Walktrough

```sh
# list the directory contents
level0@RainFall:~$ ls -la
total 737
dr-xr-x---+ 1 level0 level0     60 Mar  6  2016 .
dr-x--x--x  1 root   root      340 Sep 23  2015 ..
-rw-r--r--  1 level0 level0    220 Apr  3  2012 .bash_logout
-rw-r--r--  1 level0 level0   3530 Sep 23  2015 .bashrc
-rwsr-x---+ 1 level1 users  747441 Mar  6  2016 level0
-rw-r--r--  1 level0 level0    675 Apr  3  2012 .profile

# check security features on binary
level0@RainFall:~$ checksec --file /home/user/level0/level0
RELRO           STACK CANARY      NX            PIE             RPATH      RUNPATH      FILE
No RELRO        No canary found   NX enabled    No PIE          No RPATH   No RUNPATH   /home/user/level0/level0

# test the binary
level0@RainFall:~$ ./level0 
Segmentation fault (core dumped)
level0@RainFall:~$ ./level0 1
No !
level0@RainFall:~$ ./level0 a
No !
level0@RainFall:~$ ./level0 ""
No !
level0@RainFall:~$ ./level0 1 2
No !
level0@RainFall:~$ ./level0 1 2 2 3 4 5 6 7
No !

# use gdb to analyze the program's behavior with "" as argument
level0@RainFall:~$ gdb --args ./level0 1
GNU gdb (Ubuntu/Linaro 7.4-2012.04-0ubuntu2.1) 7.4-2012.04
Copyright (C) 2012 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.  Type "show copying"
and "show warranty" for details.
This GDB was configured as "i686-linux-gnu".
For bug reporting instructions, please see:
<http://bugs.launchpad.net/gdb-linaro/>...
Reading symbols from /home/user/level0/level0...(no debugging symbols found)...done.

# set assembly syntax into intel (better reading)
(gdb) set disassembly-flavor intel

# disassemble the main program
(gdb) disassemble main
Dump of assembler code for function main:
   0x08048ec0 <+0>:     push   ebp
   0x08048ec1 <+1>:     mov    ebp,esp
   0x08048ec3 <+3>:     and    esp,0xfffffff0
   0x08048ec6 <+6>:     sub    esp,0x20
   0x08048ec9 <+9>:     mov    eax,DWORD PTR [ebp+0xc]
   0x08048ecc <+12>:    add    eax,0x4
   0x08048ecf <+15>:    mov    eax,DWORD PTR [eax]
   0x08048ed1 <+17>:    mov    DWORD PTR [esp],eax
   0x08048ed4 <+20>:    call   0x8049710 <atoi>

# compare the args to $0x1a7
   0x08048ed9 <+25>:    cmp    eax,0x1a7
   0x08048ede <+30>:    jne    0x8048f58 <main+152># it says to jump to <main+152> if the arg is not $0x1a7
   0x08048ee0 <+32>:    mov    DWORD PTR [esp],0x80c5348
   0x08048ee7 <+39>:    call   0x8050bf0 <strdup>
   0x08048eec <+44>:    mov    DWORD PTR [esp+0x10],eax
   0x08048ef0 <+48>:    mov    DWORD PTR [esp+0x14],0x0
   0x08048ef8 <+56>:    call   0x8054680 <getegid>
   0x08048efd <+61>:    mov    DWORD PTR [esp+0x1c],eax
   0x08048f01 <+65>:    call   0x8054670 <geteuid>
   0x08048f06 <+70>:    mov    DWORD PTR [esp+0x18],eax
   0x08048f0a <+74>:    mov    eax,DWORD PTR [esp+0x1c]
   0x08048f0e <+78>:    mov    DWORD PTR [esp+0x8],eax
   0x08048f12 <+82>:    mov    eax,DWORD PTR [esp+0x1c]
   0x08048f16 <+86>:    mov    DWORD PTR [esp+0x4],eax
   0x08048f1a <+90>:    mov    eax,DWORD PTR [esp+0x1c]
   0x08048f1e <+94>:    mov    DWORD PTR [esp],eax
   0x08048f21 <+97>:    call   0x8054700 <setresgid>
   0x08048f26 <+102>:   mov    eax,DWORD PTR [esp+0x18]
   0x08048f2a <+106>:   mov    DWORD PTR [esp+0x8],eax
   0x08048f2e <+110>:   mov    eax,DWORD PTR [esp+0x18]
   0x08048f32 <+114>:   mov    DWORD PTR [esp+0x4],eax
   0x08048f36 <+118>:   mov    eax,DWORD PTR [esp+0x18]
   0x08048f3a <+122>:   mov    DWORD PTR [esp],eax
   0x08048f3d <+125>:   call   0x8054690 <setresuid>
   0x08048f42 <+130>:   lea    eax,[esp+0x10]
   0x08048f46 <+134>:   mov    DWORD PTR [esp+0x4],eax
   0x08048f4a <+138>:   mov    DWORD PTR [esp],0x80c5348

# call execve to execute command if input is correct ($0x1a7)
   0x08048f51 <+145>:   call   0x8054640 <execv>
   0x08048f56 <+150>:   jmp    0x8048f80 <main+192>

# in case where arg's not $0x1a7, it writes "No !" in stderr
   0x08048f58 <+152>:   mov    eax,ds:0x80ee170
   0x08048f5d <+157>:   mov    edx,eax
   0x08048f5f <+159>:   mov    eax,0x80c5350
   0x08048f64 <+164>:   mov    DWORD PTR [esp+0xc],edx
   0x08048f68 <+168>:   mov    DWORD PTR [esp+0x8],0x5
   0x08048f70 <+176>:   mov    DWORD PTR [esp+0x4],0x1
   0x08048f78 <+184>:   mov    DWORD PTR [esp],eax
   0x08048f7b <+187>:   call   0x804a230 <fwrite>
   0x08048f80 <+192>:   mov    eax,0x0
   0x08048f85 <+197>:   leave  
   0x08048f86 <+198>:   ret    
End of assembler dump.

(gdb) quit

# get the value of 0x1a7 using bc || just use p/d 0x1a7 on gdb to get the value
level0@RainFall:~$ echo "ibase=16; 1A7" | bc
423

# re-start gdb but with the right input
level0@RainFall:~$ gdb --args ./level0 423
GNU gdb (Ubuntu/Linaro 7.4-2012.04-0ubuntu2.1) 7.4-2012.04
Copyright (C) 2012 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.  Type "show copying"
and "show warranty" for details.
This GDB was configured as "i686-linux-gnu".
For bug reporting instructions, please see:
<http://bugs.launchpad.net/gdb-linaro/>...
Reading symbols from /home/user/level0/level0...(no debugging symbols found)...done.

# when we run the program , we notice that the program is executing a new program
(gdb) run
Starting program: /home/user/level0/level0 423
process 2966 is executing new program: /bin/dash
$ ls
level0
$ exit
[Inferior 1 (process 2966) exited normally]

# Set a breakpoint at `execv` call
(gdb) break *0x08048f51
Breakpoint 1 at 0x8048f51

# Run the program to see if it reaches the breakpoint
(gdb) run
Starting program: /home/user/level0/level0 423

Breakpoint 1, 0x08048f51 in main ()

# Examine the stack to see the arguments passed to `execv`
(gdb) x/wx ($esp)
0xbffff720:     0x080c5348
(gdb) x/s *(char **)($esp)
0x80c5348:       "/bin/sh"
(gdb) quit
A debugging session is active.

        Inferior 1 [process 2986] will be killed.

Quit anyway? (y or n) y

# check if the user is actually level1
$ whoami
level1

# get the flag
$ cat /home/user/level1/.pass
1fe8a524fa4bec01ca4ea2a869af2a02260d4a7d5fe7e7c24d8617e6dca12d3a

# use the level0 flag as the level1 password
$ su level1
Password: 
RELRO           STACK CANARY      NX            PIE             RPATH      RUNPATH      FILE
No RELRO        No canary found   NX disabled   No PIE          No RPATH   No RUNPATH   /home/user/level1/level1
level1@RainFall:~$

```
