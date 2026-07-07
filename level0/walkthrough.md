# Waltrough

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

# disassemble the main program
(gdb) disas /r main
Dump of assembler code for function main:
   0x08048ec0 <+0>:     55      push   %ebp
   0x08048ec1 <+1>:     89 e5   mov    %esp,%ebp
   0x08048ec3 <+3>:     83 e4 f0        and    $0xfffffff0,%esp
   0x08048ec6 <+6>:     83 ec 20        sub    $0x20,%esp
   0x08048ec9 <+9>:     8b 45 0c        mov    0xc(%ebp),%eax
   0x08048ecc <+12>:    83 c0 04        add    $0x4,%eax
   0x08048ecf <+15>:    8b 00   mov    (%eax),%eax
   0x08048ed1 <+17>:    89 04 24        mov    %eax,(%esp)
   0x08048ed4 <+20>:    e8 37 08 00 00  call   0x8049710 <atoi>

# compare the args to $0x1a7
   0x08048ed9 <+25>:    3d a7 01 00 00  cmp    $0x1a7,%eax
   0x08048ede <+30>:    75 78   jne    0x8048f58 <main+152> # it says to jump to <main+152> if the arg is not $0x1a7
   0x08048ee0 <+32>:    c7 04 24 48 53 0c 08    movl   $0x80c5348,(%esp)
   0x08048ee7 <+39>:    e8 04 7d 00 00  call   0x8050bf0 <strdup>
   0x08048eec <+44>:    89 44 24 10     mov    %eax,0x10(%esp)
   0x08048ef0 <+48>:    c7 44 24 14 00 00 00 00 movl   $0x0,0x14(%esp)
   0x08048ef8 <+56>:    e8 83 b7 00 00  call   0x8054680 <getegid>
   0x08048efd <+61>:    89 44 24 1c     mov    %eax,0x1c(%esp)
   0x08048f01 <+65>:    e8 6a b7 00 00  call   0x8054670 <geteuid>
   0x08048f06 <+70>:    89 44 24 18     mov    %eax,0x18(%esp)
   0x08048f0a <+74>:    8b 44 24 1c     mov    0x1c(%esp),%eax
   0x08048f0e <+78>:    89 44 24 08     mov    %eax,0x8(%esp)
   0x08048f12 <+82>:    8b 44 24 1c     mov    0x1c(%esp),%eax
   0x08048f16 <+86>:    89 44 24 04     mov    %eax,0x4(%esp)
   0x08048f1a <+90>:    8b 44 24 1c     mov    0x1c(%esp),%eax
   0x08048f1e <+94>:    89 04 24        mov    %eax,(%esp)
   0x08048f21 <+97>:    e8 da b7 00 00  call   0x8054700 <setresgid>
   0x08048f26 <+102>:   8b 44 24 18     mov    0x18(%esp),%eax
   0x08048f2a <+106>:   89 44 24 08     mov    %eax,0x8(%esp)
   0x08048f2e <+110>:   8b 44 24 18     mov    0x18(%esp),%eax
   0x08048f32 <+114>:   89 44 24 04     mov    %eax,0x4(%esp)
   0x08048f36 <+118>:   8b 44 24 18     mov    0x18(%esp),%eax
   0x08048f3a <+122>:   89 04 24        mov    %eax,(%esp)
   0x08048f3d <+125>:   e8 4e b7 00 00  call   0x8054690 <setresuid>
   0x08048f42 <+130>:   8d 44 24 10     lea    0x10(%esp),%eax
   0x08048f46 <+134>:   89 44 24 04     mov    %eax,0x4(%esp)
   0x08048f4a <+138>:   c7 04 24 48 53 0c 08    movl   $0x80c5348,(%esp)

# call execve to execute command if input is correct ($0x1a7)
   0x08048f51 <+145>:   e8 ea b6 00 00  call   0x8054640 <execv>
   0x08048f56 <+150>:   eb 28   jmp    0x8048f80 <main+192>

# in case where arg's not $0x1a7, it writes "No !" in stderr
   0x08048f58 <+152>:   a1 70 e1 0e 08  mov    0x80ee170,%eax
   0x08048f5d <+157>:   89 c2   mov    %eax,%edx
   0x08048f5f <+159>:   b8 50 53 0c 08  mov    $0x80c5350,%eax
   0x08048f64 <+164>:   89 54 24 0c     mov    %edx,0xc(%esp)
   0x08048f68 <+168>:   c7 44 24 08 05 00 00 00 movl   $0x5,0x8(%esp)
   0x08048f70 <+176>:   c7 44 24 04 01 00 00 00 movl   $0x1,0x4(%esp)
   0x08048f78 <+184>:   89 04 24        mov    %eax,(%esp)
   0x08048f7b <+187>:   e8 b0 12 00 00  call   0x804a230 <fwrite>
   0x08048f80 <+192>:   b8 00 00 00 00  mov    $0x0,%eax
   0x08048f85 <+197>:   c9      leave  
   0x08048f86 <+198>:   c3      ret    
End of assembler dump.
(gdb) quit

# get the value of 0x1a7 using bc
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
