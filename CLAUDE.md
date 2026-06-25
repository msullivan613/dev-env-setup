# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An Ansible playbook that provisions a fresh **Ubuntu 24.04 (noble) on WSL2** machine
into a ready-to-use dev environment. It runs against `localhost` only (no remote
hosts) — `inventory.ini` maps the `local` group to `localhost` via
`ansible_connection=local`. The target is the single user running the playbook.

## Commands

```bash
./bootstrap.sh                      # install Ansible if missing, then run everything (prompts for sudo)
./bootstrap.sh --tags shell,cli     # run only selected roles
./bootstrap.sh --check              # dry run, no changes
./bootstrap.sh --tags docker        # re-run a single role

# Direct invocation once Ansible is installed (-K = --ask-become-pass):
ansible-playbook -i inventory.ini site.yml -K
```

Any extra args to `bootstrap.sh` are forwarded verbatim to `ansible-playbook`
(see the final `exec` line). There is no separate test suite; `--check` is the
closest thing to a validation pass, and re-running should report zero changes
(idempotency is the correctness contract — see below).

## Architecture

Standard Ansible role layout. `site.yml` runs six roles in a fixed order, each
gated by a tag matching its name: **common → cli → shell → languages → docker →
dotfiles**. Order matters: `dotfiles` runs last so its `.zshrc` references tools
the earlier roles installed.

- `group_vars/all.yml` — **the only file you should normally edit.** All tunables
  live here: package lists, git identity, zsh theme/plugins, Node/Python versions,
  the WSL/docker toggles. Roles read these vars; don't hardcode values into role
  tasks.
- `roles/<name>/tasks/main.yml` — the actual work for each role.
- `roles/dotfiles/templates/*.j2` — Jinja2-rendered config fragments. These pull
  from `group_vars`, so e.g. git identity flows from `git_user_name`/
  `git_user_email` into `gitconfig.j2`. **The dotfiles role never overwrites the
  files in `$HOME`.** It renders the managed content into a separate location
  that the playbook fully owns and overwrites every run — `~/.config/dev-env/`
  (`zshrc.zsh`, `gitconfig`, `tmux.conf`) and `~/.config/nvim/dev-env.lua`. The
  real dotfiles (`~/.zshrc`, `~/.gitconfig`, `~/.tmux.conf`, `~/.config/nvim/
  init.lua`) are thin **stubs** that source/include those fragments (zsh
  `source`, git `[include]`, tmux `source-file`, nvim `dofile`). Stubs are
  written with `force: false`, so they're created once and then belong to the
  user — anything added below the managed line survives re-runs.
- `roles/dotfiles/files/p10k.zsh` — the Powerlevel10k prompt config, deployed
  verbatim (not templated) to `~/.p10k.zsh` with `force: false`. `p10k configure`
  regenerates that file, so it too is only seeded once and never clobbered.

`ansible.cfg` sets `become = False` globally; privilege escalation is opt-in
per-task via `become: true`. The single become password comes from
`--ask-become-pass`.

`target_user` / `target_home` default to the invoking user (`ansible_user_id` /
`ansible_env.HOME`) — tasks use these vars rather than `~` so the playbook stays
user-agnostic.

## Conventions to preserve

- **Idempotency is the contract.** Every external installer must be guarded so a
  second run reports no changes. Existing patterns: `args.creates:` on shell/get_url
  tasks, a `stat` + `when: not ...stat.exists` precheck (Oh My Zsh, fnm, uv), and
  custom `changed_when:` expressions where an installer's output is the only signal
  (see the fnm "already installed" check and the uv "Installed" checks in
  `roles/languages/tasks/main.yml`). Match one of these when adding install steps.
- **Third-party apt repos** (docker, eza) follow a fixed shape: ensure
  `/etc/apt/keyrings`, fetch the signing key there, add the repo with
  `signed-by=`, then `apt: update_cache: true`. Copy this pattern rather than
  piping to `apt-key`.
- User-space tooling installs under `~/.local` (fnm in `~/.local/share/fnm`, uv
  binaries and shims in `~/.local/bin`) — not system-wide.

## WSL/docker gotcha

The `docker` role writes `/etc/wsl.conf` to enable systemd, but the docker
**service** can't start on the first run if systemd wasn't already PID 1. The role
detects this (`when: ansible_service_mgr == 'systemd'`) and prints a warning
instead of failing. Recovery: `wsl --shutdown` from Windows PowerShell, reopen the
terminal, then `./bootstrap.sh --tags docker`. The same shutdown is also what
activates `docker` group membership.

## Out of scope (by design)

Cloud/infra CLIs (aws, gcloud, kubectl, terraform), Go/Rust toolchains, and
secrets (SSH keys, tokens) are intentionally not managed here. Nerd Font
installation is a Windows-host setting WSL can't control.
