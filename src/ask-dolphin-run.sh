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

if [ -z "$QUERY" ]; then
    QUERY="Explain these files"
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
echo -e "${BOLD}${BLUE}║      🤖  Ask AI about selected file(s)   ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}${YELLOW}Selected files:${NC}"
for f in "${FILES[@]}"; do
    if [ -d "$f" ]; then
        echo -e "  ${CYAN}📁 $f${NC}"
    else
        SIZE=$(du -h "$f" 2>/dev/null | cut -f1)
        echo -e "  ${GREEN}📄 $f${NC}  ${BOLD}(${SIZE})${NC}"
    fi
done
echo ""
echo -e "${BOLD}Your question:${NC}"
echo -e "  ${YELLOW}$QUERY${NC}"
echo ""

# --- Build the prompt ---
PROMPT="I have these selected files/directories:
$(printf '%s\n' "${FILES[@]}")

My question about them: $QUERY"

# --- Check opencode ---
if ! command -v opencode &> /dev/null; then
    echo -e "${BOLD}Error: opencode not found in PATH${NC}"
    exit 1
fi

# --- Determine model (from environment or default) ---
MODEL="${ASK_MODEL:-opencode/deepseek-v4-flash-free}"
echo -e "${BOLD}Model:${NC} ${CYAN}${MODEL}${NC}"
echo ""

# --- Stream ---
echo -e "${BOLD}⏳ Streaming AI response...${NC}"
echo ""

if [ "${GLOW_DISABLED:-0}" = "1" ]; then
    # Raw mode (askr)
    opencode run --model "$MODEL" "$PROMPT"
elif command -v glow &> /dev/null; then
    opencode run --model "$MODEL" "$PROMPT" | glow -
else
    echo -e "${YELLOW}glow not found — output without formatting${NC}"
    opencode run --model "$MODEL" "$PROMPT"
fi

echo ""
echo -e "${BOLD}${GREEN}✅ Done. Press Ctrl+C or Enter to close.${NC}"
echo -n ""
read -r 2>/dev/null || true
