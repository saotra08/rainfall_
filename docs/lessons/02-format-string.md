# Lesson 02 — Format String Bugs

> Maps to **level3, level4, level5, level8, bonus0**. Prereq: lessons 00–01.

## The bug in one line

`printf(user_input)` instead of `printf("%s", user_input)`. When the *format string itself* is attacker-controlled, every `%` directive tells `printf` to fetch and act on an argument — but no real arguments were pushed, so `printf` walks the **stack** as if those slots were its arguments. This gives you an **arbitrary read** (`%x`, `%s`) and, crucially, an **arbitrary write** (`%n`).

Spot it in recon: a `printf`/`fprintf`/`snprintf`/`syslog` whose format argument is the buffer you just supplied (in `ltrace` you'll see `printf("your input")` with no extra format). Compare against a *safe* call `printf("%s", buf)`.

## Reading the stack with `%x`

Because cdecl passes args on the stack, `printf("%x %x %x %x")` prints the 4 dwords sitting above `printf`'s own frame — i.e. your nearby stack. Send a long ruler:

```bash
./levelX "AAAA$(printf '.%%x%.0s' $(seq 20))"        # AAAA followed by 20 × '.%x'
```
Now find where your `AAAA` (`0x41414141`) shows up in the output. If it appears as the **k-th** `%x`, then **stack position k points at the start of your buffer**. That position number `k` is the key to everything that follows.

Shortcut: **direct parameter access** `%k$x` jumps straight to the k-th argument without printing the ones before it:
```bash
./levelX 'AAAA%7$x'                                  # literal arg (single-quoted); if it prints 41414141, k=7
```

## `%n` — turning a read into a write

`%n` writes the **number of characters printed so far** to the address given by that argument slot. So if slot `k` holds an address you control (because it's inside your buffer), then:

```
[ your target address ][ padding that prints N chars ][ %k$n ]
```
writes the value **N** to `*target`. You control N by controlling how many characters `printf` emits before the `%n`.

- To write a **large** value cheaply, use width: `%<N>x` prints N characters. E.g. `%216x` adds 216 to the count.
- To write a **4-byte** value without printing billions of characters, do it **byte-by-byte** with `%hhn` (writes 1 byte) to four consecutive addresses (`target`, `target+1`, `target+2`, `target+3`), increasing the running count to each target byte in turn. `%hn` writes 2 bytes (half-word) — the common "two writes of 16 bits" method.

### The standard 4-byte write recipe (byte-at-a-time, `%hhn`)

1. Put the **four target addresses** at the start of your payload: `target+0, target+1, target+2, target+3` (each little-endian, 4 bytes → 16 bytes total).
2. After them, emit padding so the running character count equals the **lowest** target byte value, then `%<pos>$hhn`. Then more padding up to the next byte value, `%<pos+1>$hhn`, etc.
3. Order the four bytes **ascending by value** so each `%…x` width is a positive increment. If a later byte is *smaller*, wrap around 0x100 (add 0x100) — that's fine for `%hhn` since it only writes the low byte.
4. `pos` is the stack index of your first address word (the `k` you found), and it increments by 1 for each subsequent address word.

Getting the counting exactly right is fiddly — do the arithmetic explicitly in your walkthrough (the eval will ask you to justify every width number). Build it, run under gdb with a breakpoint after the `printf`, and `x/wx target` to confirm the written value **before** relying on it.

## What to overwrite

- **A variable / flag** (level3/bonus0 style): same idea as lesson 01 flavor (a), but the write is *arbitrary-address*, so you don't need contiguous overflow — just aim `%n` at the global's address (`nm | grep`). Often you only need to make it non-zero, which is much easier than a full 4-byte value.
- **A GOT entry** (level8 style — see lesson 03 for GOT background): overwrite the GOT slot of a function that's called *after* your `printf` (e.g. `exit`, or a libc fn) with the address of `system`, a `win` function, or shellcode. When the program calls that function, it jumps to your target instead. Find GOT addresses with `gdb` (gef/pwndbg `got`, or `info functions` / `p &exit`) / `nm`. Full RELRO makes the GOT read-only — check first.
- **Saved return address**: possible but usually harder than a GOT/variable target on these levels.

## `%s` for reads / leaks

`%k$s` treats slot `k` as a `char*` and prints the string there — an **arbitrary read** if you place a target address in your buffer at slot `k`. Useful to leak a canary, a libc address (defeat ASLR), or verify memory. Beware: if the slot holds a non-mapped address, `printf` segfaults.

## i386 gotchas

- **4 bytes per stack slot.** Address words in your buffer each consume one `%…$` position.
- **Alignment of your buffer** affects `k`: if the buffer doesn't start on a slot boundary, prepend 1–3 junk bytes so your addresses land cleanly on positions. Adjust padding so total length stays predictable.
- **Null bytes in addresses**: `printf` stops reading the format string at a `\0`, so you can't put a raw null in the middle of the format. Placing the address *words* at the front (before any `%`) avoids this, since the copy that filled the buffer (often `strdup`/`strcpy`) is what matters, and `printf` reads left-to-right — keep the `%…$hhn` selectors referencing those front slots by index.
- **Character count includes the address bytes** you printed at the front. Factor those into your N.

## Questions to ask yourself

- Is the format string really attacker-controlled? (ltrace: `printf("<my input>")` vs `printf("%s", ...)`.)
- What is my parameter index `k` — where does `0x41414141` surface in the `%x` ruler?
- Am I doing a **partial** write (just make a flag non-zero) or a **full 4-byte** write? Choose the cheapest that works.
- What's the target address, and is it writable (variable/GOT-with-partial-RELRO)?
- Did I verify the written bytes in gdb (`x/wx target`) before trusting the exploit end-to-end?
- Have I accounted for the address bytes at the front of my payload in the `%n` character count?

## Defensive takeaway

Always pass a **constant** format string: `printf("%s", user)`. Compilers warn on this (`-Wformat -Wformat-security`). Note in the walkthrough that the fix is one `"%s",`.
