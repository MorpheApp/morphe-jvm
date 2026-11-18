#!/bin/bash
# Puts the corresponding source of a package next to its builds: the recipe that builds it and
# the source the recipe fetches, which the LGPL and GPL have go with the binaries.
#
# Usage: sources.sh <package> <output directory>
# The package is named as its file is, such as glibc-2.44-0 or zlib-glibc-1.3.2-0, and the recipe
# has to build that version, so a package taken from termux-pacman is checked against the recipe.

set -euo pipefail

package=$1
output=$(realpath "$2")
root=$(realpath "$(dirname "$0")/..")

# zlib-glibc-1.3.2-0 is built by gpkg/zlib, glibc-2.44-0 by gpkg/glibc
name=$(sed -E 's/-[^-]+-[^-]+$//' <<< "$package")
recipe=$root/gpkg/${name%-glibc}
[ -f "$recipe/build.sh" ] || { echo "No recipe for $package at $recipe" >&2; exit 1; }

# The recipe only sets variables and defines functions until a build step calls them
eval "$(
    set +u
    # shellcheck source=/dev/null
    . "$recipe/build.sh"
    printf 'version=%q revision=%q url=%q sha256=%q commit=%q\n' \
        "$TERMUX_PKG_VERSION" "${TERMUX_PKG_REVISION:-0}" "$TERMUX_PKG_SRCURL" "$TERMUX_PKG_SHA256" "${_COMMIT:-}"
)"

if [ "$name-$version-$revision" != "$package" ]; then
    echo "$recipe builds $name-$version-$revision, not $package" >&2
    exit 1
fi

mkdir -p "$output"
tar -C "$(dirname "$recipe")" -c "$(basename "$recipe")" | xz -T0 > "$output/$package-recipe.tar.xz"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
case $url in
    git+*)
        git -C "$work" init -q
        git -C "$work" fetch -q --depth 1 "${url#git+}" "$commit"
        git -C "$work" archive --format=tar --prefix="$name-$version/" FETCH_HEAD | xz -T0 > "$output/$package-source.tar.xz"
        ;;
    *)
        # Some sites keep the latest release alone, whose tarball is also published elsewhere
        case $url in
            https://www.zlib.net/*) fallback=https://github.com/madler/zlib/releases/download/v$version/${url##*/} ;;
            *) fallback= ;;
        esac
        curl -fsSL --retry 3 -o "$work/source" "$url" ||
            { [ -n "$fallback" ] && curl -fsSL --retry 3 -o "$work/source" "$fallback"; }
        echo "$sha256  $work/source" | sha256sum -c --quiet
        cp "$work/source" "$output/$package-source.tar.${url##*.tar.}"
        ;;
esac
