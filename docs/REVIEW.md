# Review Rubric & Folder Template

The bar every level folder must clear **before it counts as done**. Derived directly from `subject/en.subject.pdf`. Use it two ways: as a template when you *start* a level, and as a checklist when I *review* your finished folder.

The subject's non-negotiables, up front:
- **The reasoning must be YOURS.** You have to justify every step, live, to a human evaluator.
- **Automation tool = cheating = -42.** Analysis tools (`gdb` — our debugger *and* disassembler — plus `nm`, `strings`, `checksec`, `ltrace`, `ropper`/`ROPgadget` for *locating* gadgets) are fine. A framework that auto-solves the level is not.
- **No binary anywhere in the repo.** Not in the level folder, not in `Ressources/`.
- **No bruteforcing** the ssh passwords. **No becoming root** (bonus explicitly: root = cheating).
- **Bonus is graded only if the mandatory part (level0–level9) is perfect** and works without malfunction.

---

## Per-level folder template

Create each level folder **only when you reach that level** (never mass-scaffold). Mirror `level0/`:

```
levelX/
├── source.c              # the binary reconstructed in a language any dev understands
├── walkthrough.md        # every step of the exploit, with evidence
├── flag                  # the captured .pass (may be empty if you can explain why)
└── Ressources/           # ← exact spelling: capital R, double-s (matches the subject)
    └── pass              # the captured password file (proof); no binaries here, ever
```

> **Naming:** the subject's own `ls` shows files named `source` / `walkthrough` / `flag` (no extension) and a `Ressources` folder. This repo keeps `source.c` / `walkthrough.md` for readable diffs and GitHub rendering — that's an accepted convention, but be aware of the literal-subject naming and be ready to explain the choice. The **folder** must be exactly `Ressources`.

### `walkthrough.md` section skeleton (fill top-to-bottom)

```markdown
# levelX — <vuln class>

## 1. Recon
- ls -la (ownership, setuid bit), file, checksec  →  paste output
- nm / gdb `disas <func>` of the relevant function →  paste the key lines
- What does the program do with my input? (ltrace) →  paste

## 2. Vulnerability
- The exact bug (function, buffer size vs copy length / format string / free / etc.)
- Why it's exploitable here; which mitigation is absent (from checksec)

## 3. Exploit construction
- The measurement: offset / parameter index / chunk offset  → show the arithmetic
- The confirmation: the gdb evidence that the measurement is exact (EIP=0x42424242, %x ruler, x/wx, ...)
- The payload, byte by byte, each piece justified (addresses little-endian, why this target)

## 4. Capture
- The command run, whoami == levelX+1, cat /home/user/levelX+1/.pass, su levelX+1

## 5. Justification notes
- Every magic number traced to its source (disasm address, gdb read, struct layout)
- Env/gdb-vs-shell drift handling, null-byte handling, anything non-obvious
```

---

## Review checklist

### A. Structure & hygiene
- [ ] Folder is `levelX/` (or `bonusX/`) with `source.c`, `walkthrough.md`, `flag`, `Ressources/pass`.
- [ ] Proof folder spelled exactly **`Ressources`** (not `ressources`, not `Resources`).
- [ ] **No binary files** anywhere in the folder (`file` every file; nothing ELF).
- [ ] `flag` holds the captured `.pass`, **or** is intentionally empty *and* the walkthrough explains why.
- [ ] Chain consistency: `levelN/flag` content == `levelN+1/Ressources/pass` content.

### B. `source.c` (the reconstruction)
- [ ] Reflects the **actual** disassembled behavior (not a guess) — buffer sizes, comparisons, calls match the `gdb` disassembly.
- [ ] Readable by any developer; the vulnerable construct is visible in the source.
- [ ] No invented functions/behavior that isn't in the binary.

### C. `walkthrough.md` (the reasoning — this is what the eval grades hardest)
- [ ] `checksec` result stated, and the chosen technique is **justified by** those mitigations (e.g. "NX off → shellcode", "NX on → ROP").
- [ ] The **offset / parameter index / chunk offset is derived AND confirmed** — arithmetic shown *and* a gdb confirmation, not just one or the other.
- [ ] **Every address** (return target, PLT/GOT, gadget, "/bin/sh", variable) is traced to where it came from (`gdb`/`nm` line). No unexplained magic numbers.
- [ ] Payload layout is explained piece-by-piece; endianness correct; null-byte constraints addressed.
- [ ] Reproducible: someone following the steps on the VM gets the same flag.
- [ ] No pasted output from an auto-exploitation framework standing in for reasoning.
- [ ] You can explain it **without the notes** — the ultimate test.

### D. Bonus-specific
- [ ] Mandatory part is fully complete and non-malfunctioning first (else bonus isn't assessed at all).
- [ ] No root, no bruteforce.

---

## How I review (the loop)

1. You tell me the level and paste your recon + walkthrough draft (and the `source.c`).
2. I run this checklist, flag any weakly-justified number, and ask you the "explain it without notes" questions from the matching `docs/lessons/` primer.
3. We iterate until every box is checked. Only then is the folder "done."

I will **not** fill in real offsets/addresses/flags for you — that would fail the "YOURS ONLY" rule and rob you of the eval prep. I confirm, challenge, and point; you derive.
