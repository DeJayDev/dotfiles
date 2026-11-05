# Show 5 hour and weekly cost as a bar

make_bar() {
        local pct=$1
        local resets_at=$2
        local window_secs=$3
        local time_pos=""

        if [ -n "$resets_at" ] && [ "$resets_at" != "null" ] && [ -n "$window_secs" ]; then
                local elapsed_secs
                elapsed_secs=$((resets_at - EPOCHSECONDS))
                time_pos=$(((window_secs - elapsed_secs) * 10 / window_secs))
                [ "$time_pos" -lt 0 ] && time_pos=0
                [ "$time_pos" -gt 9 ] && time_pos=9
        fi

        render_bar "$pct" "$GREY" "$DARK" "$GREY_BG" "$time_pos"
}

format_reset() {
        local resets_at=$1
        if [ -z "$resets_at" ] || [ "$resets_at" = "null" ]; then
                echo ""
                return
        fi
        local remaining days hours mins
        remaining=$((resets_at - EPOCHSECONDS))
        [ "$remaining" -lt 0 ] && remaining=0
        days=$((remaining / 86400))
        hours=$(((remaining % 86400) / 3600))
        mins=$(((remaining % 3600) / 60))
        if [ "$days" -gt 0 ]; then
                echo "${days}d${hours}h"
        elif [ "$hours" -gt 0 ]; then
                echo "${hours}h${mins}m"
        else
                echo "${mins}m"
        fi
}

FIVE_H_SEG=""
WEEK_SEG=""

if [ -n "$FIVE_H" ]; then
        FIVE_H_BAR=$(make_bar "$FIVE_H" "$FIVE_H_RESETS" $((5 * 3600)))
        FIVE_H_RESET=$(format_reset "$FIVE_H_RESETS")
        FIVE_H_SEG="${GREY}5h: ${FIVE_H%.*}% ${NC}${FIVE_H_BAR}${NC}"
        [ -n "$FIVE_H_RESET" ] && FIVE_H_SEG="${FIVE_H_SEG}${GREY} (${BLUE}${FIVE_H_RESET}${NC}${GREY})${NC}"
fi

if [ -n "$WEEK" ]; then
        WEEK_BAR=$(make_bar "$WEEK" "$WEEK_RESETS" $((7 * 24 * 3600)))
        WEEK_RESET=$(format_reset "$WEEK_RESETS")
        WEEK_SEG="${GREY}7d: ${WEEK%.*}% ${NC}${WEEK_BAR}${NC}"
        [ -n "$WEEK_RESET" ] && WEEK_SEG="${WEEK_SEG}${GREY} (${BLUE}${WEEK_RESET}${NC}${GREY})${NC}"
fi

if [ -n "$FIVE_H_SEG" ] && [ -n "$WEEK_SEG" ]; then
        lines[2]="${FIVE_H_SEG} | ${WEEK_SEG}"
elif [ -n "$FIVE_H_SEG" ]; then
        lines[2]="$FIVE_H_SEG"
elif [ -n "$WEEK_SEG" ]; then
        lines[2]="$WEEK_SEG"
fi
