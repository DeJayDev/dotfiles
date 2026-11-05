# claude-backup

Backs up Claude Code transcripts (`~/.claude/projects/` and `history.jsonl`) with restic to the R2 bucket `claude-backups`, and also to a local repo at `~/.local/share/claude-backup` when one exists there. SessionStart and SessionEnd hooks run it when a repo's last success is over 12h old, and launchd (macOS) or a systemd user timer (Linux) runs it every 12h regardless. Snapshots are never pruned.

The restic password and R2 token live in `secrets.age` next to this file, encrypted to a key held by this machine's Secure Enclave or TPM (`~/.local/state/claude-backup/hw-identity.txt`). Their plaintext, `secrets.env`, only exists inside the yadm archive, so the yadm passphrase is the root of everything. The archive itself is encrypted with age's passphrase mode through `~/.local/bin/yadm-age`, which refuses any yadm call it doesn't recognize. The log and the status file behind the statusline badge are in `~/.local/state/claude-backup/`.

The source is `main.go` next to this file. The bootstrap builds it into `~/.local/bin/claude-backup`; after pulling a change to it, rebuild with `go build -C ~/.config/claude-backup -o ~/.local/bin/claude-backup .`

## Load the secrets into a shell

    set -a
    eval "$(age -d -i ~/.local/state/claude-backup/hw-identity.txt ~/.config/claude-backup/secrets.age)"
    set +a
    export AWS_DEFAULT_REGION=auto
    r2="s3:https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com/claude-backups"

## Restore on a new machine

1. `yadm clone`, run the bootstrap, then `yadm decrypt`. The post_decrypt hook binds the secrets to this machine's chip.
2. Load the secrets, then `restic -r "$r2" snapshots --host <old-host>`.
3. `restic -r "$r2" restore latest --host <old-host> --target ~/claude-restore`. Snapshots keep absolute paths, so move `projects/` and `history.jsonl` from `~/claude-restore/<old home>/.claude/` into `~/.claude`.
4. If R2 is unreachable, run the same commands with `-r` pointing at a local repo or any copy of one.

## Restore one session the cleanup deleted

    restic -r "$r2" find '<uuid>*'
    restic -r "$r2" restore <snapshot> --target ~/claude-restore --include '**/<uuid>.jsonl' --include '**/<uuid>/'

## Change a secret

    (umask 077 && age -d -i ~/.local/state/claude-backup/hw-identity.txt -o ~/.config/claude-backup/secrets.env ~/.config/claude-backup/secrets.age)
    $EDITOR ~/.config/claude-backup/secrets.env
    yadm encrypt

post_encrypt re-encrypts the edited file to the chip and deletes the plaintext. Commit the new archive.

## When the badge shows up

Yellow `bk <repo> 14h` means that repo's last success is over 13h old. Red `bk <repo> fail` means over 26h, or the last backup or check against it failed. The reason is in `~/.local/state/claude-backup/log`. If it says the secrets couldn't be decrypted (the plugin broke, or the chip changed), delete `hw-identity.txt` and run `yadm decrypt` to bind the secrets to a new key.

## First-time setup (once, ever)

1. Create the R2 bucket `claude-backups` and an API token scoped to Object Read & Write on that bucket only.
2. With `umask 077`, write `~/.config/claude-backup/secrets.env` as four `export` lines: `RESTIC_PASSWORD` (from `openssl rand -base64 32`), `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `R2_ACCOUNT_ID`.
3. `yadm encrypt` binds them to the chip; commit the archive. Load the secrets, then `restic init -r "$r2"`.
4. Optionally, add a local repo with `RESTIC_FROM_PASSWORD="$RESTIC_PASSWORD" restic init -r ~/.local/share/claude-backup --from-repo "$r2" --copy-chunker-params`, so it chunks identically to R2. claude-backup uses it from then on.
5. Other machines don't initialize anything. They back up to the same R2 repo under their own `--host`.
