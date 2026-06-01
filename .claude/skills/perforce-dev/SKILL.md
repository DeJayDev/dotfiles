---
name: perforce-dev
description: >
  Use whenever the user is working with Perforce P4 (formerly Helix Core) on this
  machine -- mentions p4, perforce, swarm, "p4 code review", helix, .p4config, a
  depot/changelist/CL, the `greptile-dev` P4 server, the `greptile-client-dj`
  workspace, the `~/p4-scratch-dj` directory, or the `perforce_on_worker` branch
  in greptilia. Also fires when editing `apps/worker/src/agent/environment/grepbox.ts`
  or anything under `packages/scm/src/platforms/perforce/`. Tells Claude how to
  check whether the p4 env is live and what to do when it isn't.
allowed-tools: Bash(p4:*), Bash(cat:*), Bash(ls:*), Bash(env:*), Bash(grep:*), Bash(curl:*), Read, Edit
---

# Perforce dev environment

Dj has a zsh hook on his machine that loads p4 credentials and Swarm/bot env
vars whenever he `cd`s into a Perforce-related directory. That hook is for him,
not for you. You don't run it, you don't simulate it, you don't source the
config file it reads. You only ever observe the result.

The result is in two places:

1. The shell variable `$_GREPTILIA_PERFORCE_STATE` -- the canonical signal.
2. The inherited process env (`$P4PORT`, `$P4USER`, `$SWARM_URL`, etc.) --
   what Dj's shell handed Claude Code at launch.

Follow the procedure below before doing any p4 work.

## 1. Check if the p4 env is live

Before any p4 command, run this:

```bash
echo "state=${_GREPTILIA_PERFORCE_STATE:-<unset>} p4port=${P4PORT:-<unset>}"
```

`$_GREPTILIA_PERFORCE_STATE` is the canonical signal; `$P4PORT` is a fallback
in case the state var hasn't propagated (older shells launched before the
hook exported it). Interpret the output:

| Value | Meaning | Action |
| --- | --- | --- |
| state starts with `active` (e.g. `active\|perforce_on_worker`, `active\|dj/p4-learnings\|forced`, `active\|scratch`) | p4 env is loaded; proceed | continue to step 2 |
| state starts with `cleared` (e.g. `cleared\|main`) | hook explicitly cleared the env; non-perforce branch, no opt-in | **stop. ask Dj to run `_yep_p4` in his interactive shell, then restart Claude Code.** |
| state `<unset>` but `$P4PORT` is set | shell exported P4PORT but didn't export state var (older hook); treat as active | proceed to step 2, but mention to Dj that the hook may need a refresh (`source ~/.zshrc` in his shell would re-export the state var) |
| state `<unset>` and `$P4PORT` `<unset>` | Claude Code was launched from a shell that never entered a perforce-aware directory | **stop. ask Dj to `cd ~/greptile/greptilia && _yep_p4` (or `cd ~/p4-scratch-dj`) in his interactive shell, then restart Claude Code.** |

Do not try to "fix" a non-active state from inside Claude. The hook is only
re-run by Dj's interactive shell; nothing you do in the Bash tool will refresh
it. The only correct recovery is asking Dj to fix his shell and relaunch.

## 2. Run p4 commands

Cwd resets between Bash tool calls back to Claude's launch directory. Every
p4 command needs its own cd:

```bash
cd ~/greptile/greptilia && p4 info
cd ~/p4-scratch-dj && p4 changes -m5
```

Either directory works -- p4 resolves credentials via P4CONFIG walk-up (see
"Reference" below). You don't need to be in any specific subdirectory.

If `p4 info` fails after step 1 passed, check the troubleshooting matrix.

## 3. Never echo `$P4PASSWD`

The config file Dj's hook sources contains `P4PASSWD=<cleartext>`. That value
is in your process env. Don't:

- `env | grep ^P4` -- includes P4PASSWD
- `printenv P4PASSWD`
- `echo $P4PASSWD`
- any command that puts the value in a tool-result transcript

Safe checks:

```bash
env | grep -E '^(P4PORT|P4USER|P4CLIENT|SWARM_|BOT_)='
[[ -n "$P4PASSWD" ]] && echo "P4PASSWD set" || echo "P4PASSWD unset"
```

## Reference

### Naming (2026 rebrand)
Perforce dropped the "Helix" brand. New names:

- Helix Core → **Perforce P4** (a.k.a. P4) -- the original 1995 name
- Helix Core Cloud → **P4 Cloud**
- Helix Swarm → **P4 Code Review**
- Helix DAM / Plan / Search → **P4 DAM / P4 Plan / P4 Search**
- Helix IPLM / ALM / TeamHub / QAC → **Perforce IPLM / ALM / TeamHub / QAC** (kept "Perforce" prefix, dropped "Helix")

Umbrella term is **P4 Platform**. New artist/designer client: **P4 One** (from Snowtrack acquisition).

The `p4` CLI, `.p4config`, P4PORT/P4USER/P4CLIENT/P4PASSWD env vars, P4CONFIG walk-up, and helper-script behavior are all unchanged -- only product names changed. This skill still uses "Swarm" in places because `$SWARM_URL`/`$SWARM_PROJECT`/`$SWARM_BRANCH` env vars and the `p4dev.sh` helpers haven't been renamed locally. If Dj says "P4 Code Review", that's Swarm.

Source: https://www.perforce.com/blog/vcs/introducing-the-p4-platform

### Canonical config file
`~/greptile/.p4config.local` -- one level above the greptilia worktree so
git operations can't disturb it. Contains `P4PORT`, `P4USER`, `P4CLIENT`,
`P4PASSWD`, `SWARM_URL`, `SWARM_PROJECT`, `SWARM_BRANCH`, `BOT_USERNAME`.

`~/p4-scratch-dj/.p4config.local` is a symlink to it. Don't edit the symlink;
edit the canonical file if anything needs to change. Both files are
gitignored; keep it that way.

### How p4 finds it
`~/.p4enviro` has `P4CONFIG=.p4config.local`. The p4 binary walks up from
`$PWD` looking for that filename. Works from `~/greptile/greptilia` or
`~/p4-scratch-dj` (or any subdir). Verify with `p4 set P4CONFIG`.

### State values
`$_GREPTILIA_PERFORCE_STATE` can be:
- `active|<branch>` -- on `perforce_on_worker`
- `active|<branch>|forced` -- on some other branch, `_yep_p4` opted in
- `active|scratch` -- inside `~/p4-scratch-dj`
- `cleared|<branch>` -- in greptilia on a non-perforce branch, no opt-in
- unset -- shell never entered a perforce-aware dir

For your purposes: `active*` means go, anything else means stop.

### Helper scripts
Two `p4dev.sh` scripts handle common Swarm chores so you don't have to script
them from scratch:

- `~/greptile/greptilia/internal/cli/p4-dev.sh` -- includes a `setup`
  subcommand and Swarm `review-create` / `review-url` helpers.
- `~/p4-scratch-dj/p4dev.sh` -- depot-side helper with similar Swarm helpers.
  Errors with `source your .p4config.local first` if env isn't loaded, which
  in your case means step 1 said stop.

Read them before reinventing.

### The `perforce_on_worker` branch
Dj's working branch for the Perforce platform integration in `apps/worker`
and `packages/scm/src/platforms/perforce/`. The hook treats it as the
"developing against perforce" trigger -- on this branch (or with `_yep_p4`
forced) the local DB swaps to `greptile-perforce`.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `p4 set P4CONFIG` prints nothing | running p4 from outside any covered directory | re-run with `cd ~/greptile/greptilia &&` or `cd ~/p4-scratch-dj &&` prefix |
| `P4CONFIG=.p4config.local (enviro)` but no `(config '...')` suffix | walk-up didn't find the file from `$PWD` | wrong tree -- cd into greptilia or p4-scratch-dj |
| `p4 info`: `Perforce password (P4PASSWD) invalid or unset` | server rejected stored password or ticket expired | ask Dj to run `p4 login` in his interactive shell |
| `p4 info`: `Connect to server failed; check $P4PORT` | network/VPN, or P4PORT resolved wrong | confirm `p4 set P4PORT` matches `~/greptile/.p4config.local`; ask Dj about network |
| `$_GREPTILIA_PERFORCE_STATE` is `cleared\|<branch>` | non-perforce branch, hook unloaded the env | ask Dj to run `_yep_p4` and restart Claude |
| `$_GREPTILIA_PERFORCE_STATE` is unset | Claude launched from a shell that never visited a perforce dir | ask Dj to `cd ~/greptile/greptilia && _yep_p4` then restart Claude |
| `p4 login -ap` hangs / "EOF reading terminal" | non-tty stdin in Bash tool | don't run `p4 login` from Claude; ask Dj to do it in his shell |
| Second Bash command can't find files from the first | cwd resets between Bash tool calls | prefix every call with its own `cd`, or chain commands in one call |

## Things NOT to do

- **Don't run `gdev`.** It's Dj's interactive dev-stack launcher. It needs a
  real TTY and wedges every time an LLM has tried it from a non-interactive
  shell. No `gdev`, no `gdev &`, no `script -q /dev/null gdev`, no
  `expect`/`unbuffer`/tmux/`nohup` wrappers. If the stack isn't up, ask Dj
  to boot it in his own terminal. You only ever tail the log file it prints.
- Don't try to refresh `$_GREPTILIA_PERFORCE_STATE` or re-source any config
  from inside Claude. Only Dj's interactive shell can do that; you'd just
  pollute your own process env.
- Don't `source ~/greptile/.p4config.local`. p4 reads it on its own; sourcing
  it pulls `P4PASSWD` into env unnecessarily and skips the rest of the hook
  (Infisical, `.env` rewrite).
- Don't `p4 set P4PORT=...` etc. globally -- writes to `~/.p4enviro` and
  shadows the per-dir config. Let `P4CONFIG` do its job.
- Don't edit `~/p4-scratch-dj/.p4config.local` -- it's a symlink. Edit
  `~/greptile/.p4config.local`.
- Don't run `p4 login -ap` (or any interactive `p4 login`) from the Bash
  tool. Non-tty stdin; it hangs.
- Don't extract or echo `$P4PASSWD` (see step 3).
- Don't put real secrets in committed files. `.p4config.local` is gitignored;
  keep it that way.
- Don't delete the personal Infisical override via `infisical secrets delete`
  -- the hook only ever `set`s, so deletion breaks symmetric rollback.
