#!/usr/bin/env bash
# Bump pkgver and the AppImage checksums from the upstream release manifests.
#
#   ./bump.sh          update PKGBUILD + .SRCINFO if upstream has a newer release
#   ./bump.sh --check  only report, change nothing
#
# Source of truth: https://github.com/openchamber/openchamber releases
#   - api/releases/latest            -> newest tag
#   - latest-linux.yml               -> sha512 (base64) of the x86_64 AppImage
#   - latest-linux-arm64.yml         -> sha512 (base64) of the aarch64 AppImage
# makepkg requires hex checksums, so the base64 values are converted.
set -euo pipefail
cd "$(dirname "$0")"

repo='openchamber/openchamber'
check_only=0
[[ ${1:-} == --check ]] && check_only=1

current=$(sed -n 's/^pkgver=//p' PKGBUILD)
latest_tag=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')
latest=${latest_tag#v}

printf 'current: %s\nlatest:  %s\n' "$current" "$latest"
if [[ $(vercmp "$latest" "$current") -le 0 ]]; then
  echo "already up to date"
  exit 0
fi
if (( check_only )); then
  echo "update available; run ./bump.sh to apply"
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

manifest() { # $1 = manifest name, $2 = arch suffix in the asset name
  curl -fsSL "https://github.com/${repo}/releases/download/v${latest}/$1" -o "$tmp/$1"
  python3 - "$tmp/$1" "$2" <<'PY'
import base64, re, sys
text = open(sys.argv[1]).read()
suffix = sys.argv[2]
for block in re.split(r'\n\s*-\s+url:', text)[1:]:
    url = block.splitlines()[0].strip()
    digest = re.search(r'sha512:\s*(\S+)', block)
    if digest and url.endswith(suffix):
        print(base64.b64decode(digest.group(1)).hex())
        break
else:
    sys.exit('no %s entry in %s' % (suffix, sys.argv[1]))
PY
}

x86_64_sum=$(manifest latest-linux.yml -linux-x86_64.AppImage)
aarch64_sum=$(manifest latest-linux-arm64.yml -linux-arm64.AppImage)

[[ ${#x86_64_sum} -eq 128 && ${#aarch64_sum} -eq 128 ]] || {
  echo "unexpected checksum length" >&2
  exit 1
}

sed -i \
  -e "s|^pkgver=.*|pkgver=${latest}|" \
  -e 's|^pkgrel=.*|pkgrel=1|' \
  -e "s|^sha512sums_x86_64=.*|sha512sums_x86_64=('${x86_64_sum}')|" \
  -e "s|^sha512sums_aarch64=.*|sha512sums_aarch64=('${aarch64_sum}')|" \
  PKGBUILD

makepkg --printsrcinfo > .SRCINFO

echo "bumped to ${latest}"
git --no-pager diff -- PKGBUILD .SRCINFO 2>/dev/null || true
echo
echo "next: makepkg -f  (or makepkg -si), then commit and push"
