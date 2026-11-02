# openchamber-bin

Arch Linux package for [OpenChamber](https://openchamber.dev) 2.6.0, built from the
official prebuilt release artifacts. Upstream publishes no AUR package; this one
repackages the electron-builder AppImage from the GitHub release, so it follows
upstream version numbers directly instead of a `-git` build.

## What it installs

| Path | Content |
| --- | --- |
| `/opt/openchamber/` | Extracted official AppImage (`x86_64` or `aarch64`) |
| `/usr/bin/openchamber-desktop` | Launcher for the desktop app |
| `/usr/share/applications/openchamber.desktop` | Desktop entry (`Categories=Development`) |
| `/usr/share/icons/hicolor/512x512/apps/openchamber.png` | Icon |

Includes Electron 44 and the bundled OpenCode CLI (`opencode-cli/opencode`, v2.2.5),
so no separate `opencode` install is needed for the desktop app.

There is intentionally **no** `/usr/bin/openchamber`: upstream reserves that name for
the `@openchamber/web` CLI (`npm i -g @openchamber/web`), and both can be installed
side by side. Only the desktop packages conflict.

## Build and install

```bash
makepkg -si          # build from source (downloads the AppImage, ~270 MB)
```

Or use the package built here:

```bash
sudo pacman -U openchamber-bin-2.6.0-1-x86_64.pkg.tar.zst
```

Extraction uses `7z` to read the squashfs payload, so the AppImage is never executed
during the build — a native `aarch64` machine can build the `aarch64` package, and no
FUSE/libfuse2 is required at runtime.

## Dependencies

`depends` covers every shared library the Electron binary links to (derived from the
`NEEDED` entries of the shipped ELFs, resolved against the local package database).
Optional runtime integrations are `optdepends`: `libnotify`, `libsecret`, `libpulse`,
`gtk4`, and the `xdg-desktop-portal` implementations.

## Known behaviour: in-app updates

OpenChamber only self-updates from a real `.AppImage`, `.deb` or `.rpm`; it detects
that by reading a `package-type` marker plus `$APPIMAGE`. A pacman-managed install has
neither, so the app's update check reports:

> Updates require the packaged Linux AppImage, .deb or .rpm. Start OpenChamber from its
> .AppImage file or install a package, not an extracted or repackaged copy.

This is cosmetic — the app runs normally — and it is the correct outcome for a distro
package: updates come from `pacman`. Do **not** work around it by writing
`resources/package-type`; the updater would then try to drive `dpkg`/`rpm`, which Arch
does not have.

## Verification performed for 2.6.0-1

- `sha512` of the downloaded AppImage matched the digest in upstream `latest-linux.yml`,
  and its `sha256` matched the GitHub API asset digest.
- `makepkg -f` completed with the source checksum passing.
- Installed into a throw-away root with `pacman -Udd`: file modes are `755` for
  `openchamber`, `chrome-sandbox`, `opencode-cli/opencode` and the launcher; `644` for
  the desktop entry.
- `desktop-file-validate` passes on the shipped `.desktop`.
- `ldd /opt/openchamber/openchamber` reports no missing libraries.
- The packaged app was launched against a real X/Wayland display: it starts, generates
  its relay identity, and serves the UI; only the update check above fails.
- Sandbox: Chromium's sandbox works through unprivileged user namespaces
  (`chrome-sandbox` stays `755`). The launcher adds `--no-sandbox` only if the kernel
  refuses `unshare --user`, mirroring upstream's Debian/RPM post-install script.

## Publishing to the AUR

The repository here is already initialised with the first commit and the AUR remote
configured, so publishing is:

```bash
ssh aur@aur.archlinux.org            # expect: "Welcome to aur.archlinux.org"
git push -u origin master
```

`.gitignore` already excludes `src/`, `pkg/` and built packages; only the five files
in the commit (`PKGBUILD`, `.SRCINFO`, `.gitignore`, `bump.sh`, `README.md`) go to
the AUR.

## Updating

```bash
./bump.sh            # reads the newest release, rewrites pkgver + sha512sums, refreshes .SRCINFO
./bump.sh --check    # report only
makepkg -f           # rebuild
git commit -am "Update to $(sed -n 's/^pkgver=//p' PKGBUILD)"
git push
```

`bump.sh` converts the base64 `sha512` values from `latest-linux.yml` and
`latest-linux-arm64.yml` into the hex form `makepkg` requires; the parser was checked
against 2.6.0 and reproduces the committed checksums exactly.
