# Lesson 00 — Toolkit & i386 Fundamentals

> Applies to **every** level. Read this first; the other lessons assume it.

This is your recon and reasoning kit. None of it is level-specific — it's the muscle memory the eval wants to see. The rule from the subject: *"Nothing is left to chance. If there is a problem, start wondering if your code is not the cause."* You must be able to explain every number you use.

---

## 1. The mental model: what the stack looks like on i386

RainFall is **32-bit x86 (i386)**, System V **cdecl** calling convention. Burn this into memory:

```
   higher addresses
   ┌───────────────────────┐
   │  argv / envp strings   │
   │  ...                    │
   │  arg N ... arg 1        │  ← caller pushes args RIGHT-TO-LEFT
   │  return address (EIP)   │  ← what `ret` pops into EIP
   │  saved EBP              │  ← `push %ebp` in the prologue
   │  local var A            │  ← [ebp-0x4]-ish
   │  buffer[...]            │  ← grows toward lower addresses when filled
   └───────────────────────┘
   lower addresses  ← ESP (top of stack)
```

Key facts you will use constantly:
- The stack **grows downward** (toward lower addresses), but a `strcpy`/`gets`/`read` **fills a buffer upward** (toward higher addresses). That is *why* overflowing a buffer eventually reaches saved EBP and then the return address.
- **cdecl**: arguments are passed **on the stack**, pushed right-to-left. Return value comes back in `EAX`. Caller cleans up the stack. This is why format-string bugs read *stack slots* as their arguments.
- A function prologue is almost always `push %ebp ; mov %esp,%ebp ; sub $N,%esp`. The `sub $N,%esp` tells you how many bytes of locals the frame has.
- Addresses are **little-endian**: the value `0x08048abc` is written in memory / your payload as the bytes `bc 8a 04 08`.

## 2. Reading a disassembly line

```
0x08048ecc <+12>:  add    $0x4,%eax        ; AT&T syntax: op src,dst
```
- AT&T order is `src, dst` (GNU tools default). `mov %esp,%ebp` means EBP ← ESP.
- `0x8(%esp)` = memory at ESP+8. `0xc(%ebp)` = memory at EBP+12.
- `lea 0x10(%esp),%eax` computes an *address* (EAX = ESP+0x10) without dereferencing — often a pointer to a local buffer/struct.
- `call 0x8049710 <atoi>` — note the symbol. `gdb`'s `disas` resolves PLT stubs to names, which is how you spot `system`, `strcpy`, `printf`, `gets`, `execve`, etc.

## 3. The recon loop (run this on every binary, in order)

```bash
ls -la                       # who owns it, is it setuid (-rwsr-x---)? note the +ACL
file ./levelX                # confirm: ELF 32-bit LSB, dynamically linked, not stripped?
./levelX ; ./levelX AAAA     # just run it — observe prompts, echoes, crashes
checksec --file=./levelX     # mitigations: RELRO / canary / NX / PIE  (see §4)
nm ./levelX                  # symbols: interesting globals, custom funcs (e.g. a hidden win())
nm -D ./levelX               # dynamic symbols (imported libc functions)
strings ./levelX             # "/bin/sh", format strings, prompts, hints
gdb -q ./levelX -batch -ex 'disas main'      # disassemble with gdb (our disassembler); see §2/§5
gdb -q ./levelX -batch -ex 'info functions'  # functions/symbols; use gef/pwndbg `got` for GOT entries
ltrace ./levelX AAAA         # libc calls + args, live — fastest way to see gets/strcpy/printf
strace ./levelX AAAA         # syscalls — confirms execve, reads, segfault address
```

Reading `main` fast:
```bash
gdb -q ./levelX -batch -ex 'disas main'              # just main (gdb is our disassembler)
gdb -q ./levelX -batch -ex 'disas /r main'           # /r also prints the raw opcode bytes per instruction
```

## 4. checksec — and what each result forces you to do

| Mitigation | If OFF / weak | If ON |
|---|---|---|
| **NX** (No eXecute) | You *can* inject and run shellcode on the stack (see lesson 04). | Stack not executable → you need **ROP/ret2libc** (lesson 03). |
| **Stack canary** | Plain overflow of saved EIP works. | A random cookie sits before saved EBP; overwriting it blindly aborts (`__stack_chk_fail`). You must leak or avoid it. |
| **PIE** | Code addresses are fixed (`0x08048xxx`) — you can hardcode them. | Code is randomized; you need an address leak first. |
| **RELRO** | Partial/None → **GOT is writable** (enables GOT overwrite, lesson 02/08). | Full RELRO → GOT is read-only. |
| **ASLR** (system-wide, not in checksec) | Stack/heap/libc addresses stable → hardcode. | Addresses move per-run → leak, or brute a few bits, or use non-randomized code addresses. |

Most early RainFall binaries are deliberately soft (No canary, NX disabled, No PIE). **Always run checksec and state the result in your walkthrough** — it's the justification for *why* you chose shellcode vs ROP vs a variable overwrite.

## 5. gdb workflow you'll reuse every level

Use `gef` or `pwndbg` if available (they add `checksec`, `pattern`, `got`, better stack views). Core moves:

```gdb
gdb ./levelX
disas main                     # find the vuln call and the instruction after it
break *0x08048abc              # break at a precise address (note the *)
run AAAA                       # or: run < /tmp/payload  |  run "$(cat /tmp/payload)"
info registers                 # esp/ebp/eip/eax at the crash or breakpoint
x/40wx $esp                    # dump 40 words from ESP in hex — read the stack
x/s 0x0804a010                 # show the string at an address (generic example addr)
x/i $eip                       # the instruction about to run
info frame                     # saved EIP location, saved EBP
```

**Finding the offset to the return address** (the single most common measurement):
1. Feed a *cyclic, non-repeating* pattern (`ABCDEFGH...` or gef's `pattern create 200`).
2. Let it crash. Read `EIP` (or `$esp` at the fault).
3. The bytes that landed in EIP tell you the exact offset. With gef: `pattern offset $eip`. By hand: find those 4 ASCII bytes in your pattern and count.
4. **Verify** by sending `"A"*offset + "BBBB"` and confirming `EIP == 0x42424242`. Never trust an offset you haven't confirmed lands exactly.

> ⚠️ **Environment shifts the stack.** Addresses seen in gdb can differ from a raw shell run because gdb injects extra env vars / a longer `argv[0]`. Techniques: run with a NOP sled for slack (lesson 04), clear the environment (`env -i`), or match `argv[0]` length. Always note this if your address is stack-based.

## 6. Building & delivering payloads with shell (allowed — these are *your* scripts)

Automated *exploitation frameworks that solve the level for you* are cheating. Writing your **own** payload is fine and expected ("You're invited to create scripts... but you will have to explain them"). We build payloads in the **shell** — `printf`, `head`, `tr` — no external language needed.

**Shell payload cookbook** (reused in every lesson):

```bash
head -c 76  /dev/zero | tr '\0' 'A'      # repeat a printable byte N times  → 76 'A's
head -c 200 /dev/zero | tr '\0' '\220'   # repeat a raw byte N times (NOP sled: 0x90 = octal 220)
printf '\xbc\x8a\x04\x08'                 # emit a 4-byte address, little-endian (bytes of 0x08048abc, reversed)
printf '%%'                               # emit a literal '%' inside a printf-built format-string payload
```

```bash
# stdin: 76 'A' padding then a little-endian return address
{ head -c 76 /dev/zero | tr '\0' 'A'; printf '\xbc\x8a\x04\x08'; } > /tmp/p
./levelX < /tmp/p
cat /tmp/p - | ./levelX          # keep stdin open after the payload (for an interactive shell)

# argv delivery
./levelX "$(head -c 76 /dev/zero | tr '\0' 'A')$(printf '\xbc\x8a\x04\x08')"

# a format-string arg is just a literal — single-quote it so the shell leaves % and $ alone
./levelX 'AAAA%7$x'
```
Use `printf` (never `echo`) for raw bytes, and remember little-endian: address `0x08048abc` is written `\xbc\x8a\x04\x08`. Group commands with `{ …; …; }` to concatenate their output, and watch for a stray trailing newline unless the target expects one.

## 7. Capturing the flag and moving on

```bash
# your exploit should drop you into a shell running as levelX+1
whoami                          # confirm you are the next user
cat /home/user/levelX+1/.pass   # the password = your flag
su levelX+1                     # log in as them, verify the password works
```
Then write the level folder (see `docs/REVIEW.md` for the template): `source.c`, `walkthrough.md`, `flag`, `Ressources/pass`.

## 8. Questions to ask yourself before asking for help

The subject: *"Before asking for help, ask yourself if you have factored in all the possibilities."* Checklist:
- What does the program actually do with my input? (ltrace it.)
- Which function is the dangerous one, and what's the size of the buffer it writes into vs. what I control?
- What are the mitigations (checksec), and which technique do they allow/forbid?
- Where is the thing I want to overwrite (return address / a variable / a GOT entry), and what's the exact byte offset to it?
- Have I *verified* that offset/address in gdb, or am I guessing?
- Is my address little-endian? Is my payload length exactly right (off-by-one on the null terminator)?
- Could the environment be shifting a stack address between gdb and the real run?

If you can answer all of these with evidence, you can write a walkthrough that survives the eval.
