#!/bin/sh

echo "[.files] - Installing rust via rustup"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# shellcheck source=/dev/null
. "$HOME/.cargo/env"

echo "[.files] - Installing rust packages (1/2)"
cargo install cargo-binstall

echo "[.files] - Installing rust packages (2/2)"
cargo binstall -y fd-find fnm hunt hyperfine ripgrep topgrade tealdeer zoxide
