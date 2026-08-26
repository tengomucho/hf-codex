#!/usr/bin/env bash
# Arg-parsing and dry-run command-shape tests for hf-codex.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"

fail() { echo "FAIL: $*" >&2; exit 1; }

# --- stubs -----------------------------------------------------------------
# fzf stub: flags arrive as --prompt=... ; candidate lines on stdin.
# Model pick -> first line containing gpt-oss-20b; provider pick -> groq.
cat > "$WORK/bin/fzf" <<'EOF'
#!/usr/bin/env bash
input=$(cat)
case "$*" in
  *Model:*) echo "$input" | grep -m1 'gpt-oss-20b' ;;
  *)        echo "$input" | grep -m1 'groq' ;;
esac
EOF
chmod +x "$WORK/bin/fzf"

# curl stub: fixed models JSON.
cat > "$WORK/bin/curl" <<'EOF'
#!/usr/bin/env bash
cat <<'JSON'
{"data":[
  {"id":"openai/gpt-oss-20b","providers":[{"provider":"groq"},{"provider":"cerebras"}]},
  {"id":"moonshotai/Kimi-K2","providers":[{"provider":"novita"}]}
]}
JSON
EOF
chmod +x "$WORK/bin/curl"

# codex stub: should never be exec'd in dry-run; fail loudly if it is.
cat > "$WORK/bin/codex" <<'EOF'
#!/usr/bin/env bash
echo "codex stub must not run in dry-run" >&2
exit 42
EOF
chmod +x "$WORK/bin/codex"

export PATH="$WORK/bin:$PATH"
export HF_TOKEN="hf_test_token"
export HF_HOME="$WORK/hfhome"
export HF_CODEX_DRY_RUN=1

# --- 1. --bill-to without argument -> exit 1, helpful stderr ---------------
out="$(bash "$REPO_ROOT/hf-codex" --bill-to 2>&1)" && fail "--bill-to without arg should exit 1"
[[ "$out" == *"requires an organization name"* ]] || fail "unexpected error: $out"
echo "ok: --bill-to without arg rejected"

# --- 2. dry-run prints codex argv with model + forwarded args --------------
out="$(bash "$REPO_ROOT/hf-codex" exec 'say hi' 2>/dev/null)" || fail "dry-run exited non-zero"
[[ "$out" == codex\ * ]] || fail "dry-run output should start with 'codex': $out"
[[ "$out" == *'model=\"openai/gpt-oss-20b:groq\"'* ]] || fail "missing model string: $out"
[[ "$out" == *"exec"* && "$out" == *"say"*"hi"* ]] || fail "forwarded args missing: $out"
echo "ok: dry-run argv has model and forwarded args"

# --- 3. --bill-to=org -> config.toml gains X-HF-Bill-To header -------------
out="$(bash "$REPO_ROOT/hf-codex" --bill-to=my-org 2>/dev/null)" || fail "bill-to run failed"
cfg="$HF_HOME/hf-codex/config.toml"
grep -q 'X-HF-Bill-To' "$cfg" || fail "config.toml missing X-HF-Bill-To"
grep -q 'HF_BILL_TO_HEADER' "$cfg" || fail "config.toml missing HF_BILL_TO_HEADER"
echo "ok: --bill-to writes env_http_headers"

exit 0
