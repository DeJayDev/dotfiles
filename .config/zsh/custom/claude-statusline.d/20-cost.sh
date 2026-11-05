lines[1]="${GREY}\$$(printf "%.2f" "$TOTAL_COST")${NC}"

if [ $((LINES_ADDED + LINES_REMOVED)) -gt 0 ]; then
        lines[1]="${lines[1]} ${GREEN}+${LINES_ADDED}${NC} ${RED}-${LINES_REMOVED}${NC}"
fi
