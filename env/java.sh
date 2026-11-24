#!/bin/bash
set -euo pipefail

if [ -f "${JAVA_HOME}/.foxos-installed" ]; then
    exit 0
fi

# https://bell-sw.com/pages/downloads/?version=java-25
mkdir -p "${JAVA_HOME}"
JAVA_URL=$(curl -fsSL 'https://api.bell-sw.com/v1/liberica/releases?version-feature=25&version-modifier=latest&os=linux&arch=x86&bitness=64&package-type=tar.gz&bundle-type=jdk&fields=downloadUrl,version' \
    | jq -er 'max_by(.version | gsub("\\+"; ".") | split(".") | map(tonumber)).downloadUrl')
curl -fsSL "${JAVA_URL}" | tar -xz --strip-components=1 -C "${JAVA_HOME}"
"${JAVA_HOME}/bin/java" -version
"${JAVA_HOME}/bin/javac" -version
touch "${JAVA_HOME}/.foxos-installed"
