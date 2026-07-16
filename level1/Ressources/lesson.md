# level1 — Stack Buffer Overflow (guided lesson)

> Companion to [../../docs/lessons/01-stack-overflow.md](../../docs/lessons/01-stack-overflow.md). Prereq: [../../docs/lessons/00-toolkit.md](../../docs/lessons/00-toolkit.md).
>
> This lesson teaches you **how to think about level1** and the exact recon → confirm → deliver loop.
> It deliberately contains **no real offset, address, payload, or flag** — you derive and `gdb`-confirm
> every real value yourself on the VM. That is both the 42 spoiler discipline *and* the whole point of
> the eval: the reasoning has to be yours.

---

## 1. What you're up against

From your own recon (`level1/walkthrough.md`) you already know:

- The binary is **SUID `level2`** (`-rwsr-s--- ... level2 ...`). Whatever code you get it to run, it runs
  **as `level2`** — that is how you read `level2`'s `.pass`.
- `checksec` says: **No stack canary · NX disabled · No PIE** (and ASLR is off on the box).
- It reads your input with **`gets()`** — a function with *no bound at all*.

Read the mitigations as an attack menu — each *absent* protection unlocks a technique:

| Missing mitigation | What it means for you |
|---|---|
| **No canary** | Nothing sits between the buffer and the saved return address to detect the overwrite. You can smash EIP freely. |
| **NX disabled** | The stack is **executable** — bytes you place on the stack can be *run as code* (shellcode is on the table). |
| **No PIE / ASLR off** | Code and stack addresses are **stable and predictable** run-to-run, so a hardcoded address in your payload stays valid. |

That combination (unbounded read + no canary + executable, predictable stack) is the easiest possible
overflow environment. Every door is open; your job is to *measure* precisely.

## 2. The bug

`gets(buf)` keeps copying stdin into `buf` until a newline, with **no idea how big `buf` is**. Send more
bytes than `buf` holds and the write spills past it, up the stack into the slots at higher addresses:

```
lower addr
┌───────────────────────────┐  <- buf starts here
│   buf  (fixed size N)      │   you control these...
├───────────────────────────┤
│   ... other locals ...     │   ...and these...
├───────────────────────────┤
│   saved EBP   (4 bytes)    │   ...and this...
├───────────────────────────┤
│   saved EIP / ret  (4 B)   │   <- overwrite this and you choose where the function returns
└───────────────────────────┘
higher addr
```

By choosing *what lands in which slot*, you steer the program. There are two shapes this can take — and
**recon on the VM tells you which one level1 actually is.** Don't assume; look.

## 3. Two shapes — figure out which one you're looking at

### Shape (a): overwrite a checked variable / flag

Sometimes there is a local (or global) variable that the program **tests after** the `gets()` — e.g.
`if (var == SOME_MAGIC) { ...win... }`. Because the overflow runs *through* that variable's slot before
it reaches EIP, you can set it to whatever the check wants.

- **How to spot it in `disas main`:** a `cmp`/`test` against a constant *after* the input call, guarding
  the interesting branch (a `system`, an `execl`, a "you win" path). A recognizable magic constant
  (values like `0xdeadbeef` are a classic tell) is a strong hint you're in shape (a).
- **What you build:** `padding-to-reach-the-variable` + `little-endian(magic value)`. You may not even
  need to touch EIP.

### Shape (b): overwrite the saved return address (EIP)

If the win is a **function `main` never calls** (a `run` / `callsystem` / shell-spawning helper), or if
there's simply no data check to satisfy, you take over EIP directly.

- **How to spot it:** `nm ./level1` and `gdb disas` reveal a function that spawns a shell / prints a
  "wait, what?" message but is **never referenced from `main`**. That dangling function is your target.
- **Two ways to use EIP once you control it:**
  - **ret2func** — set the saved return address to that existing function's address. Simplest, no shellcode.
  - **shellcode** — because **NX is off**, lay a NOP sled + your shellcode on the stack and set EIP to
    land somewhere in the sled. This is the technique from
    [../../docs/lessons/04-shellcode.md](../../docs/lessons/04-shellcode.md); use it if there's no
    convenient function to jump to.

> Heads-up: this repo's top-level `README.md` sketches level1 one way and `docs/lessons/` sketches it
> another. **Neither is authoritative** — the binary on the VM is. Let your `disas main` decide between
> shape (a) and shape (b), and ignore any pre-written offset/address until you've reproduced it yourself.

## 4. The method (this is the graded part)

Same loop every time — arithmetic **and** a gdb confirmation, never one without the other:

1. **Recon.** `ls -la` (ownership + SUID bit), `checksec --file ./level1`, then read the code:
   ```sh
   gdb -q ./level1 -batch -ex 'set disassembly-flavor intel' -ex 'disas main'
   nm ./level1        # look for an unreferenced win/shell function (shape b)
   ```
   Note the buffer's distance from `%ebp` (from the `lea -0xNN(%ebp),...` feeding `gets`) and the
   prologue's `sub $0xNN,%esp`.

2. **Compute the offset by arithmetic.** Distance from the buffer to the target slot. For the *saved
   return address* it's `buffer_distance_from_ebp + 4` (the +4 skips saved EBP). For a *checked variable*
   it's the buffer-to-variable distance. **Show this arithmetic** in your walkthrough.

3. **Confirm the offset in gdb — do not trust the arithmetic alone.** Padding, `and $0xfffffff0,%esp`
   alignment, and compiler quirks shift it. Send a marker and watch where it lands:
   ```sh
   # send N filler bytes then a 4-byte marker; N is your computed offset
   { head -c N /dev/zero | tr '\0' 'A'; printf 'BBBB'; } > /tmp/p
   gdb -q ./level1
   (gdb) run < /tmp/p
   # if you nailed the offset, EIP == 0x42424242 ('BBBB'). If not, adjust N and repeat.
   ```
   For shape (a), instead confirm with `x/wx &the_variable` that your bytes reached it.

4. **Build & deliver the payload with shell only** (no python/pwntools — that's an auto-fail here). The
   cookbook is [../../docs/lessons/00-toolkit.md](../../docs/lessons/00-toolkit.md) §6. The moving parts:
   - **Padding:** `head -c N /dev/zero | tr '\0' 'A'`
   - **Addresses are little-endian, byte-reversed.** Example of the *encoding only* (not level1's value):
     an address `0x08048abc` is written `printf '\xbc\x8a\x04\x08'`. Reverse the four bytes, always.
   - **Concatenate** with a brace group so the pieces join:
     ```sh
     { head -c N /dev/zero | tr '\0' 'A'; printf '<4 little-endian bytes>'; } > /tmp/p
     ./level1 < /tmp/p           # or  ./level1 "$(cat /tmp/p)"  if it reads argv
     ```
   - **Watch the edges:** a stray trailing newline, and **null bytes** — `gets` stops at newline (`0x0a`)
     but a `0x00` in an address can truncate other delivery methods; know which one you're using.
   - **gdb-vs-shell stack drift:** if your payload needs a *stack* address (shape b/shellcode), the stack
     is at a slightly different address under `gdb` than under a bare shell (different `argv`/`env`).
     Confirm the working address in the *real* run, or use a NOP sled wide enough to absorb the drift.

5. **Keep stdin open** if you want the spawned shell to stay interactive:
   ```sh
   cat /tmp/p - | ./level1
   ```

## 5. Capture (the payoff)

Once the payload lands, you're a shell running as `level2`:

```sh
whoami                          # -> level2
cat /home/user/level2/.pass     # this string is level2's login password  == level1/flag
su level2                       # log in and move on
```

Put that captured `.pass` into `level1/flag` (it must equal `level2/Ressources/pass` once you create the
level2 folder), and write up your recon + exact offset + address + payload reasoning in
`level1/walkthrough.md`.

## 6. Questions to ask yourself

- What is the **exact** buffer size, and where does the target slot sit relative to it? Can I point at the
  `disas` line that proves it?
- Am I in **shape (a)** (satisfy a data check) or **shape (b)** (hijack EIP)? What evidence?
- If shape (b): is there a function to `ret2` into, or do I need shellcode? Did I account for NX being off?
- Did I **confirm** the offset (EIP `== 0x42424242`, or `x/wx` on the variable) — not just compute it?
- Is every byte of my payload justified, correctly little-endian, and free of a stray newline / bad null?

## 7. Defensive takeaway (the subject's real goal)

`gets()` is unfixable and was removed from C11 — the lesson is to read into a bounded buffer:
`fgets(buf, sizeof buf, stdin)` or `read(fd, buf, sizeof buf)`. Layered on top, a **stack canary**
(`-fstack-protector`) catches the smash before `ret`, **NX** (`-z noexecstack`) stops stack shellcode,
and **PIE + ASLR** randomize the addresses your payload depended on. level1 has *none* of these, which is
exactly why it falls to a single unbounded copy.
