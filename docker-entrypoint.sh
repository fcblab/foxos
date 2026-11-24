#!/bin/bash
set -e

if [ "${AUTO_INSTALL_JAVA:-true}" = "true" ]; then
    "$(dirname "$0")/env/java.sh"
fi
if [ "${AUTO_INSTALL_RUST:-true}" = "true" ]; then
    "$(dirname "$0")/env/rust.sh"
fi

"$(dirname "$0")/foxos-config.sh"

# Start T3 Code after applying the current environment.
if [ "${START_T3CODE:-true}" = "true" ] && command -v t3 >/dev/null 2>&1; then
    echo "Starting T3 Code on ${T3CODE_HOST:-0.0.0.0}:${T3CODE_PORT:-3773}"

    t3 serve \
        --host "${T3CODE_HOST:-0.0.0.0}" \
        --port "${T3CODE_PORT:-3773}" \
        </dev/null &
fi

exec "$@"
