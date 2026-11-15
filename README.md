# SlackBuild

A universal Slackware package builder. It creates a `.txz` package from a
source archive, a binary package, a recipe, or a source tree.

Run it from the directory containing the source file and any optional hook
files.

## Usage

```sh
./SlackBuild [OPTIONS] SOURCE [VERSION] [NAME]
```

`SOURCE` can be:

- a source archive: `.tar.gz`, `.tar.xz`, `.tar.bz2`, `.tar.zst`, `.tar`,
  `.tgz`, `.tbz`, `.tlz`, `.zip`
- a binary package: `.deb`, `.rpm`, `.txz`, `.AppImage`
- a recipe: `.git`, `.url`, `.pip`, `.pkg`
- a skeleton directory named `*.skel`

Examples:

```sh
./SlackBuild foo-1.2.3.tar.gz
./SlackBuild foo-1.2.3.tar.gz 1.2.3 foo
./SlackBuild -o /tmp/packages foo.url
./SlackBuild -s meson foo-1.2.3.tar.xz
./SlackBuild mpv-MASTER-0.42.0.git
./SlackBuild mpv.git MASTER
```

## Options

| Option | Description |
| --- | --- |
| `-o, --output DIR` | Output directory (default: `/tmp`) |
| `-b, --build NUMBER` | Build number (default: today's `YYMMDD`) |
| `-s, --build-system SYS` | Force a build system |
| `-c, --extra-config OPT` | Extra configure/CMake/Meson options |
| `-h, --help` | Show help |

`--build-system` accepts `auto`, `cmake`, `meson`, `autotools`, `make`,
`perl`, `python`, or `pip`.

Options may appear before or after `SOURCE`.

## Unprivileged builds

If the script is run as a normal user and `fakeroot` is available, it
re-executes itself under `fakeroot`. This gives the build a fake root
identity, so `chown` and `makepkg` record `root:root` ownership in the
resulting `.txz` package.

To disable this behavior:

```sh
NO_FAKEROOT=1 ./SlackBuild ...
```

If `fakeroot` is not installed, or if `NO_FAKEROOT=1` is used by a non-root
user, the script prints a warning and the package ownership may not be
`root:root`.

## Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `OUTPUT` | `/tmp` | Package output directory |
| `BUILD` | `YYMMDD` | Package build number |
| `ARCH` | `uname -m` | Target architecture |
| `JOBS` | `nproc` | Parallel build jobs |
| `PREFIX` | `/usr` | Install prefix |
| `LIBDIRSUFFIX` | `64` on 64-bit | Library directory suffix |
| `LIBINSTALLDIR` | `$PREFIX/lib$LIBDIRSUFFIX` | Library install directory |
| `CFLAGS` | `-O2 -fPIC` | C compiler flags |
| `CXXFLAGS` | `-O2 -fPIC` | C++ compiler flags |
| `CMAKEFLAGS` | empty | Extra CMake flags |
| `EXTRACONFIG` | empty | Extra configure/CMake/Meson options |
| `STRIP` | `ON` | Set to `OFF` to skip stripping |
| `NO_FAKEROOT` | `0` | Set to `1` to disable automatic fakeroot |

`VERSION` and `NAME` can also be supplied from the environment, but the
positional arguments are preferred.

## Build-system detection

When no custom build hook is present, detection checks in this order:

1. `meson.build` → Meson
2. `CMakeLists.txt` → CMake
3. `Makefile.PL` → Perl
4. `setup.py`, `pyproject.toml`, `setup.cfg` → Python
5. `configure`, `configure.ac`, `autogen.sh` → Autotools
6. `Makefile`, `GNUmakefile`, `makefile` → make

Use `-s/--build-system` to override detection for source archives.

## Binary packages and recipes

Binary package handling is built into the build stage; no temporary
`NAME-build.sh` is generated.

| Source | Handling |
| --- | --- |
| `.deb` | `ar x` + extract `data.tar.*` into `$PKG` |
| `.rpm` | `rpm2cpio` + `cpio` into `$PKG` |
| `.AppImage` | `--appimage-extract`, install binary, desktop file, icon |
| `.txz` | extract package into `$PKG`; run its `doinst.sh` |
| `.pip` | install PyPI module `$NAME` with `pip --root $PKG` |
| `.skel` | copy the `*.skel` directory into `$PKG` |
| `.pkg` | requires a custom `NAME-build.sh` |

Recipe files:

- `.git`: first field is the repository URL, optional second field is a tag.
  - `MASTER` checks out `master`/`main` and sets `VERSION=GIT$BUILD`.
  - `LATEST` checks out the latest tag, or the tag in the second field.
  - Any other value is treated as a tag.
- `.url`: first field is the download URL.
- `.pip`: installs a PyPI module named `$NAME`.
- `.pkg`: no built-in unpacking; provide `NAME-build.sh`.

Prebuilt `.txz` packages keep their existing `slack-desc` and `doinst.sh`.

## Hooks

All hooks are optional and must be named after `$NAME`:

| File | Purpose |
| --- | --- |
| `NAME-prebuild.sh` | Run before patches and configuration |
| `NAME-configure.sh` | Sourced to override `$CONFIG` |
| `NAME-build.sh` | Custom build recipe; overrides auto-detection |
| `NAME-postbuild.sh` | Run after installation, before stripping |
| `NAME-doinst.sh` | Appended to `install/doinst.sh` |
| `NAME-slack-desc` | Replace the generated `slack-desc` |

A generic `build.sh`, `prebuild.sh`, `configure.sh`, `postbuild.sh`, or
`doinst.sh` is used when the `NAME-` version is absent.

For source archives, `--build-system` takes precedence over a custom build
hook. For binary package types, a custom build hook takes precedence over the
built-in handling.

Custom build hooks receive the traditional Slackware variables:

```text
$PKG $NAME $VERSION $CWD $TMP $SRC $SRCPKG $ARCH $BUILD $OUTPUT
$PREFIX $LIBDIRSUFFIX $LIBINSTALLDIR $CONFIG $EXTRACONFIG
$JOBS $STRIP $CFLAGS $CXXFLAGS $CMAKEFLAGS $ME
```

Minimal custom build hook:

```sh
#!/bin/sh
cd "$SRC" || exit 1
make -j"$JOBS" || exit 1
make install DESTDIR="$PKG" || exit 1
```

## Slackware layout and policy

- Package filename: `name-version-arch-build.txz`.
- Hyphens in `VERSION` become underscores in the package filename.
- Documentation is installed in `/usr/doc/name-version`.
- Man pages are moved to `/usr/man` and gzipped.
- Files under `/etc` are installed as `*.new`; a generated `config()` helper
  in `doinst.sh` handles upgrades. A file named `*.notnew` is installed
  without the `.new` suffix.
- `doinst.sh` refreshes desktop, icon, and GLib schema caches when needed.
- Binaries and shared objects are stripped, `.la` files are removed, and
  permissions are normalized.
- Absolute symlinks are converted to relative symlinks.
- On 64-bit builds, remaining `/usr/lib` content is moved to `/usr/lib64`.
- If `/usr/local` or `/opt` is used by the upstream installer, it is
  flattened into the normal `$PREFIX` layout.
- `slack-desc` is generated with 11 lines when no local file is provided.
  If missing, the script may fetch one from Slackware mirrors or
  SlackBuilds.org.
- A `.dep` file is generated when `requiredbuilder` is installed.

## Notes

- `makepkg` from Slackware's pkgtools is required. `/sbin`, `/usr/sbin`, and
  `/usr/local/sbin` are added to `PATH` automatically so `makepkg` is found.
- The extracted source is left in `./tmp` for inspection.
- The staging directory is removed after a successful build.
- `TMP` is always `./tmp`; it is not read from the environment.
