claude() {
    printf '\033]0;Claude: %s\007' "${PWD##*/}"
    CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 command claude "$@"
    printf '\033]0;%s\007' "${PWD##*/}"
}
