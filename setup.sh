#!/usr/bin/env bash
# One-time (idempotent) setup of a self-contained Combine review sandbox.
#
# Creates, all under this directory:
#   HiggsAnalysis/CombinedLimit   clone (origin = cms-analysis, myself = fork)
#   HiggsAnalysis/build_combine   out-of-source build dir
#   pr-review/                    per-PR worktrees (only with combine-pr --worktree)
#
# Safe to re-run: it skips whatever already exists.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

UPSTREAM=${COMBINE_UPSTREAM:-https://github.com/cms-analysis/HiggsAnalysis-CombinedLimit.git}
# Your fork, added as remote "myself". Optional: unset means upstream only.
#   COMBINE_FORK=git@github.com:<you>/HiggsAnalysis-CombinedLimit.git ./setup.sh
FORK=${COMBINE_FORK:-}

# The path MUST end in HiggsAnalysis/CombinedLimit: CMakeLists.txt symlinks
# build/HiggsAnalysis/CombinedLimit back to the source root, and the build dir
# must stay outside the source tree or that symlink becomes a path cycle.
SRC="$HERE/HiggsAnalysis/CombinedLimit"

command -v pixi >/dev/null || { echo "setup: pixi not found on PATH" >&2; exit 1; }
command -v gh   >/dev/null || echo "setup: warning - gh not found, PR checkout will not work" >&2

if [ ! -d "$SRC/.git" ]; then
  echo ">>> Cloning $UPSTREAM"
  mkdir -p "$HERE/HiggsAnalysis"
  git clone "$UPSTREAM" "$SRC"
else
  echo ">>> Clone already present at $SRC"
fi

if [ -n "$FORK" ] && ! git -C "$SRC" remote | grep -qx myself; then
  echo ">>> Adding remote 'myself' -> $FORK"
  git -C "$SRC" remote add myself "$FORK"
fi

cd "$SRC"

echo ">>> Solving pixi environment (locked)"
# --locked fails if pixi.lock is out of sync with pixi.toml, the same guard the
# Pixi CI job applies.
pixi install --locked

echo ">>> Building Combine with tests"
pixi run install-tests

echo ">>> Smoke test"
pixi run combine --help >/dev/null && echo "    combine: ok"

cat <<MSG

>>> Setup complete.

    Source the environment with:

        source $HERE/env.sh

MSG
