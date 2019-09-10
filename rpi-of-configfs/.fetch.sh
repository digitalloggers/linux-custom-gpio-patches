#!/bin/sh
mkdir work
cd work
git init .
git remote add linux-stable https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git/
git remote add raspberrypi https://github.com/raspberrypi/linux
git remote update
git branch -r|grep 'raspberrypi/rpi.*\.y$'|while read BRANCH; do
    VERSION="${BRANCH##raspberrypi/rpi-}"
    DIR="patches/${VERSION%%.y}"
    IDX="1"
    for HASH in `git log --reverse --pretty="format:%H" -G cfs_overlay_item linux-stable/linux-"$VERSION".."$BRANCH" `; do
       mkdir -p "$DIR"
       git show "$HASH" > "$DIR/$IDX-$HASH".patch
       IDX="$(($IDX+1))"
    done
done
