GREY='\033[90m'
WHITE='\033[97m'
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[94m'
# Desaturated "muted" bar colors. Truecolor lets us dial in dimmed hues; on
# terminals without 24-bit support fall back to the nearest 256-color shades.
if [ "$COLORTERM" = "truecolor" ] || [ "$COLORTERM" = "24bit" ]; then
        GREEN_MUTED='\033[38;2;68;88;70m'
        GREEN_MUTED_BG='\033[48;2;68;88;70m'
        RED_MUTED='\033[38;2;92;68;68m'
        RED_MUTED_BG='\033[48;2;92;68;68m'
        YELLOW_MUTED='\033[38;2;90;84;56m'
        YELLOW_MUTED_BG='\033[48;2;90;84;56m'
        MARKER='\033[38;2;96;184;180m'
else
        GREEN_MUTED='\033[38;5;65m'
        GREEN_MUTED_BG='\033[48;5;65m'
        RED_MUTED='\033[38;5;95m'
        RED_MUTED_BG='\033[48;5;95m'
        YELLOW_MUTED='\033[38;5;101m'
        YELLOW_MUTED_BG='\033[48;5;101m'
        MARKER='\033[38;5;73m'
fi
MARKER="$WHITE" # local override: solid white time-marker instead of peer's teal
DARK='\033[38;5;238m' # local: dark track behind the grey 5h/7d fill
GREY_BG='\033[100m'
NC='\033[0m' # No Color

# Vertical fill glyphs, level 0 (empty) .. 8 (full)
BAR_GLYPHS=(' ' '▁' '▂' '▃' '▄' '▅' '▆' '▇' '█')

# render_bar PCT FILL_FG MUTED_FG MUTED_BG [TIME_POS]
# Renders a 10-cell bar with sub-cell resolution via vertical glyphs. The
# partial cell draws its glyph (fill color) over the muted background so it
# appears to fill up. If TIME_POS is given, that cell is drawn blue and fills
# up in blue where the usage overlaps it.
render_bar() {
        local pct=${1%.*}
        local fill_fg=$2 muted_fg=$3 muted_bg=$4 time_pos=${5:-}
        local total i level bar=""

        total=$(((pct * 80 + 50) / 100))
        [ "$total" -lt 0 ] && total=0
        [ "$total" -gt 80 ] && total=80

        for i in {0..9}; do
                level=$((total - i * 8))
                [ "$level" -lt 0 ] && level=0
                [ "$level" -gt 8 ] && level=8

                if [ -n "$time_pos" ] && [ "$i" -eq "$time_pos" ]; then
                        bar="${bar}${MARKER}█${NC}"
                elif [ "$level" -ge 4 ]; then
                        bar="${bar}${fill_fg}█${NC}"
                else
                        bar="${bar}${muted_fg}█${NC}"
                fi
        done
        echo -e "$bar"
}
