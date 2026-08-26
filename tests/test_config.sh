#!/usr/bin/env bash
# Config-cache and generated config.toml tests for hf-codex.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"

fail() { echo "FAIL: $*" >&2; exit 1; }

# --- stubs (same shape as test_args.sh) ------------------------------------
cat > "$WORK/bin/fzf" <<'EOF'
#!/usr/bin/env bash
input=$(cat)
case "$*" in
  *Model:*) echo "$input" | grep -m1 'gpt-oss-20b' ;;
  *)        echo "$input" | grep -m1 'cerebras' ;;
esac
EOF
chmod +x "$WORK/bin/fzf"

cat > "$WORK/bin/curl" <<'EOF'
#!/usr/bin/env bash
cat <<'JSON'
{"data":[
  {"id":"openai/gpt-oss-20b","providers":[{"provider":"groq"},{"provider":"cerebras"}]}
]}
JSON
EOF
chmod +x "$WORK/bin/curl"

cat > "$WORK/bin/codex" <<'EOF'
#!/usr/bin/env bash
exit 42
EOF
chmod +x "$WORK/bin/codex"

export PATH="$WORK/bin:$PATH"
export HF_TOKEN="hf_test_token"
export HF_HOME="$WORK/hfhome"
export HF_CODEX_DRY_RUN=1

# --- 1. run writes last-model.json with the selected model ------------------
bash "$REPO_ROOT/hf-codex" >/dev/null 2>&1 || fail "first dry-run failed"
cfg="$HF_HOME/hf-codex/last-model.json"
[[ -f "$cfg" ]] || fail "last-model.json not written"
model="$(jq -r '.model' "$cfg")"
[[ "$model" == "openai/gpt-oss-20b:cerebras" ]] || fail "cached model wrong: $model"
echo "ok: last-model.json caches selected model"

# --- 2. generated config.toml points codex at the HF router -----------------
toml="$HF_HOME/hf-codex/config.toml"
grep -q '^model_provider = "hf"$' "$toml" || fail "model_provider missing"
grep -q '^base_url = "https://router.huggingface.co/v1"$' "$toml" || fail "base_url missing"
grep -q '^env_key = "HF_TOKEN"$' "$toml" || fail "env_key missing"
grep -q '^wire_api = "responses"$' "$toml" || fail "wire_api missing"
echo "ok: config.toml has hf provider block"

# --- 3. no bill-to flag -> no env_http_headers section ----------------------
if grep -q 'env_http_headers' "$toml"; then fail "env_http_headers present without --bill-to"; fi
echo "ok: no bill-to section by default"

exit 0
