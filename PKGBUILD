# Maintainer: Cnagnn <yogapratamaputrar@gmail.com>
# Upstream publishes no AUR package; this one repackages the official
# electron-builder AppImage from the GitHub release, so it tracks upstream
# version numbers exactly.

pkgname=openchamber-bin
pkgver=2.6.0
pkgrel=1
pkgdesc="Desktop app for OpenChamber, the agentic development environment (official prebuilt release)"
arch=('x86_64' 'aarch64')
url="https://openchamber.dev"
license=('MIT')
depends=(
  'alsa-lib'
  'at-spi2-core'
  'cairo'
  'dbus'
  'expat'
  'glib2'
  'glibc'
  'gtk3'
  'libcups'
  'libglvnd'
  'libx11'
  'libxcb'
  'libxcomposite'
  'libxdamage'
  'libxext'
  'libxfixes'
  'libxkbcommon'
  'libxrandr'
  'mesa'
  'nspr'
  'nss'
  'pango'
  'systemd-libs'
  'util-linux'
)
makedepends=('7zip')
optdepends=(
  'libnotify: native desktop notifications'
  'libsecret: store credentials in the system keyring'
  'libpulse: audio in screen sharing and voice features'
  'gtk4: native GTK4 dialogs where the desktop provides them'
  'xdg-desktop-portal: file pickers and screen capture'
  'xdg-desktop-portal-gtk: portal implementation for GTK desktops'
  'xdg-desktop-portal-kde: portal implementation for KDE Plasma'
)
provides=('openchamber-desktop')
conflicts=('openchamber-desktop' 'openchamber-desktop-git' 'openchamber-desktop-appimage' 'openchamber-desktop-bin')
options=('!strip' '!debug' '!emptydirs')

_upstream="https://github.com/openchamber/openchamber/releases/download/v${pkgver}"

source_x86_64=("${_upstream}/OpenChamber-${pkgver}-linux-x86_64.AppImage")
source_aarch64=("${_upstream}/OpenChamber-${pkgver}-linux-arm64.AppImage")

# sha512 digests of the release AppImages. Upstream publishes them base64-encoded
# in latest-linux.yml / latest-linux-arm64.yml; makepkg wants hex, which is what
# bump.sh converts. Refresh both with: ./bump.sh
sha512sums_x86_64=('32f494e34af14cedf8896ffd750919f640a7f6fc2d169cb8ecf66ae876b92a88cc51f1a7b9dacc0f59040c39a85378eed011eb614f873dea5d1e214b5219f9a4')
sha512sums_aarch64=('6058b41fe7059be1fd356143b3ae5c2337e336fe37f89958bd920e51167b7e63e5bbb5d0ae7619bc8bece6ad7fdd1483e82270a6f195f90163cc5b88b69e7378')

_optdir=/opt/openchamber
_launcher=openchamber-desktop

prepare() {
  cd "$srcdir"

  # Extraction must not execute the AppImage: 7zip reads the squashfs directly,
  # so an aarch64 package can be built on an x86_64 host (and vice versa).
  local _asset
  case "$CARCH" in
    x86_64) _asset="OpenChamber-${pkgver}-linux-x86_64.AppImage" ;;
    aarch64) _asset="OpenChamber-${pkgver}-linux-arm64.AppImage" ;;
  esac

  7z x -bd -y -o"$srcdir/app" "$_asset" >/dev/null

  # 7zip keeps the recorded modes, but directories and the AppImage-only
  # helpers are normalised so the package is reproducible regardless of the
  # extractor used.
  find "$srcdir/app" -type d -exec chmod 755 {} +
  chmod 755 \
    "$srcdir/app/openchamber" \
    "$srcdir/app/chrome-sandbox" \
    "$srcdir/app/chrome_crashpad_handler" \
    "$srcdir/app/resources/opencode-cli/opencode" \
    "$srcdir/app/resources/ripgrep/rg"
}

package() {
  install -d "$pkgdir$_optdir"
  cp -a "$srcdir/app/." "$pkgdir$_optdir/"

  # AppImage-only glue: AppRun sets up the bundle's own library path, and the
  # two symlinks exist so the runtime can find the icon. None are needed for an
  # installed copy, and upstream deliberately does not ship a /usr/bin/openchamber
  # link because that name belongs to the @openchamber/web CLI.
  rm -f "$pkgdir$_optdir/AppRun" \
        "$pkgdir$_optdir/.DirIcon" \
        "$pkgdir$_optdir/openchamber.png"

  install -Dm644 "$srcdir/app/usr/share/icons/hicolor/512x512/apps/openchamber.png" \
    "$pkgdir/usr/share/icons/hicolor/512x512/apps/openchamber.png"

  sed -e 's|^Exec=.*|Exec='"$_launcher"' %U|' \
      -e '/^X-AppImage-Version=/d' \
      "$srcdir/app/openchamber.desktop" > "$srcdir/openchamber.desktop"
  install -Dm644 "$srcdir/openchamber.desktop" \
    "$pkgdir/usr/share/applications/openchamber.desktop"

  install -d "$pkgdir/usr/bin"
  cat > "$pkgdir/usr/bin/$_launcher" <<'EOF'
#!/bin/sh
# Chromium's sandbox needs either a setuid helper or unprivileged user namespaces.
# Mirrors upstream's Linux after-install script: on kernels without working user
# namespaces, fall back to --no-sandbox so the app still starts.
if ! { [ -L /proc/self/ns/user ] && unshare --user true; } 2>/dev/null; then
  set -- --no-sandbox "$@"
fi
exec /opt/openchamber/openchamber "$@"
EOF
  chmod 755 "$pkgdir/usr/bin/$_launcher"
}
