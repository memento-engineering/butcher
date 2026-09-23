#!/bin/sh
# Maps a release tag reference to the workspace member it releases.
#
# The org tags one release per package, spelled as the published package name,
# a hyphen, the letter v and the version -- so `butcher_report-v0.2.0-beta.1`
# releases `packages/butcher_report`. With three publishable members the
# release workflow has to know which directory a tag means before it can run a
# dry run, score it or publish it.
#
# This lives in a file rather than inline in the workflow so the validation
# plan can exercise it with a real tag and compare the answer, which a step
# buried in YAML cannot be.
#
# Usage:
#
#   sh .github/parse_release_tag.sh refs/tags/butcher-v0.1.0   # packages/butcher
#
# A bare tag name works as well as a full reference. Prints the member
# directory on stdout and exits 0; exits 1 when the tag names no member and 2
# when it is missing or malformed.
set -eu

ref="${1:-}"
if [ -z "$ref" ]; then
	echo "parse_release_tag: usage: parse_release_tag.sh <tag-ref>" >&2
	exit 2
fi

# `refs/tags/butcher-v0.1.0` and `butcher-v0.1.0` both name the same release.
tag="${ref#refs/tags/}"

case "$tag" in
*-v[0-9]*) ;;
*)
	echo "parse_release_tag: '$tag' is not a <package>-v<version> release tag" >&2
	exit 2
	;;
esac

# Longest match, so the version's own hyphens -- a prerelease suffix like
# `-beta.1` -- stay out of the package name.
package="${tag%%-v[0-9]*}"

case "$package" in
butcher) directory='packages/butcher' ;;
butcher_process) directory='packages/butcher_process' ;;
butcher_report) directory='packages/butcher_report' ;;
*)
	echo "parse_release_tag: '$package' is not a member of this workspace" >&2
	exit 1
	;;
esac

printf '%s\n' "$directory"
