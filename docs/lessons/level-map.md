# Level Map — Breach & Technique per Level

Orientation for the whole project: the **breach** (bug class) and the **technique family** for each level, with what to look for during recon. This is a map, **not** a solution key — it names *categories*, never offsets, addresses, symbol names, or payloads. Those you derive yourself on the VM (the eval grades exactly that reasoning).

> **Confirm everything on the VM.** This supersedes the placeholder specifics in the top-level [`README.md`](../../README.md) roadmap (some were inaccurate guesses). Knowing the class doesn't solve the level — *which* target, *which* index/offset, and the byte-level construction are still yours.

## Mandatory

| Level | Breach (bug class) | Technique | What to look for | Lesson |
|---|---|---|---|---|
| **0** | Trivial argument check | Pass the expected value — the program spawns the shell itself | An `atoi`/`strcmp` of `argv[1]` against a constant | [00](00-toolkit.md) |
| **1** | Stack overflow (`gets`, no bound) | Overwrite the saved return address → jump to an existing shell-spawning function, or inject shellcode (NX off) | A function that `main` never calls; buffer size vs `gets` | [01](01-stack-overflow.md) / [04](04-shellcode.md) |
| **2** | Stack overflow **+ a naive return-address check** | The filter blocks returning onto the stack → run shellcode from a *non-stack* region (the copy the program makes) or ret2libc | Where your input is duplicated, and the `cmp` on the saved return address | [01](01-stack-overflow.md) |
| **3** | Format string (`printf(user)`) | `%n` write to a global that a later check compares | A global compared to a constant right after the `printf` | [02](02-format-string.md) |
| **4** | Format string (indirect / via a wrapper) | Same `%n` write, but a **large** target value → width padding / byte-wise writes | The required constant (it's big) | [02](02-format-string.md) |
| **5** | Format string | **GOT overwrite** — redirect a function called after the `printf` to a hidden shell function | Which libc call happens after `printf`; a function never normally reached | [02](02-format-string.md) |
| **6** | Heap overflow (`strcpy` into an undersized chunk) | Overflow into an adjacent heap **function pointer** and repoint it | Two `malloc`s where one holds a function pointer | [05](05-heap.md) |
| **7** | Heap overflow → **arbitrary write** | Corrupt a second struct's pointer used as a `strcpy` destination → write a GOT entry to a hidden function | Two `{buffer, pointer}` structs and a `strcpy(dest, src)` where you control `dest` | [05](05-heap.md) |
| **8** | Logic / heap-adjacency bug (command interface) | Manipulate allocations so an "authenticated" field is non-zero, then the login command runs a shell | How the `auth` and `service` buffers overlap in memory | [05](05-heap.md) |
| **9** | C++ object overflow (buffer before a **vtable pointer**) | Overwrite the vtable pointer so the next virtual call jumps to your data/shellcode (NX off) | A class with a `char` buffer + a virtual method; the copy that overflows it | [01](01-stack-overflow.md) / [04](04-shellcode.md) |

## Bonus

> Graded **only if the mandatory part is perfect**. The last user is `end`. No root, no bruteforce.

| Level | Breach (bug class) | Technique | What to look for | Lesson |
|---|---|---|---|---|
| **0** | Stack overflow via a custom input routine that concatenates two reads | Overflow the saved return address → shellcode / existing function | The read helper's size handling and the separator | [01](01-stack-overflow.md) |
| **1** | **Signed/unsigned integer bug** | An `atoi` result used as a `memcpy` length after a *signed* bound check; a negative value passes but is huge unsigned → controlled overflow | The sign of the comparison vs `memcpy`'s `size_t` | [01](01-stack-overflow.md) |
| **2** | Stack overflow, size influenced by `LANG` env var | Overflow saved EIP → shellcode; account for the locale-dependent offset | `getenv("LANG")` and the greeting concatenation | [01](01-stack-overflow.md) |
| **3** | Logic bug (`atoi`-indexed comparison) | A crafted/empty `argv` zeroes the compare index → the pass check passes and it prints | The `atoi`-derived index into the `.pass` comparison | [00](00-toolkit.md) |

## Using this without shortcutting the eval

The **class** and **technique family** are orientation only. The graded work is still yours: *which* GOT entry / function / vtable, the parameter index, the width math, the exact offset — each traced to your own `gdb`/`nm` evidence. Read the matching lesson, do recon on the VM, then bring your findings and draft for review against [`REVIEW.md`](../REVIEW.md).
