# Morphe JVM runtime packages

The patcher of [Morphe Manager](https://github.com/MorpheApp/morphe-manager) runs on a build of
the JVM for Linux, which runs on the GNU C library that termux-pacman builds for Android. This
repository is [termux-pacman/glibc-packages](https://github.com/termux-pacman/glibc-packages) with
the few changes Morphe needs on top, and publishes the packages the app embeds as releases.
termux-pacman keeps the latest build of each package alone, so the app downloads them from here.

## Changes to upstream

- `gpkg/glibc`: Android allows a 32-bit ARM app to truncate a file with `ftruncate64` alone and
  ends it on `ftruncate`. Upstream answers `ftruncate64` with `ftruncate`; here both make
  `ftruncate64`, the call bionic makes (`fakesyscall.json`, `ftruncate.c.patch`). 64-bit ABIs
  have `ftruncate` alone, so their builds do not change.
- `morphe/`, `.github/README.md` and `.github/workflows/morphe-release.yml`: the release, see below.

Everything else is upstream as it is. The upstream workflows are disabled in this repository
rather than removed, as they upload to the servers of termux-pacman.

## Merging upstream

```sh
git remote add upstream https://github.com/termux-pacman/glibc-packages
git fetch upstream
git merge upstream/main
```

The changes touch a single line of upstream (`gpkg/glibc/fakesyscall.json`), which conflicts only
when upstream changes that line itself.

## Releasing

Run the **Release runtime packages** workflow with a new tag, such as `gpkg-2`:

- `build`: packages built from the recipes here, named as their files are, such as `glibc-2.44-0`
- `mirror`: packages taken from termux-pacman as they built them, such as `zlib-glibc-1.3.2-0`,
  while their server still has them
- `termux-packages`: the commit of the build scripts of termux-packages, `master` by default

Every package is published for aarch64, arm and x86_64, as `<name>-<version>-<revision>-<arch>.pkg.tar.xz`,
next to the recipe and source it was built from (`*-recipe.tar.xz`, `*-source.tar.*`), as the
LGPL and GPL require, and `SHA256SUMS`. The release notes record the commits and the builder
image. The app pins each package by its SHA-256, see `embeddedJvms` in `app/build.gradle.kts`.

A release is never changed once the app pins it: a new build or version goes to a new tag.
