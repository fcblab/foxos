#!/bin/bash
set -euo pipefail

if [ -f "${CARGO_HOME:-$HOME/.cargo}/.foxos-installed" ]; then
    exit 0
fi

curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --default-toolchain stable \
        --profile minimal --component rustfmt,clippy,rust-analyzer,rust-src
rustc --version
cargo --version
rust-analyzer --version
touch "${CARGO_HOME:-$HOME/.cargo}/.foxos-installed"
