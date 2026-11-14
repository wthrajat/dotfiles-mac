#!/usr/bin/env bash
# Rebuild yabai from the personal fork, install it, and refresh the sudoers rule.
#
# Usage: ~/.config/yabai/update-fork.sh [--pull]
#   --pull  fast-forward the checked-out branch from origin before building
#
# Signing: uses the "yabai-cert" keychain identity when it exists, so the
# Accessibility grant survives rebuilds. Falls back to ad-hoc signing, which
# needs Accessibility to be removed and re-added after every update.

set -euo pipefail

readonly REPO_DIR="$HOME/dev/yabai"
readonly INSTALL_PATH="$HOME/.local/bin/yabai"
readonly LINK_PATH="/opt/homebrew/bin/yabai"
readonly SUDOERS_PATH="/private/etc/sudoers.d/yabai"
readonly BUNDLE_ID="com.asmvik.yabai"
readonly CERT_NAME="yabai-cert"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

pull_latest() {
    log "Pulling $(git -C "$REPO_DIR" branch --show-current) from origin"
    git -C "$REPO_DIR" pull --ff-only
}

build_binary() {
    log "Building"
    make -C "$REPO_DIR" install >/dev/null
}

install_binary() {
    local staged_path="$INSTALL_PATH.new"
    mkdir -p "$(dirname "$INSTALL_PATH")"
    cp "$REPO_DIR/bin/yabai" "$staged_path"
    mv -f "$staged_path" "$INSTALL_PATH"
    ln -sfn "$INSTALL_PATH" "$LINK_PATH"
}

signing_identity() {
    if security find-certificate -c "$CERT_NAME" >/dev/null 2>&1; then
        echo "$CERT_NAME"
    else
        echo "-"
    fi
}

sign_binary() {
    local identity
    identity="$(signing_identity)"
    log "Signing with identity: $identity"
    codesign --force --sign "$identity" --identifier "$BUNDLE_ID" "$INSTALL_PATH"
    codesign --verify --strict --all-architectures "$INSTALL_PATH"
}

update_sudoers() {
    local binary_hash rule_file
    binary_hash="$(shasum -a 256 "$INSTALL_PATH" | cut -d ' ' -f 1)"
    rule_file="$(mktemp)"
    echo "$USER ALL=(root) NOPASSWD: sha256:$binary_hash $LINK_PATH --load-sa" > "$rule_file"

    log "Validating and installing sudoers rule (asks for your password)"
    sudo visudo -cf "$rule_file" >/dev/null
    sudo install -m 0440 -o root -g wheel "$rule_file" "$SUDOERS_PATH"
    rm -f "$rule_file"
}

restart_yabai() {
    log "Restarting yabai"
    yabai --restart-service
}

main() {
    if [[ "${1:-}" == "--pull" ]]; then pull_latest; fi

    build_binary
    install_binary
    sign_binary
    update_sudoers
    restart_yabai

    log "Installed $("$INSTALL_PATH" --version) at $INSTALL_PATH"
    if [[ "$(signing_identity)" == "-" ]]; then
        log "Ad-hoc signed: remove and re-add yabai in Accessibility settings"
    fi
}

main "$@"
