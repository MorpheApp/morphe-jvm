# Morphe JVM runtime packages

The patcher of [Morphe Manager](https://github.com/MorpheApp/morphe-manager) runs on a build of
the JVM for Linux, which runs on the GNU C library that termux-pacman builds for Android. This
repository is [termux-pacman/glibc-packages](https://github.com/termux-pacman/glibc-packages) with
the few changes Morphe needs on top, and publishes the packages the app embeds as releases.
termux-pacman keeps the latest build of each package alone, so the app downloads them from here.

## Changes to upstream

- `gpkg/glibc`: Android ends an app, and every process it starts, on a system call its seccomp
  filter does not allow, which differs between ABIs and Android versions. glibc makes the calls
  bionic makes instead wherever upstream does not already, through `fakesyscall.json` and a few
  patches of the glibc sources (`*.c.patch`). Reported upstream in
  [termux-pacman/glibc-packages#404](https://github.com/termux-pacman/glibc-packages/issues/404):
  once upstream fixes the calls there, a merge takes their fix and these changes go.
- `morphe/`, `.github/README.md`, `.github/workflows/morphe-release.yml` and
  `.github/workflows/morphe-locales.yml`: the release, see below.

Everything else is upstream as it is. The upstream workflows are disabled in this repository
rather than removed, as they upload to the servers of termux-pacman.

## Merging upstream

```sh
git remote add upstream https://github.com/termux-pacman/glibc-packages
git fetch upstream
git merge upstream/main
```

A merge conflicts only where upstream changes what is changed here. A new version of glibc may
move the lines a patch of its sources applies to.

## Releasing

Run the **Release runtime packages** workflow with a new tag, such as `gpkg-3`:

- `build`: packages built from the recipes here, named as their files are, such as `glibc-2.44-0`
- `mirror`: packages taken from termux-pacman as they built them, such as `zlib-glibc-1.3.2-0`,
  while their server still has them
- `termux-packages`: the commit of the build scripts of termux-packages, `master` by default

The packages are built together with their dependencies from the recipes here, so a release does
not depend on the repository of termux-pacman, other than for the packages it mirrors.

Every package is published for aarch64, arm and x86_64, as `<name>-<version>-<revision>-<arch>.pkg.tar.xz`,
next to the recipe and source it was built from (`*-recipe.tar.xz`, `*-source.tar.*`), as the
LGPL and GPL require, and `SHA256SUMS`. The release notes record the commits and the builder
image. The app pins each package by its SHA-256, see `embeddedJvms` in `app/build.gradle.kts`.

A release with glibc also gets `<glibc package>-locales.tar.xz`, the locales the app needs compiled
by the `localedef` of that package, as a compiled locale only fits the glibc that compiled it.
termux-pacman leaves compiling them to `locale-gen` on the device. The files of a locale are the
same on every little-endian architecture, so one archive, `C.UTF-8/LC_*`, serves every ABI. Without
a UTF-8 locale glibc reports ASCII, and the JVM cannot open any path with another character. The
**Release locales** workflow compiles them again for an existing release, with `tag` and `glibc`.

A release is never changed once the app pins it: a new build or version goes to a new tag. The
locales of its glibc are the one thing added to a release later, as they leave every pinned file
as it is.

## When to release

Only when the app needs it, as every release has to be tested on each ABI and on the oldest and
newest Android the app supports:

- Android ends the JVM on a system call, which the app reports as a system call Android blocks
  before it falls back to patching without the JVM
- a security fix in glibc or zlib that matters to reading the files the patcher works on
- a fix of termux-pacman for Android that the JVM needs
