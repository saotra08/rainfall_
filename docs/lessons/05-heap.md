# Lesson 05 — Heap Exploitation (overflow, double-free, uninitialized read)

> Maps to **bonus1, bonus2, bonus3**. Prereq: lessons 00–02. Reminder: **bonus is only graded if the mandatory part is perfect.**

The heap is harder to reason about than the stack because layout depends on allocation *history* and allocator internals. RainFall uses an old glibc **ptmalloc/dlmalloc**, so classic (pre-hardening) techniques apply. Slow down and draw the heap.

## Heap & chunk basics (ptmalloc, 32-bit)

`malloc(n)` returns a pointer to a **chunk**. Each chunk has a small header just *before* the returned pointer:

```
chunk:
  [ prev_size (4) ][ size (4) | flags ]   ← header (8 bytes on 32-bit)
  [ user data ... returned pointer here ] ← malloc gives you THIS address
```
- `size` is 8-aligned; its low 3 bits are flags (`PREV_INUSE` = bit 0). So a request of 12 bytes → chunk size `0x18`ish with `PREV_INUSE` set (`0x19`).
- **Freed** small chunks go on **bins** (free lists). **fastbins** are singly-linked LIFO lists for small sizes; a freed fastbin chunk stores a **fd** (forward pointer) to the next free chunk in its *user data* area.
- Adjacent allocations are usually contiguous, so **overflowing one chunk writes into the next chunk's header/data**.

Inspect with gef/pwndbg: `heap chunks`, `heap bins`, `x/16wx <chunk>`. Watch the heap evolve as you allocate/free.

## Technique A — Heap buffer overflow (bonus1)

A `strcpy`/`memcpy` into a heap buffer with no bound, same root cause as lesson 01 but on the heap. What you can clobber:
- **The next chunk's data** — if that chunk holds a **function pointer**, a length, a flag, or a struct the program later trusts/calls, overwrite it. This is the cleanest heap exploit: overflow chunk A into chunk B's function pointer, program calls B's pointer → your target (a `win`, `system`, or shellcode address).
- **The next chunk's header** (`size`/`prev_size`) — sets up allocator-level attacks (harder; only if there's no easier pointer to hit).

Method: allocate the objects, find the **distance** from your buffer to the target field (read the struct usage in the `gdb` disassembly + `heap chunks` in gdb), overflow exactly that many bytes, then place your target value. Confirm with `x/wx &target_field` before triggering the call.

## Technique B — Double free / fastbin dup (bonus2)

Freeing the same chunk twice (or free + use) corrupts the fastbin list. Old glibc has **no tcache and weak double-free checks**, so the classic **fastbin dup**:

1. `a = malloc(sz); b = malloc(sz);`
2. `free(a); free(b); free(a);` → fastbin list becomes `a → b → a` (a points to itself in the cycle).
3. `malloc(sz)` returns `a`; now **write a fake fd** into a's user data pointing at a target address (minus the header offset) whose `size` field passes the fastbin size check.
4. Subsequent `malloc`s hand back `b`, then `a` again, then finally **your target address** as a chunk → arbitrary write there (overwrite a GOT entry, `__malloc_hook`/`__free_hook`, a saved return address, or a function pointer).

The fiddly part is the **size-field sanity check**: the fake target must have a dword that looks like a valid fastbin size for that bin. Hunt for a nearby "fake size" (a common trick targets `__malloc_hook - 0x…` where surrounding bytes form a usable size). Justify the address arithmetic explicitly.

> If the level exposes an interactive `malloc/free/edit` menu, model each option as an allocator primitive (allocate / free / write) and plan the sequence on paper first.

## Technique C — Uninitialized heap read / use-after-free leak (bonus3)

`malloc` does **not** zero memory (only `calloc` does). A freshly `malloc`'d chunk still contains **whatever the previous user left** — including freed pointers (heap/libc addresses) sitting in old `fd`/`bk` fields or leftover data. If the program **prints** an uninitialized buffer, you get a **leak**:

- Free a chunk that contained a heap or libc pointer, `malloc` the same size back, and read the field the program prints → **defeat ASLR** (learn the heap base or a libc address).
- Or exploit a logic path where an uninitialized length/flag controls a copy, turning the leak into a write.

Method: engineer the allocation history so the interesting pointer lands exactly in the bytes the program reads back, capture the leak, compute the base, then pivot to a write (Technique A/B) using the now-known addresses.

## i386 heap gotchas

- **8-byte alignment & 8-byte header** on 32-bit — offsets differ from 64-bit tutorials (which assume 16). Recompute, don't copy.
- **`PREV_INUSE` and other flag bits** live in the low bits of `size`; mask them (`& ~7`) when reading a size.
- The **returned pointer is 8 bytes past the chunk start** — when you craft a fake chunk to be handed out, your target address must be `real_target - 8` so the user pointer lands on `real_target`.
- Allocator behavior depends on **history**: reproduce the exact malloc/free order every time, or your offsets shift.
- Old glibc = fewer checks than modern; techniques from current CTF writeups may be *over*-complicated for this box. Try the simple version first.

## Questions to ask yourself

- Draw the heap: what chunks exist, in what order, and where is the field I want to hit relative to my controllable buffer?
- Is there a **function pointer / struct** in an adjacent chunk I can overwrite (Technique A) before resorting to allocator metadata attacks?
- For a double-free: what's the exact malloc/free sequence, and what fake **size** makes my target pass the fastbin check?
- For a leak: which allocation history places the pointer I want into the bytes the program prints?
- Did I verify each intermediate state in gdb (`heap chunks`, `heap bins`, `x/wx`) rather than assuming?
- Once I have a write primitive, what's the highest-value target (GOT / hook / return address / function pointer)?

## Defensive takeaway

Use `calloc` (zeroes memory) or explicitly initialize; bound every heap copy; never `free` twice / never use after free; and rely on modern allocator hardening (tcache double-free detection, safe-linking) — but the primary fix is the same discipline as the stack lessons: **bounds + lifetimes**.
