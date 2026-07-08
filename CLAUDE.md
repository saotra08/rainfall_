# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is a write-up / tooling repo for **RainFall**, the 42 school binary-exploitation project (i386 / 32-bit ELF, CTF-style privilege escalation). It is **not** a buildable software project.

The single most important fact: **the vulnerable binaries do not live in this repo.** They exist only on a remote target VM (an old 32-bit Linux at `TARGET_IP:4242`). The `.c` files under `levelX/`/`bonusX/` are **reconstructions** of each binary's source from disassembly (`gdb`'s `disas`, `nm`), written by hand for documentation — they are not compiled and are not the ground truth. The subject explicitly forbids storing binaries here (see `README.md` → "The `Resources/` folder must NOT contain any binary files").

The actual work happens over SSH on the VM: analyze a setuid binary, exploit it to read `/home/levelX/.pass`, `su` to the next user, repeat. This repo captures the *evidence and reasoning* (source reconstruction, walkthrough, captured password).

## Environment / harness commands

The repo ships a Docker container that only exists to give you `ssh` + `sshpass` pre-wired to the VM.

```bash
cp .env.example .env      # then edit .env: set TARGET_IP to the VM's IP (find it via `ifconfig` on the VM)
make all                  # build image `rainfall:42` and drop into an interactive shell in the container
make exec                 # open another shell in the already-running container (name: rainfall42)
make re                   # fclean + all (full rebuild)
make fclean               # docker system prune -af  (destructive: nukes all unused docker data)
```

From inside the container, connect with the SSH shortcuts defined in `ssh/config` (host aliases `l0`–`l9` for levels, `b0`–`b3` for bonuses):

```bash
ssh l0                    # = level0@$TARGET_IP -p 4242 ; password for level0 is "level0"
```

`entrypoint.sh` runs at container start: it substitutes `TARGET_IP` into `/root/.ssh/config` and creates convenience symlinks. There is no build/lint/test suite — "running" this project means the Docker + SSH flow above.

## Per-level folder convention

Each solved level gets its own folder (`level0/` … `level9/`, `bonus0/` … `bonus3/`) containing:

- `source.c` — reconstructed source of the binary
- `walkthrough.md` — step-by-step exploitation, with pasted `gdb` output and reasoning
- `flag` — the captured `.pass` password for that level (= the *next* user's login password)
- a `Ressources/` subfolder holding `pass` (the captured password file), plus notes

The password captured from `levelN` **is** the login password for `levelN+1`, so `levelN/flag` == `levelN+1/Ressources/pass`.

### Canonical proof-folder name (resolved)

The proof folder is **`Ressources`** (capital R, double-s). This is the spelling used by the subject's own `ls -alR` example (`en.subject.pdf`, Mandatory part), so it is the ground truth for grading. `level0/` and `level1/` and `entrypoint.sh` and `README.md` have all been aligned to it. When you create a new level folder, use exactly `Ressources/` — do not reintroduce `ressources` (lowercase) or `Resources` (single-s).

## Current state

Only **level0** and **level1** folders exist. level0 is fully documented (source, walkthrough, captured flag). level1 is scaffolded but `walkthrough.md` and `flag` are still empty and `source.c` is a stub. `README.md` documents the full roadmap and per-level approach for all levels/bonuses ahead of time — treat those as *plans*, not completed work, and verify against the VM before trusting offsets/addresses/flags listed there.

## Project constraints (from the subject — these are grading rules, honor them)

- **No binaries in the repo.** Keep them on the VM only.
- **Do not bruteforce SSH passwords** and **do not become root** — both are explicitly treated as cheating/failure.
- **Do not use automated exploitation tools** to solve the levels — walkthroughs must reflect your own reasoning. (Analysis tools like `gdb` — used as both debugger and disassembler — plus `nm`, `strings`, `checksec`, `ropper` are fine.)
- Every offset, gadget, and address in a walkthrough must be justifiable; the eval requires explaining each step.

## Working on this repo

When helping with a level, the typical loop is: SSH in → analyze the binary on the VM → identify the vuln (stack overflow, format string, heap, ROP, shellcode — see the roadmap table in `README.md`) → craft/trigger the exploit → `cat` the next `.pass` → write up `source.c` + `walkthrough.md` + `flag` in the level folder. Payloads target **32-bit x86**, so use little-endian 4-byte addresses and 32-bit calling conventions (args on the stack).

**Tooling conventions (keep consistent across all files):** use `gdb` as **both** debugger and disassembler (e.g. `gdb -q ./bin -batch -ex 'disas main'`) — do **not** use `objdump`. Build and deliver payloads with **shell** (`printf` for raw bytes, `head -c N /dev/zero | tr '\0' 'X'` for repeats), **not** python/pwntools. The reusable shell payload cookbook lives in `docs/lessons/00-toolkit.md` §6.

## Teaching & review workflow (how to help the user)

The user is a learner doing this for a graded 42 eval, so the support model is **concept up front → hands-off attempt → review after**:

1. **Before a level** — give a concept briefing tailored to that level's vuln class. Point at the matching primer in `docs/lessons/`. Explain the *technique* and what to look for; do **not** hand over the offsets/addresses/payload.
2. **During** — stay hands-off. The user does recon and builds the exploit on the VM themselves (the eval requires the reasoning to be *theirs*, and automation tools are an automatic fail).
3. **After** — the user pastes their `gdb` evidence and walkthrough draft; review it against `docs/REVIEW.md`, challenge any weakly-justified offset/gadget, and iterate until the folder passes.

**Spoiler discipline:** never commit real per-level offsets, addresses, or flags on the user's behalf — they capture and paste those; you review. Committed lessons/templates teach transferable method only. New level folders are created **one at a time as they're reached**, using the template in `docs/REVIEW.md` (never mass-scaffolded).

See `docs/README.md` for the lesson → level → rubric index.

Note: `.gitignore` excludes `AGENTS.md` and `*.env` (keep real target IPs out of git; `.env.example` is the committed template).
