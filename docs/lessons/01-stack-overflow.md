# Lesson 01 — Stack Buffer Overflows

> Maps to **level0, level1, level2** (and the overflow half of **level9**). Prereq: lesson 00.

## The core idea

A fixed-size buffer lives on the stack. A copy routine writes into it **without checking the length**. You send more bytes than the buffer holds, so the write spills past the buffer into whatever sits at higher addresses: other locals, saved EBP, the **saved return address**, and beyond. By choosing what lands where, you either:

- **(a)** flip a nearby variable/flag to a value the program checks, or
- **(b)** overwrite the **saved return address (EIP)** so that when the function returns, execution jumps to *your* chosen address (an existing function, or shellcode).

That's the whole family. level0/level2 are flavor (a)/(b) variations; level1 is a classic saved-EIP overwrite.

## The dangerous functions (spot these in recon)

`gets()` (no bound at all — always exploitable), `strcpy`, `strcat`, `sprintf`, `scanf("%s")`, and `read()`/`fread()` **when the length argument is larger than the destination buffer**. In `ltrace` / the `gdb` disassembly you'll see the call and its size argument — compare it to the buffer size from the prologue's `sub $N,%esp`.

## Anatomy of the overwrite

Given a prologue `sub $0x50,%esp` and a buffer at `lea -0x48(%ebp),%eax`:

```
[ebp-0x48] ─ buffer starts here ────────────┐
   ... 0x48 = 72 bytes of buffer ...          │ you control these
[ebp-0x00] saved EBP        (+4 bytes) ───────┤  → total 72 + 4 = 76 to reach EIP
[ebp+0x04] saved EIP (return address) ────────┘  ← bytes 77..80 overwrite this
```
So the **offset to the return address** here is `buffer_distance_from_ebp + 4` = `0x48 + 4 = 76`. This is *arithmetic you must show*, then **confirm in gdb** (lesson 00 §5). Do not just trust the arithmetic — padding, alignment (`and $0xfffffff0,%esp`), and compiler quirks shift it.

## Flavor (a): overwrite a variable / flag

Sometimes you don't need EIP at all. A local (or global) flag is checked *after* the vulnerable copy:

```c
char buf[64];
int  auth = 0;
gets(buf);
if (auth) win();        // or if (auth == 0xdeadbeef)
```
If `auth` sits at a higher address than `buf` in the same frame (or is a struct field after the buffer), overflow just far enough to set it. The exact target value matters: `!= 0` vs a specific magic constant vs a specific byte. Read the comparison in the disassembly (`cmp`) to know what to write. Watch **byte order** and whether the check is on 1 byte or 4.

For a **struct** (level2-style: `struct { char buf[...]; int is_admin; }`), the field offset is fixed by the struct layout — overflow `buf` by exactly `offsetof(is_admin)` bytes, then write the field value.

## Flavor (b): overwrite the saved return address

1. Find the offset to saved EIP (arithmetic + gdb confirm).
2. Decide the target address to jump to:
   - an **existing function in the binary** (a `win`/`callsystem`/`run` that does `system("/bin/sh")` or reads the pass) — find it with `nm` / `gdb`'s `disas`;
   - a **PLT entry** (`system@plt`) plus a fake stack frame for its argument (bridges into lesson 03);
   - **shellcode** you injected (lesson 04);
   - a **ROP chain** (lesson 03) when NX is on.
3. Payload = `padding (offset bytes)` + `target address (little-endian, 4 bytes)`.

When you jump straight to a function that takes arguments (like `system(char*)`), remember cdecl: at the moment your `ret` transfers control, the callee expects `[esp] = fake return addr`, `[esp+4] = arg1`, ... So a `system("/bin/sh")` via overwrite looks like:
```
padding | &system | &(fake ret / &exit) | &"/bin/sh"
```
For jumping to a parameterless internal `win()`, you often just need `padding | &win`.

## i386 gotchas that bite here

- **Stack alignment**: `and $0xfffffff0,%esp` in `main` rounds ESP down, which can add hidden padding between your buffer and saved EIP. Your gdb-confirmed offset already accounts for it — trust the measurement over the naive `buf_size+8`.
- **Null bytes**: `strcpy`/`gets` stop at different terminators. `strcpy` copies until a `\0`, so a target address containing a `0x00` byte (e.g. `0x08048f00`) will truncate the copy — you may need to place it last, or use a `read()`-based path that copies fixed length including nulls.
- **Off-by-one / newline**: `gets` strips the newline; `fgets`/`read` may keep it. Count bytes exactly.
- **gdb vs shell stack drift**: a return address pointing at *binary code* (`0x08048xxx`) is stable regardless of env; a return address pointing at the *stack* (shellcode) is not (lesson 04).

## Questions to ask yourself

- What is the buffer's size (from `sub`/`lea`) and what is the copy length? Where's the gap?
- Am I overwriting a **variable** (cheaper) or do I need **EIP**? Re-read the `cmp` / control flow.
- What exact value/target does the check or jump require? How many bytes, what endianness?
- What's the offset — and have I confirmed `EIP == 0x42424242` with a marker before building the real payload?
- Does my target address contain null bytes that a string copy would truncate?
- If jumping to a function with arguments, have I laid out the fake frame (ret slot + args) correctly for cdecl?

## Defensive takeaway (the subject's real goal)

These bugs vanish with bounded copies (`fgets` with the real size, `strncpy`/`snprintf`), never `gets`, and compiler mitigations (`-fstack-protector`, NX, PIE, RELRO). Note in your walkthrough which single mitigation would have killed the exploit — that's the "bugless program" lesson the subject is after.
