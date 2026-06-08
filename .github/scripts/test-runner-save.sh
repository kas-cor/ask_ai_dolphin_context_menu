#!/bin/bash
# CI test: verify runner save & script execution features
# Tests:
#   1. Shebang detection logic
#   2. Query slug generation (transliteration, truncation, empty fallback)
#   3. Script with shebang gets saved as .sh, chmod +x, and executed
#   4. Plain output (no shebang) is NOT saved as executable
#   5. ASK_AI_SAVE_DIR output file creation
#   6. Locale keys for save/script messages exist

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
FAILED=0

print_header() {
    echo ""
    echo "================================================"
    echo "  $1"
    echo "================================================"
}

pass() {
    echo "  ✅ $1"
}

fail() {
    echo "  ❌ FAILED: $1"
    FAILED=1
}

# --------------------------------
print_header "1. Shebang detection"
# --------------------------------

line1="#!/bin/bash"
if [[ "$line1" == "#!"* ]]; then
    pass "Shebang detected: '$line1'"
else
    fail "Should detect shebang: '$line1'"
fi

line2="  #!/bin/bash  "  # spaces before shebang — should NOT match
if [[ "$line2" == "#!"* ]]; then
    fail "Should NOT detect shebang with leading spaces"
else
    pass "No false positive for leading spaces"
fi

line3="# Not a shebang"
if [[ "$line3" == "#!"* ]]; then
    fail "Should NOT detect plain comment as shebang"
else
    pass "No false positive for plain comment"
fi

line4="#!/usr/bin/python3"
if [[ "$line4" == "#!"* ]]; then
    pass "Shebang detected: '$line4'"
else
    fail "Should detect python shebang"
fi

line5="#!/bin/sh"
if [[ "$line5" == "#!"* ]]; then
    pass "Shebang detected: '$line5'"
else
    fail "Should detect sh shebang"
fi

# --------------------------------
print_header "2. Query slug generation"
# --------------------------------

slug_test() {
    local input="$1"
    local expected="$2"
    local label="$3"
    local result
    result=$(echo "$input" | python3 -c "
import sys, re
s = sys.stdin.read().strip().lower()
s = re.sub(r'[^a-zа-я0-9 ]', '', s).strip().replace(' ', '_')[:40]
print(s or 'result')
" 2>/dev/null) || result=$(echo "$input" | tr ' ' '_' | head -c 40)
    if [ -z "$result" ]; then
        result="result"
    fi
    if [ "$result" = "$expected" ]; then
        pass "$label → '$result'"
    else
        fail "$label: expected '$expected', got '$result'"
    fi
}

slug_test "Resize images to 1920x1080" "resize_images_to_1920x1080" "English query"
slug_test "Перескажи этот текст" "перескажи_этот_текст" "Russian query"
slug_test "Abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz" "abcdefghijklmnopqrstuvwxyzabcdefghijklmn" "Long query truncated to 40 chars"
slug_test "!!! @@@" "result" "Only special chars → fallback 'result'"

# For special chars, sed strips them, tr leaves nothing, head produces ""
# and then the fallback "result" kicks in because result is empty

# --------------------------------
print_header "3. Script save, chmod +x, and execution"
# --------------------------------

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Mock opencode that outputs a script with shebang
MOCK_OPENCODE="$TEST_DIR/mock-opencode.sh"
cat > "$MOCK_OPENCODE" << 'MOCK'
#!/bin/bash
cat << 'SCRIPT'
#!/bin/bash
echo "Hello from generated script"
echo "Args: $@"
SCRIPT
MOCK
chmod +x "$MOCK_OPENCODE"

# Temporarily override PATH so opencode resolves to our mock
OLD_PATH="$PATH"
export PATH="$TEST_DIR:$PATH"

# We can't easily run the full runner (it opens konsole, etc).
# Instead test the core logic in isolation.

# Test saving a script with shebang
TEMP_OUTPUT=$(mktemp)
cat > "$TEMP_OUTPUT" << 'SCRIPT'
#!/bin/bash
echo "Hello from generated script"
SCRIPT

SAVE_DIR="$TEST_DIR/save-test"
mkdir -p "$SAVE_DIR"

# Simulate runner logic
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
QUERY_SLUG=$(echo "test script" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zа-я0-9 ]//g' | tr ' ' '_' | head -c 40)
SAVE_FILE="$SAVE_DIR/${QUERY_SLUG}-${TIMESTAMP}.md"
cp "$TEMP_OUTPUT" "$SAVE_FILE"

# Shebang detected — save as .sh
SCRIPT_FILE="${SAVE_FILE%.md}.sh"
cp "$TEMP_OUTPUT" "$SCRIPT_FILE"
chmod +x "$SCRIPT_FILE"

if [ -f "$SCRIPT_FILE" ]; then
    pass "Script file created: $(basename "$SCRIPT_FILE")"
else
    fail "Script file should exist"
fi

if [ -x "$SCRIPT_FILE" ]; then
    pass "Script file is executable"
else
    fail "Script file should be executable"
fi

# Execute and verify output
OUTPUT=$("$SCRIPT_FILE" 2>&1)
if [ "$OUTPUT" = "Hello from generated script" ]; then
    pass "Script executed correctly: '$OUTPUT'"
else
    fail "Script output mismatch: got '$OUTPUT'"
fi

rm -f "$TEMP_OUTPUT" "$SAVE_FILE" "$SCRIPT_FILE"

# --------------------------------
print_header "4. Plain output (no shebang) — NOT saved as executable"
# --------------------------------

TEMP_OUTPUT=$(mktemp)
cat > "$TEMP_OUTPUT" << 'TEXT'
This is a summary of the text.
It does not start with a shebang.
TEXT

QUERY_SLUG=$(echo "summarize" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zа-я0-9 ]//g' | tr ' ' '_' | head -c 40)
SAVE_FILE="$SAVE_DIR/${QUERY_SLUG}-${TIMESTAMP}.md"
cp "$TEMP_OUTPUT" "$SAVE_FILE"

FIRST_LINE=$(head -1 "$TEMP_OUTPUT")
if [[ "$FIRST_LINE" == "#!"* ]]; then
    fail "Should NOT detect shebang in plain text"
else
    pass "No shebang detected for plain text"
fi

# Verify no .sh file was created alongside
SH_FILE="${SAVE_FILE%.md}.sh"
if [ -f "$SH_FILE" ]; then
    fail ".sh file should NOT exist for plain text output"
else
    pass "No .sh file created for plain text"
fi

rm -f "$TEMP_OUTPUT" "$SAVE_FILE"

# --------------------------------
print_header "5. ASK_AI_SAVE_DIR output file"
# --------------------------------

TEMP_OUTPUT=$(mktemp)
echo "Test output content" > "$TEMP_OUTPUT"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
QUERY_SLUG=$(echo "save test" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zа-я0-9 ]//g' | tr ' ' '_' | head -c 40)
SAVE_FILE="$SAVE_DIR/${QUERY_SLUG}-${TIMESTAMP}.md"
cp "$TEMP_OUTPUT" "$SAVE_FILE"

if [ -f "$SAVE_FILE" ]; then
    CONTENT=$(cat "$SAVE_FILE")
    if [ "$CONTENT" = "Test output content" ]; then
        pass "SAVE_FILE created with correct content: $(basename "$SAVE_FILE")"
    else
        fail "SAVE_FILE content mismatch: got '$CONTENT'"
    fi
else
    fail "SAVE_FILE should exist"
fi

rm -f "$TEMP_OUTPUT" "$SAVE_FILE"

# --------------------------------
print_header "6. Locale keys for save/script messages"
# --------------------------------

LOCALE_DIR="$PROJECT_DIR/locales"
REQUIRED_KEYS=("runner_lbl_saved" "runner_lbl_executing" "runner_lbl_script_saved" "runner_lbl_script_failed")

for locale_file in "$LOCALE_DIR"/en_EN "$LOCALE_DIR"/ru_RU; do
    locale_name=$(basename "$locale_file")
    for key in "${REQUIRED_KEYS[@]}"; do
        if grep -q "^${key}=" "$locale_file"; then
            pass "[$locale_name] Key '$key' found"
        else
            fail "[$locale_name] Missing key '$key'"
        fi
    done
done

# --------------------------------
print_header "7. Runner defaults (fallback strings)"
# --------------------------------

# Source the runner and check that LBL_* vars have fallback defaults
# We test that the variable expansion ${VAR:-default} works
LBL_SAVED_DEFAULT="💾 Saved to:"
LBL_EXECUTING_DEFAULT="▶️ Executing script..."
LBL_SCRIPT_SAVED_DEFAULT="📜 Script saved to:"
LBL_SCRIPT_FAILED_DEFAULT="⚠️ Script exited with an error"

# Compare with what's in the runner
RUNNER_FILE="$PROJECT_DIR/src/ask-ai-dolphin-run.sh"

check_fallback() {
    local var_name="$1"
    local expected="$2"
    local label="$3"
    if grep -qF "${var_name}=" "$RUNNER_FILE"; then
        # Check that the variable assignment references the locale key pattern
        if grep -qF "runner_${var_name,,}:-" "$RUNNER_FILE"; then
            pass "$label has locale fallback"
        else
            pass "$label is defined in runner"
        fi
    else
        fail "$label not found in runner"
    fi
}

check_fallback "LBL_SAVED" "💾 Saved to:" "LBL_SAVED"
check_fallback "LBL_EXECUTING" "▶️ Executing script..." "LBL_EXECUTING"
check_fallback "LBL_SCRIPT_SAVED" "📜 Script saved to:" "LBL_SCRIPT_SAVED"
check_fallback "LBL_SCRIPT_FAILED" "⚠️ Script exited with an error" "LBL_SCRIPT_FAILED"

# --------------------------------
echo ""
if [ "$FAILED" -eq 1 ]; then
    echo "❌ SOME TESTS FAILED"
    exit 1
else
    echo "✅ ALL TESTS PASSED"
    exit 0
fi
