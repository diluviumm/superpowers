#!/usr/bin/env bash
# fork-check.sh — SATU perintah, seluruh baterai verifikasi lokal fork ini.
#
# Dipakai: sebelum push, setelah sync upstream, atau kapan pun perlu bukti segar
# bahwa tidak ada regresi. Jalur verifikasi ringkas per-butir (a–g) tetap dimiliki
# cron superpowers-fork-sync; lihat FORK-NOTES.md dan docs/USAGE.md.
#
# Usage:  scripts/fork-check.sh
# Exit:   0 = semua lulus, 1 = ada yang gagal (ringkasan + log ekor per kegagalan).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# Self-heal PATH: shell non-interaktif (proses Python/agent) kadang tanpa direktori
# perl — `shasum` (prereq packaging codex) hidup di /usr/bin/core_perl. Tanpa ini
# baterai gagal prematur hanya karena PATH, bukan karena kode.
command -v shasum >/dev/null 2>&1 \
  || export PATH="$PATH:/usr/bin/core_perl:/usr/bin/site_perl:/usr/bin/vendor_perl"

PASS=0
FAIL=0
FAILED=()
LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fork-check.XXXXXX")"
# Simpan log HANYA saat hijau; saat gagal, log suite dipertahankan + path dicetak
# agar kegagalan langsung terdiagnosis (kejadian transient jadi bukti, bukan tebakan).
cleanup_logs() {
  if ((FAIL == 0)); then
    rm -rf "$LOG_DIR"
  else
    echo "log kegagalan disimpan di: $LOG_DIR" >&2
  fi
}
trap cleanup_logs EXIT

check() {
  local name="$1"
  shift
  local log
  log="$LOG_DIR/$(printf '%s' "$name" | tr ' /' '__').log"
  if "$@" >"$log" 2>&1; then
    printf '  [PASS] %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  [FAIL] %s\n' "$name"
    FAIL=$((FAIL + 1))
    FAILED+=("$name")
    sed 's/^/         /' "$log" | tail -n 12
  fi
}

echo "== Struktur & guard =="
check "fork-guard" python3 scripts/fork-guard.py
check "shell lint (all tracked .sh)" bash scripts/lint-shell.sh --all

echo "== Suite Hermes =="
check "pytest tests/hermes (19 test)" \
  uv run --no-project --with pytest python -m pytest tests/hermes/ -q

echo "== Suite bash =="
check "shell-lint suite" bash tests/shell-lint/test-lint-shell.sh
check "diagnosing suite (46)" bash tests/diagnosing-superpowers/test-skill-structure.sh
check "hooks suite" bash tests/hooks/test-session-start.sh
check "systematic-debugging suite" bash tests/systematic-debugging/test-find-polluter.sh

echo "== Suite node =="
check "brainstorm-server suite (npm test)" bash -c '
  cd tests/brainstorm-server
  [ -d node_modules/ws ] || npm install --no-audit --no-fund
  npm test
'

echo "== Suite harness lintas-agen =="
check "opencode bootstrap-caching" bash tests/opencode/test-bootstrap-caching.sh
check "opencode plugin-loading" bash tests/opencode/test-plugin-loading.sh
check "kimi plugin-manifest" bash tests/kimi/test-plugin-manifest.sh
check "devin plugin" bash tests/devin/test-devin-plugin.sh
check "antigravity tools" bash tests/antigravity/test-antigravity-tools.sh
check "codex marketplace-manifest" bash tests/codex/test-marketplace-manifest.sh
check "codex package-archive" bash tests/codex/test-package-codex-plugin.sh
check "codex-plugin-sync" bash tests/codex-plugin-sync/test-sync-to-codex-plugin.sh
check "pi extension" node tests/pi/test-pi-extension.mjs

echo "== Suite claude-code (statis, tanpa CLI claude) =="
check "claude-code sdd-workspace" bash tests/claude-code/test-sdd-workspace.sh
check "claude-code worktree-path-policy" bash tests/claude-code/test-worktree-path-policy.sh
check "claude-code executing-plans" bash tests/claude-code/test-executing-plans-scripts.sh
check "test-helpers smoke (source + assert tanpa claude)" bash -c '
  source tests/claude-code/test-helpers.sh
  d=$(create_test_project); [ -d "$d" ] || exit 1; rm -rf "$d"
  o=$(printf "alpha\nbeta\nbeta")
  assert_contains "$o" "beta" smoke >/dev/null || exit 2
  assert_not_contains "$o" "gamma" smoke >/dev/null || exit 3
  assert_count "$o" "beta" 2 smoke >/dev/null || exit 4
'

echo "== Suite tool-tambahan (yq & graphviz user-level) =="
check "version-bump suite (butuh yq)" bash tests/version-bump/test-bump-version.sh
check "writing-skills render-graphs (butuh dot)" bash tests/writing-skills/test-render-graphs.sh

echo
echo "=================================================="
printf 'HASIL: %d lulus, %d gagal (total %d)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
if ((FAIL > 0)); then
  printf 'GAGAL:' >&2
  printf ' %s' "${FAILED[@]}" >&2
  printf '\n' >&2
  exit 1
fi
echo "STATUS: HIJAU — semua suite lokal lulus."
