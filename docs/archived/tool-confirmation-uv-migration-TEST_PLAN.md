# Test Plan — Tool confirmation prompts + uv migration

Manual test plan for the per-tool confirmation prompts introduced in
`03_python.sh`, `04_java.sh`, `05_node.sh`, and `06_ai.sh`, and for the
replacement of pyenv + Poetry with uv.

Each scenario follows the **Given / When / Then** structure.
Unless noted otherwise, execute inside WSL2 (Ubuntu).

Reference: [PLANNING-tool-confirmation-uv-migration.md](PLANNING-tool-confirmation-uv-migration.md)

---

## Execution Sequence

| Run | Environment                        | Scope                                                                             |
| --- | ---------------------------------- | --------------------------------------------------------------------------------- |
| T1  | Fresh Ubuntu WSL2 image            | First install — all confirmations answered Y; Groups P, J, N, AI                  |
| T2  | Same instance, state from T1       | Idempotency — all tools already installed; Groups SK                              |
| T3  | Same instance, after --clean-tools | Tools removed, managers intact — confirmations answered N; Groups P, J, N, AI, SK |
| T4  | Same instance, state from T3       | Re-run after N answers — tools still absent, prompts appear again                 |
| T5  | Pipe invocation (non-interactive)  | curl \| bash — no TTY, all confirmations default to Y; Group NI                   |

**Pre-conditions for all runs:**

- Ubuntu WSL2 distro available (reuse the instance from the main TEST_PLAN Run 3/4)
- 1Password SSH agent active
- Repo cloned at `~/Dev/repos/linux-init-bootstrap` and up to date

---

## Run T1 — Fresh install, all confirmations Y

### Pre-conditions

- `~/.bootstrap-state` does not exist (or modules 03–06 cleared)
- `~/Dev/tools/python`, `java`, `node`, `ai` do not exist

### Command

```powershell
wsl -d Ubuntu-26-test
```

```bash
bash ~/Dev/repos/linux-init-bootstrap/bootstrap.sh --verbose 2>&1 | tee /mnt/c/Users/wellington.nonato/t1-fresh-all-yes.log
```

Answer `Y` (or Enter) to every confirmation prompt.

---

## Run T2 — Idempotency (all tools installed)

### Pre-conditions

- State from T1 intact — all sub-states `complete`

### Command

```bash
bash ~/Dev/repos/linux-init-bootstrap/bootstrap.sh --verbose 2>&1 | tee /mnt/c/Users/wellington.nonato/t2-idempotency.log
```

No prompts expected — all tools already installed.

---

## Run T3 — After --clean-tools, all confirmations N

### Pre-conditions

- Run `bash bootstrap.sh --clean-tools` to remove tool directories and sub-states
- Managers (uv, SDKman, NVM) are also removed by `--clean-tools`

### Command

```bash
bash ~/Dev/repos/linux-init-bootstrap/bootstrap.sh --verbose 2>&1 | tee /mnt/c/Users/wellington.nonato/t3-all-no.log
```

Answer `n` to every confirmation prompt.

---

## Run T4 — Re-run after all-N (prompts must reappear)

### Pre-conditions

- State from T3: managers installed, all tool sub-states `skipped`

### Command

```bash
bash ~/Dev/repos/linux-init-bootstrap/bootstrap.sh --verbose 2>&1 | tee /mnt/c/Users/wellington.nonato/t4-rerun-after-no.log
```

All confirmation prompts must reappear (skipped tools are not marked complete).
Answer `Y` to all to restore the environment.

---

## Run T5 — Non-interactive (pipe invocation)

### Pre-conditions

- Tools removed (run `--clean-tools` before this run)

### Command

```bash
curl -fsSL https://gist.githubusercontent.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959/raw/linux-init-phase3-bootstrap.sh | bash 2>&1 | tee /mnt/c/Users/wellington.nonato/t5-non-interactive.log
```

No stdin available — `_confirm` must default to `Y` for all tools.

---

## Group P — `03_python.sh`: uv + Python LTS confirmation

**Location:** `install/03_python.sh`

**Runs:** T1, T2, T3, T4, T5

### P1–P3: uv manager (always installed, no prompt)

| ID | Given                                  | When        | Then                                                 |
|:--:| -------------------------------------- | ----------- | ---------------------------------------------------- |
| P1 | uv not installed                       | Module runs | uv installed silently, no prompt shown               |
| P2 | uv already installed                   | Module runs | `skip uv <version>` displayed; hint shown; no prompt |
| P3 | uv installed; Python LTS not installed | Module runs | uv skipped; Python LTS prompt appears                |

### P4–P7: Python LTS confirmation

| ID | Given                                                  | When                     | Then                                                                         |
|:--:| ------------------------------------------------------ | ------------------------ | ---------------------------------------------------------------------------- |
| P4 | Python LTS not installed                               | User enters `Y` or Enter | `uv python install` runs; `module_03_python_lts=complete` written to state   |
| P5 | Python LTS not installed                               | User enters `n`          | Install skipped; `module_03_python_lts=skipped` written to state; hint shown |
| P6 | Python LTS installed (`module_03_python_lts=complete`) | Module runs              | `skip Python <version>` + reinstall hint displayed; no prompt                |
| P7 | Python LTS state is `skipped`                          | Module re-runs           | Prompt reappears — skipped state does not suppress the prompt                |

### P8: pyenv and Poetry absent

| ID | Given         | When         | Then                                                            |
|:--:| ------------- | ------------ | --------------------------------------------------------------- |
| P8 | Fresh install | T1 completes | `~/Dev/tools/python/pyenv` does not exist; `poetry` not in PATH |

---

## Group J — `04_java.sh`: SDKman + JDK/Maven/Gradle confirmation

**Location:** `install/04_java.sh`

**Runs:** T1, T2, T3, T4, T5

### J1–J2: SDKman manager (always installed, no prompt)

| ID | Given                    | When        | Then                                                |
|:--:| ------------------------ | ----------- | --------------------------------------------------- |
| J1 | SDKman not installed     | Module runs | SDKman installed; no prompt shown                   |
| J2 | SDKman already installed | Module runs | `skip SDKman` + reinstall hint displayed; no prompt |

### J3–J8: JDK confirmation

| ID | Given                                         | When                     | Then                                                                          |
|:--:| --------------------------------------------- | ------------------------ | ----------------------------------------------------------------------------- |
| J3 | JDK not installed                             | User enters `Y` or Enter | `sdk install java 25.0.3.fx-zulu` runs; `module_04_java_jdk=complete` written |
| J4 | JDK not installed                             | User enters `n`          | Install skipped; `module_04_java_jdk=skipped` written; hint shown             |
| J5 | JDK installed (`module_04_java_jdk=complete`) | Module runs              | `skip Java <version>` + reinstall hint; no prompt                             |
| J6 | JDK state is `skipped`                        | Module re-runs           | Prompt reappears                                                              |

### J7–J10: Maven confirmation

| ID  | Given                    | When                     | Then                                                              |
|:---:| ------------------------ | ------------------------ | ----------------------------------------------------------------- |
| J7  | Maven not installed      | User enters `Y` or Enter | `sdk install maven` runs; `module_04_java_maven=complete` written |
| J8  | Maven not installed      | User enters `n`          | Install skipped; `module_04_java_maven=skipped` written           |
| J9  | Maven installed          | Module runs              | `skip Maven <version>` + reinstall hint; no prompt                |
| J10 | Maven state is `skipped` | Module re-runs           | Prompt reappears                                                  |

### J11–J14: Gradle confirmation

| ID  | Given                     | When                     | Then                                                                |
|:---:| ------------------------- | ------------------------ | ------------------------------------------------------------------- |
| J11 | Gradle not installed      | User enters `Y` or Enter | `sdk install gradle` runs; `module_04_java_gradle=complete` written |
| J12 | Gradle not installed      | User enters `n`          | Install skipped; `module_04_java_gradle=skipped` written            |
| J13 | Gradle installed          | Module runs              | `skip Gradle <version>` + reinstall hint; no prompt                 |
| J14 | Gradle state is `skipped` | Module re-runs           | Prompt reappears                                                    |

### J15: Independent confirmation per tool

| ID  | Given                       | When   | Then                                                                      |
|:---:| --------------------------- | ------ | ------------------------------------------------------------------------- |
| J15 | JDK: Y, Maven: n, Gradle: Y | T1 run | JDK and Gradle installed; Maven skipped; each sub-state written correctly |

---

## Group N — `05_node.sh`: NVM + Node.js LTS confirmation

**Location:** `install/05_node.sh`

**Runs:** T1, T2, T3, T4, T5

### N1–N2: NVM manager (always installed, no prompt)

| ID | Given                 | When        | Then                                             |
|:--:| --------------------- | ----------- | ------------------------------------------------ |
| N1 | NVM not installed     | Module runs | NVM installed; no prompt shown                   |
| N2 | NVM already installed | Module runs | `skip NVM` + reinstall hint displayed; no prompt |

### N3–N6: Node.js LTS confirmation

| ID | Given                          | When                     | Then                                                              |
|:--:| ------------------------------ | ------------------------ | ----------------------------------------------------------------- |
| N3 | Node.js LTS not installed      | User enters `Y` or Enter | `nvm install --lts` runs; `module_05_node_lts=complete` written   |
| N4 | Node.js LTS not installed      | User enters `n`          | Install skipped; `module_05_node_lts=skipped` written; hint shown |
| N5 | Node.js LTS installed          | Module runs              | `skip Node.js <version>` + reinstall hint; no prompt              |
| N6 | Node.js LTS state is `skipped` | Module re-runs           | Prompt reappears                                                  |

---

## Group AI — `06_ai.sh`: NVM/Node guard + Claude/Gemini confirmation

**Location:** `install/06_ai.sh`

**Runs:** T1, T2, T3, T4, T5

### AI1–AI4: NVM and Node.js LTS guard

| ID  | Given                                    | When                   | Then                                                                                            |
|:---:| ---------------------------------------- | ---------------------- | ----------------------------------------------------------------------------------------------- |
| AI1 | NVM not installed                        | `--modules ai` invoked | NVM installed automatically before proceeding                                                   |
| AI2 | NVM installed; Node.js LTS not installed | `--modules ai` invoked | Node.js LTS installed automatically before proceeding                                           |
| AI3 | NVM and Node.js LTS both installed       | Module runs            | Both skipped with version info; no install runs                                                 |
| AI4 | `gh` not found                           | Module runs            | Warning displayed: `gh not found — run: bash bootstrap.sh --modules packages`; module continues |

### AI5–AI8: Claude Code confirmation

| ID  | Given                          | When                     | Then                                                                                 |
|:---:| ------------------------------ | ------------------------ | ------------------------------------------------------------------------------------ |
| AI5 | Claude Code not installed      | User enters `Y` or Enter | `npm install @anthropic-ai/claude-code` runs; `module_06_ai_claude=complete` written |
| AI6 | Claude Code not installed      | User enters `n`          | Install skipped; `module_06_ai_claude=skipped` written; hint shown                   |
| AI7 | Claude Code installed          | Module runs              | `skip Claude Code <version>` + reinstall hint; no prompt                             |
| AI8 | Claude Code state is `skipped` | Module re-runs           | Prompt reappears                                                                     |

### AI9–AI12: Gemini CLI confirmation

| ID   | Given                         | When                     | Then                                                                          |
|:----:| ----------------------------- | ------------------------ | ----------------------------------------------------------------------------- |
| AI9  | Gemini CLI not installed      | User enters `Y` or Enter | `npm install @google/gemini-cli` runs; `module_06_ai_gemini=complete` written |
| AI10 | Gemini CLI not installed      | User enters `n`          | Install skipped; `module_06_ai_gemini=skipped` written; hint shown            |
| AI11 | Gemini CLI installed          | Module runs              | `skip Gemini CLI` + reinstall hint; no prompt                                 |
| AI12 | Gemini CLI state is `skipped` | Module re-runs           | Prompt reappears                                                              |

### AI13: Copilot instructions always shown

| ID   | Given                      | When             | Then                                                                                                                   |
|:----:| -------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------- |
| AI13 | Any state of Claude/Gemini | Module completes | Copilot instructions always printed: `gh auth login`, `gh extension install github/gh-copilot`, `gh copilot --version` |

---

## Group SK — Skip messages and reinstall hint

**Runs:** T2, T3 (after re-install with Y in T4)

These scenarios validate that the skip message is informative and the reinstall hint is always shown.

| ID   | Given                 | When           | Then                                                          |
|:----:| --------------------- | -------------- | ------------------------------------------------------------- |
| SK1  | uv installed          | Module 03 runs | Output contains uv version; contains `--clean-tools` hint     |
| SK2  | Python LTS installed  | Module 03 runs | Output contains Python version; contains `--clean-tools` hint |
| SK3  | SDKman installed      | Module 04 runs | Output contains SDKman version; contains `--clean-tools` hint |
| SK4  | JDK installed         | Module 04 runs | Output contains Java version; contains `--clean-tools` hint   |
| SK5  | Maven installed       | Module 04 runs | Output contains Maven version; contains `--clean-tools` hint  |
| SK6  | Gradle installed      | Module 04 runs | Output contains Gradle version; contains `--clean-tools` hint |
| SK7  | NVM installed         | Module 05 runs | Output contains NVM version; contains `--clean-tools` hint    |
| SK8  | Node.js LTS installed | Module 05 runs | Output contains Node version; contains `--clean-tools` hint   |
| SK9  | Claude Code installed | Module 06 runs | Output contains Claude version; contains `--clean-tools` hint |
| SK10 | Gemini CLI installed  | Module 06 runs | Output contains Gemini version; contains `--clean-tools` hint |

---

## Group NI — Non-interactive mode (`_confirm` TTY detection)

**Runs:** T5

| ID  | Given                                      | When                               | Then                                                                                  |
|:---:| ------------------------------------------ | ---------------------------------- | ------------------------------------------------------------------------------------- |
| NI1 | Script invoked via `curl \| bash` (no TTY) | Any confirmation prompt is reached | `_confirm` returns 0 (Y) without displaying the prompt; install proceeds              |
| NI2 | Script invoked via `curl \| bash`          | All modules run                    | All tools installed without any user input; same result as answering Y to all prompts |

---

## Regression Checks

After each run, verify:

| Check                                      | How to verify                                                                                                            |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| `--clean-tools` removes all sub-state keys | `cat ~/.bootstrap-state` — no `module_03_python_lts`, `module_04_java_*`, `module_05_node_lts`, `module_06_ai_*` entries |
| pyenv absent after T1                      | `ls ~/Dev/tools/python/` — only `uv`-managed directories; no `pyenv/`                                                    |
| poetry absent after T1                     | `command -v poetry` — not found                                                                                          |
| uv installs Python in seconds              | T1 log — Python install completes in under 30 seconds                                                                    |
| State file consistency                     | `cat ~/.bootstrap-state` — sub-state values are either `complete` or `skipped`, never empty                              |
