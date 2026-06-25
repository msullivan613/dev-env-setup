# dev-env-setup

Reproducible development environment for a fresh **Ubuntu 24.04 (WSL2)** machine,
driven by Ansible. Clone it onto a newly imaged box, run one script, and get back
the shell, tools, languages, and dotfiles I'm used to.

## Quick start

```bash
git clone <this-repo> ~/dev-env-setup
cd ~/dev-env-setup
./bootstrap.sh
```

`bootstrap.sh` installs Ansible (if missing) and runs the playbook against
`localhost`. You'll be prompted once for your sudo password.

## What it sets up

| Role        | Contents |
|-------------|----------|
| `common`    | apt update/upgrade, `build-essential`, core utilities |
| `cli`       | ripgrep, fd, fzf, bat, jq, neovim, eza |
| `shell`     | zsh + Oh My Zsh (autosuggestions, syntax-highlighting), Powerlevel10k theme, default shell |
| `languages` | Node via [fnm](https://github.com/Schniz/fnm), Python via [uv](https://github.com/astral-sh/uv), `virtualenv` (uv-installed CLI) |
| `docker`    | docker-ce engine + compose/buildx plugins, docker group, systemd in WSL |
| `dotfiles`  | `.zshrc`, `.gitconfig`, `.tmux.conf`, `nvim/init.lua` (Jinja2 templates) |

## Customizing

All tunables live in [`group_vars/all.yml`](group_vars/all.yml): package lists,
git identity, zsh theme/plugins, Node/Python versions. Edit there rather than in
the roles.

## Prompt (Powerlevel10k)

The `shell` role installs [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
as an Oh My Zsh custom theme, and the `dotfiles` role deploys the prompt config
to `~/.p10k.zsh` from [`roles/dotfiles/files/p10k.zsh`](roles/dotfiles/files/p10k.zsh).
The instant-prompt block and `source ~/.p10k.zsh` line are part of the `.zshrc`
template, so re-running the playbook no longer clobbers the prompt.

To change the prompt, run the wizard and commit the result back into the repo:

```bash
p10k configure
cp ~/.p10k.zsh ~/dev-env-setup/roles/dotfiles/files/p10k.zsh
```

> **Fonts:** P10k needs a Nerd Font (MesloLGS NF) configured in your **Windows
> terminal** — that's a host-side setting WSL can't manage, so install/select it
> in Windows Terminal once. Set `p10k_install: false` in `group_vars/all.yml` to
> fall back to a plain theme.

## Running subsets

```bash
./bootstrap.sh --tags shell,cli   # only those roles
./bootstrap.sh --check            # dry run (no changes)
./bootstrap.sh --tags docker      # just (re)configure docker
```

Once Ansible is installed you can also call the playbook directly:

```bash
ansible-playbook -i inventory.ini site.yml -K
```

## Docker on WSL2 — first run note

The `docker` role enables systemd via `/etc/wsl.conf`. If systemd wasn't already
running, the docker **service** can't start during the first run. In that case:

1. From **Windows PowerShell**: `wsl --shutdown`
2. Reopen your WSL terminal.
3. Re-run: `./bootstrap.sh --tags docker`

You also need a new login session for `docker` group membership to take effect
(the `wsl --shutdown` covers this). Verify with:

```bash
docker run --rm hello-world
```

## Idempotency

The playbook is safe to re-run; every external installer (Oh My Zsh, fnm, uv,
Docker key/repo) is guarded, so a second run reports no changes. Re-running is
the intended way to apply updates after editing `group_vars/all.yml`.

## Not included (yet)

- Cloud/infra CLIs (aws, gcloud, kubectl, terraform)
- Go / Rust toolchains
- Secrets (SSH keys, tokens) — managed manually, kept out of the repo
