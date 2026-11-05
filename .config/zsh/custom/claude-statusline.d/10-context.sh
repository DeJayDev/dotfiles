if [[ "$CTX_WINDOW_SIZE" =~ ^[0-9]+$ ]] && [ "$CTX_WINDOW_SIZE" -gt 0 ]; then
        pct=$((TOKENS * 100 / CTX_WINDOW_SIZE))
else
        pct=0
fi

if [ "$pct" -ge 90 ]; then
        BAR_COLOR="$RED"
        BAR_COLOR_MUTED="$RED_MUTED"
        BAR_COLOR_MUTED_BG="$RED_MUTED_BG"
elif [ "$pct" -ge 75 ]; then
        BAR_COLOR="$YELLOW"
        BAR_COLOR_MUTED="$YELLOW_MUTED"
        BAR_COLOR_MUTED_BG="$YELLOW_MUTED_BG"
else
        BAR_COLOR="$GREEN"
        BAR_COLOR_MUTED="$GREEN_MUTED"
        BAR_COLOR_MUTED_BG="$GREEN_MUTED_BG"
fi

BAR=$(render_bar "$pct" "$BAR_COLOR" "$BAR_COLOR_MUTED" "$BAR_COLOR_MUTED_BG")

lines[0]="[$MODEL_DISPLAY] ${BAR} ${WHITE}${pct%.*}%${NC} ($TOKENS/$CTX_WINDOW_SIZE)"
