#!/bin/bash
# ask-dolphin-run.sh — universal runner for launching opencode in Konsole
# Takes the query as $1, files as $2+
# Shows a header and streams the response through glow

# Clean exit on Ctrl+C (avoids Konsole's "Program error" message)
trap 'echo ""; exit 0' INT

QUERY="$1"
shift

# Filter out empty arguments
FILES=()
for f in "$@"; do
    [ -n "$f" ] && FILES+=("$f")
done

# --- Locale detection (same logic as dialog + install) ---
# Priority: ASK_LOCALE env → $LANG → en_EN
DETECTED_LOCALE="en_EN"
case "${ASK_LOCALE:-}" in
    ru_RU|ru) DETECTED_LOCALE="ru_RU" ;;
    en_EN|en) DETECTED_LOCALE="en_EN" ;;
    *)
        case "${LANG:-}" in
            ru_RU*|ru_UA*|be_BY*|uk_UA*) DETECTED_LOCALE="ru_RU" ;;
        esac
        ;;
esac
LOCALE="$DETECTED_LOCALE"

# Load locale file (check next to script or project root for source runs)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCALE_FILE="$SCRIPT_DIR/locales/$LOCALE"
[ -f "$LOCALE_FILE" ] || LOCALE_FILE="$(dirname "$SCRIPT_DIR")/locales/$LOCALE"
[ -f "$LOCALE_FILE" ] && source "$LOCALE_FILE"

# --- Localized strings (from locale file or inline defaults) ---
HDR_TITLE="${runner_hdr_title:-🤖  Ask AI about selected file(s)}"
LBL_FILES="${runner_lbl_files:-Selected files:}"
LBL_QUESTION="${runner_lbl_question:-Your question:}"
LBL_MODEL="${runner_lbl_model:-Model:}"
LBL_STREAMING="${runner_lbl_streaming:-⏳ Streaming AI response...}"
LBL_GLOW_MISSING="${runner_lbl_glow_missing:-glow not found -- output without formatting}"
LBL_ERR_OPENCODE="${runner_lbl_err_opencode:-Error: opencode not found in PATH}"
LBL_DONE="${runner_lbl_done:-✅ Done. Press Ctrl+C or Enter to close.}"
FALLBACK_QUERY="${runner_fallback_query:-Explain these files}"

# --- Defaults ---
if [ -z "$QUERY" ]; then
    QUERY="$FALLBACK_QUERY"
fi

# If no files provided — use the current directory
if [ ${#FILES[@]} -eq 0 ]; then
    FILES=("$PWD")
fi

# --- Colors ---
BOLD='\033[1m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Header ---
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║      ${HDR_TITLE}   ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}${YELLOW}${LBL_FILES}${NC}"
for f in "${FILES[@]}"; do
    if [ -d "$f" ]; then
        echo -e "  ${CYAN}📁 $f${NC}"
    else
        SIZE=$(du -h "$f" 2>/dev/null | cut -f1)
        echo -e "  ${GREEN}📄 $f${NC}  ${BOLD}(${SIZE})${NC}"
    fi
done
echo ""
echo -e "${BOLD}${LBL_QUESTION}${NC}"
echo -e "  ${YELLOW}$QUERY${NC}"
echo ""

# --- Build the prompt ---
PROMPT="I have these selected files/directories:
$(printf '%s\n' "${FILES[@]}")

My question about them: $QUERY"

# --- Check opencode ---
if ! command -v opencode &> /dev/null; then
    echo -e "${BOLD}${LBL_ERR_OPENCODE}${NC}"
    exit 1
fi

# --- Determine model (from environment or default) ---
MODEL="${ASK_MODEL:-opencode/deepseek-v4-flash-free}"
echo -e "${BOLD}${LBL_MODEL}${NC} ${CYAN}${MODEL}${NC}"
echo ""

# --- Stream ---
echo -e "${BOLD}${LBL_STREAMING}${NC}"
echo ""

if [ "${GLOW_DISABLED:-0}" = "1" ]; then
    # Raw mode (askr)
    opencode run --model "$MODEL" "$PROMPT"
elif command -v glow &> /dev/null; then
    opencode run --model "$MODEL" "$PROMPT" | glow -
else
    echo -e "${YELLOW}${LBL_GLOW_MISSING}${NC}"
    opencode run --model "$MODEL" "$PROMPT"
fi

echo ""
echo -e "${BOLD}${GREEN}${LBL_DONE}${NC}"
echo -n ""
read -r 2>/dev/null || true
