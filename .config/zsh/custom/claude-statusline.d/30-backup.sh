backup_badge() {
        local target=$1 success=$2 result=$3 check_result=$4
        [ -n "$result" ] || return
        local age=$((EPOCHSECONDS - success))
        if [ "$result" = "fail" ] || [ "$check_result" = "fail" ] || [ "$age" -gt $((26 * 3600)) ]; then
                echo "${RED}bk ${target} fail${NC}"
        elif [ "$age" -gt $((13 * 3600)) ]; then
                echo "${YELLOW}bk ${target} $((age / 3600))h${NC}"
        fi
}

backup_status="${XDG_STATE_HOME:-$HOME/.local/state}/claude-backup/status"
if [ -f "$backup_status" ]; then
        source "$backup_status"
        for badge in "$(backup_badge local "$success_local" "$result_local" "$check_result_local")" \
                "$(backup_badge r2 "$success_r2" "$result_r2" "$check_result_r2")"; do
                [ -n "$badge" ] && lines[1]="${lines[1]} ${badge}"
        done
fi
