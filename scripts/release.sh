#!/bin/bash
# 打发布 tag：格式 yyyy.mm.dd-sn，sn 为当天第几次构建（自动 +1）
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
git fetch --tags --quiet

today=$(date +%Y.%m.%d)
last=$(git tag -l "${today}-*" | sed "s/^${today}-//" | sort -n | tail -1)
sn=$(( ${last:-0} + 1 ))
tag="${today}-${sn}"

git tag "$tag"
git push origin "$tag"
echo "已推送 tag ${tag}，GitHub Actions 开始构建发布"
