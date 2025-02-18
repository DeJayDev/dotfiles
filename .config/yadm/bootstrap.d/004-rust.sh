#!/bin/sh

echo "[.files] - Installing rust via rustup"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

echo "[.files] - Installing rust packages (1/2)"
cargo install cargo-binstall

echo "[.files] - Installing rust packages (2/2)"
cargo binstall -y fnm hunt topgrade tealdeer zoxide
