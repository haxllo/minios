# MiniOS Bootstrap Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create an initial repo scaffold for a stable custom desktop distribution workflow.

**Architecture:** Use Ubuntu 22.04 as stable base, Xorg session path, and lightweight session components (Openbox, Tint2, Plank, Rofi, Picom). Provide scripts for install, session setup, and ISO build.

**Tech Stack:** Bash, live-build, Openbox session stack.

---

### Task 1: Create project scaffold and docs

**Files:**
- Create: `README.md`
- Create: `docs/architecture.md`
- Create: `docs/hardware/gt720-profile.md`
- Create: `.gitignore`

**Step 1: Write the failing test**

Check missing files:

```bash
test -f README.md && test -f docs/architecture.md && test -f docs/hardware/gt720-profile.md
```

**Step 2: Run test to verify it fails**

Run: `bash -lc 'test -f README.md && test -f docs/architecture.md && test -f docs/hardware/gt720-profile.md'`
Expected: FAIL before files exist.

**Step 3: Write minimal implementation**

Add the missing files with purpose, architecture, and hardware profile guidance.

**Step 4: Run test to verify it passes**

Run: `bash -lc 'test -f README.md && test -f docs/architecture.md && test -f docs/hardware/gt720-profile.md'`
Expected: PASS.

**Step 5: Commit**

```bash
git add README.md docs/architecture.md docs/hardware/gt720-profile.md .gitignore
git commit -m "chore: bootstrap docs and repository structure"
```

### Task 2: Add install and setup scripts

**Files:**
- Create: `scripts/install_base.sh`
- Create: `scripts/setup_session.sh`
- Create: `scripts/minios-session.sh`
- Create: `scripts/check.sh`

**Step 1: Write the failing test**

```bash
bash -n scripts/install_base.sh scripts/setup_session.sh scripts/minios-session.sh scripts/check.sh
```

**Step 2: Run test to verify it fails**

Run: same command before scripts exist.
Expected: FAIL with missing file errors.

**Step 3: Write minimal implementation**

Create scripts with strict shell mode and clear output.

**Step 4: Run test to verify it passes**

Run: `bash -n scripts/install_base.sh scripts/setup_session.sh scripts/minios-session.sh scripts/check.sh`
Expected: PASS.

**Step 5: Commit**

```bash
git add scripts/
git commit -m "feat: add base install and session setup scripts"
```

### Task 3: Add config templates and ISO build script

**Files:**
- Create: `scripts/build_iso.sh`
- Create: `config/picom/picom.conf`
- Create: `config/tint2/tint2rc`
- Create: `config/rofi/config.rasi`
- Create: `config/openbox/rc.xml`
- Create: `config/openbox/menu.xml`
- Create: `config/session/minios.desktop`
- Create: `Makefile`

**Step 1: Write the failing test**

```bash
find config -type f | wc -l
```

**Step 2: Run test to verify it fails**

Run before files exist.
Expected: low count / missing paths.

**Step 3: Write minimal implementation**

Add baseline configuration templates and `live-build` script.

**Step 4: Run test to verify it passes**

Run:

```bash
bash -n scripts/build_iso.sh
make check
```

Expected: PASS for script syntax checks.

**Step 5: Commit**

```bash
git add config/ scripts/build_iso.sh Makefile
git commit -m "feat: add session config templates and iso build script"
```
