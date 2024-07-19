alias drop-caches='sudo paccache -rk3; paru -Sc --aur --noconfirm'
alias update-mirrors='export TMPFILE="$(mktemp)"; \
    sudo true; \
    rate-mirrors --disable-comments-in-file --save=$TMPFILE arch --max-delay=21600 \
      && sudo mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-backup \
      && sudo mv $TMPFILE /etc/pacman.d/mirrorlist \
      && drop-caches \
      && paru -Syyu --noconfirm'
