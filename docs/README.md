# RainFall — Study Guide & Review Harness

This `docs/` folder is your learning companion for the RainFall project: concept lessons per vulnerability class, and a review rubric that holds each level folder to the eval bar. It teaches **method**, not answers — every real offset/address/flag you derive yourself on the VM.

## How we work each level (concept up front → attempt → review)

1. **Concept briefing** — before you start a level, read the matching lesson(s) below; I give a short briefing tailored to that level's vuln class (technique + what to look for, *no* offsets/payload).
2. **You attempt it** — hands-off. You do recon and build the exploit on the VM yourself, because the eval requires the reasoning to be *yours* and automation tools are an automatic fail.
3. **I review** — you paste your `gdb` evidence and `walkthrough.md` draft; I run [`REVIEW.md`](REVIEW.md), challenge any weak justification, and we iterate until the folder passes.

New level folders are created **one at a time as we reach them**, from the template in [`REVIEW.md`](REVIEW.md).

## Lessons

| Lesson | Topic | Levels it covers |
|---|---|---|
| [`lessons/00-toolkit.md`](lessons/00-toolkit.md) | Recon loop, i386/stack/cdecl fundamentals, gdb, checksec, payload delivery | **all** |
| [`lessons/01-stack-overflow.md`](lessons/01-stack-overflow.md) | Overflow a variable / saved return address | level0, level1, level2, level9 |
| [`lessons/02-format-string.md`](lessons/02-format-string.md) | `%x` reads, `%n` arbitrary write, variable/GOT overwrite | level3, level4, level5, level8, bonus0 |
| [`lessons/03-rop-nx.md`](lessons/03-rop-nx.md) | ROP, PLT/GOT, ret2plt / ret2libc, stack pivot (beats NX) | level6, level9 |
| [`lessons/04-shellcode.md`](lessons/04-shellcode.md) | Shellcode injection, NOP sled, return-address hunting | level7 |
| [`lessons/05-heap.md`](lessons/05-heap.md) | Heap overflow, double-free/fastbin dup, uninitialized read | bonus1, bonus2, bonus3 |

> The vuln→level mapping follows the roadmap in the top-level [`README.md`](../README.md). Treat that roadmap's specific flags/offsets as **placeholders to verify**, not answers — the real values come from the binary on the VM.

## Review

- [`REVIEW.md`](REVIEW.md) — the per-level folder template and the checklist we hold every level to (structure, `source.c`, `walkthrough.md`, bonus rules), plus the subject's hard rules (yours-only reasoning, no automation, no binaries, no root/bruteforce, bonus needs a perfect mandatory).

## The non-negotiables (from `subject/en.subject.pdf`)

- Justify **every** step yourself — the eval is a live human review.
- **Automation tool = -42.** Analysis tools are fine; auto-solvers are not.
- **No binaries** in the repo; **no root**; **no bruteforcing** passwords.
- The `flag` file may be empty *if* you can explain why.
- **Bonus is only assessed if the mandatory part is perfect.**
