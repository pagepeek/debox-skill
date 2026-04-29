#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${DEBOX_SKILL_REPO_URL:-https://github.com/pagepeek/debox-skill.git}"
RAW_BASE_URL="${DEBOX_SKILL_RAW_BASE_URL:-https://raw.githubusercontent.com/pagepeek/debox-skill/main}"
INSTALL_DIR="${DEBOX_SKILL_INSTALL_DIR:-$HOME/.agents/skills/debox}"

usage() {
  cat <<'EOF'
Usage:
  debox.sh install
  debox.sh run <debox-cli-args...>
  debox.sh <debox-cli-args...>

Examples:
  bash debox.sh install
  bash debox.sh group parse-id --url "https://m.debox.pro/group?id=fxi3hqo5" --json
  bash debox.sh run env check --json
EOF
}

download_file() {
  local url="$1"
  local destination="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$destination"
    return 0
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$destination"
    return 0
  fi

  echo "debox installer requires curl or wget" >&2
  return 1
}

copy_local_skill() {
  local source_dir="$1"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  rm -rf "$INSTALL_DIR"
  cp -R "$source_dir" "$INSTALL_DIR"
}

install_skill() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [[ -f "$script_dir/debox/SKILL.md" ]]; then
    copy_local_skill "$script_dir/debox"
    echo "Installed debox skill to $INSTALL_DIR"
    return 0
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  if command -v git >/dev/null 2>&1; then
    git clone --depth 1 "$REPO_URL" "$tmp_dir/repo" >/dev/null
    copy_local_skill "$tmp_dir/repo/debox"
    echo "Installed debox skill to $INSTALL_DIR"
    return 0
  fi

  mkdir -p "$tmp_dir/repo/debox/scripts" "$tmp_dir/repo/debox/references"
  download_file "$RAW_BASE_URL/debox/SKILL.md" "$tmp_dir/repo/debox/SKILL.md"
  download_file "$RAW_BASE_URL/debox/scripts/debox.sh" "$tmp_dir/repo/debox/scripts/debox.sh"
  chmod +x "$tmp_dir/repo/debox/scripts/debox.sh"

  local ref
  for ref in credentials messaging bot-registration miniapp chatwidget shares-safety troubleshooting; do
    download_file "$RAW_BASE_URL/debox/references/$ref.md" "$tmp_dir/repo/debox/references/$ref.md"
  done

  copy_local_skill "$tmp_dir/repo/debox"
  echo "Installed debox skill to $INSTALL_DIR"
}

ensure_installed() {
  if [[ ! -x "$INSTALL_DIR/scripts/debox.sh" ]]; then
    install_skill
  fi
}

cmd="${1:-install}"
case "$cmd" in
  install)
    install_skill
    ;;
  run)
    shift
    ensure_installed
    exec "$INSTALL_DIR/scripts/debox.sh" "$@"
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    ensure_installed
    exec "$INSTALL_DIR/scripts/debox.sh" "$@"
    ;;
esac
