# Lesson 03 — ROP, ret2plt / ret2libc & Stack Pivots (defeating NX)

> Maps to **level6, level9** (and any level where **NX is enabled**). Prereq: lessons 00–01.

## Why ROP exists

When **NX** is on, the stack/heap are not executable, so injected shellcode won't run. But you still control the saved return address (via a stack overflow, lesson 01). Instead of jumping to *your bytes*, you jump to **code that already exists** — the binary's own functions, PLT stubs, or short instruction sequences ending in `ret` (**gadgets**). Chaining these with the stack as your "program" is **Return-Oriented Programming**.

First, always confirm the constraint: `checksec` → NX enabled? If NX is *off*, prefer shellcode (lesson 04) — it's simpler. ROP is the answer specifically when you can't execute your own bytes.

## Background: PLT and GOT (you need this for ret2plt and lesson 02/08)

Dynamically-linked calls to libc go through two tables:
- **PLT** (Procedure Linkage Table, in the binary, executable): `call system@plt` jumps here; the stub reads the real address from the GOT and jumps to it.
- **GOT** (Global Offset Table, writable unless Full RELRO): holds the resolved libc addresses.

Consequences you exploit:
- You can `ret` **into a PLT entry** (`system@plt`) to call libc functions *at their fixed binary addresses* — no libc leak needed (**ret2plt**). Find these addresses with `gdb`'s `disas main` / `disas system` (look for `<system@plt>`) or `nm`.
- You can **overwrite a GOT entry** (lesson 02/level8) so a normal call is redirected.

## ret2plt: call a libc function via the PLT

If the binary imports `system` (or you can reach it), and a `"/bin/sh"` string exists somewhere (in the binary via `strings`, in an env var, or one you place), the classic frame after the overflow is:

```
padding to saved EIP
&system@plt        ← ret jumps here
&exit@plt          ← "return address" system sees (so it exits cleanly, not crash)
&"/bin/sh"         ← arg1 to system (cdecl: first arg at [esp+4] on entry)
```
Remember cdecl: when `system` begins, it reads its argument from `[esp+4]`; the `[esp]` slot is where it *thinks* it will return to. That's why the layout is `func | ret-for-func | arg1 | arg2 …`.

Chaining two calls (e.g. `setreuid(euid,euid)` then `system`) needs a **`pop; ret` gadget** to clean the first call's arguments before the next address is consumed:
```
&func1 | &(pop..pop; ret) | arg1..argN | &func2 | &after2 | args2...
```
The gadget pops `func1`'s N arguments off the stack so ESP lands on `&func2`.

## Finding gadgets

```bash
ropper --file ./levelX --search "pop; ret"
ropper --file ./levelX --search "pop ebx; pop ecx; ret"
ROPgadget --binary ./levelX | grep ': ret'
gdb -q ./levelX -batch -ex 'disas main' | grep -i ret   # eyeball ret-ending sequences (per function)
```
Common useful gadgets: `pop <reg>; ret` (load a value into a register / skip args), `ret` (alignment / stack pivot targets), `pop; pop; pop; ret` (clean 3 args), `leave; ret` (stack pivot), `int 0x80` (direct syscall).

> Using `ropper`/`ROPgadget` to **locate** gadgets is fine (they're analysis tools). Using a framework that **auto-builds and fires the whole chain** for you crosses into the "automation = cheating" line — assemble and justify the chain yourself.

## ret2libc (when the binary doesn't call system itself)

If `system`/`"/bin/sh"` aren't directly reachable in the binary, call them **inside libc**:
1. Get libc's base address (defeat ASLR): leak a GOT entry (e.g. `puts` via a `puts(puts@got)` ROP call, or a format-string `%s` read, lesson 02).
2. Compute `system = libc_base + offset(system)` and `binsh = libc_base + offset("/bin/sh")` using the target's libc (`nm -D`, or known offsets for that libc version).
3. Build the same `&system | &exit | &binsh` frame with the libc addresses.

If ASLR is off on the box, you can skip the leak and hardcode libc addresses from gdb — but *say so* and show how you read them.

## Stack pivot

Sometimes the overflow only gives you a few bytes past EIP — not enough room for a chain. **Pivot** ESP to memory you fully control (a buffer elsewhere, e.g. a global or the heap where you staged the chain):
- Put the chain in the controllable buffer.
- Overwrite EIP with a `pop <reg>; ret` to set a register, or use `leave; ret` / `xchg <reg>,esp; ret` / `mov esp, <reg>; ret` to move ESP onto your staged chain.
- `leave` = `mov ebp,esp ; pop ebp`; if you control saved EBP, a second `leave;ret` can relocate the frame — a classic pivot.

## i386 gotchas

- Every chain entry is a **4-byte little-endian address**. A wrong count of `pop`s desynchronizes the whole chain.
- **Null bytes**: if the overflow is via `strcpy`, addresses with `0x00` bytes truncate the chain — pick gadgets/addresses without nulls, or switch to a `read()`-based overflow that tolerates nulls.
- Keep ESP **16-byte-ish sane** if you call into modern libc (older RainFall libc is forgiving, but note it).
- gdb-vs-shell drift matters only for *stack* addresses; PLT/gadget addresses in the binary are stable.

## Questions to ask yourself

- Did I confirm NX is on (so ROP is required, not shellcode)?
- Does the binary already import/contain `system` and `"/bin/sh"` (ret2plt), or must I go into libc (ret2libc + leak)?
- For each call in my chain, is the cdecl frame right: `func | ret-slot | args…`, with a `pop;ret` between calls to clean args?
- Do any of my addresses contain null bytes that my copy primitive can't carry?
- If space is tight, do I need a pivot — and do I control the memory I'm pivoting onto?
- Can I single-step the `ret` chain in gdb and watch ESP walk exactly through my addresses?

## Defensive takeaway

NX alone doesn't stop ROP — you also want **ASLR + PIE** (randomize the code you'd chain), **Full RELRO** (lock the GOT), and a **stack canary** (stop the overflow that starts it all). Layered mitigations are the point.
