# shellcheck shell=bash
# Source me:  source /path/to/combine-pixi-setup/env.sh
#
# Activates the Combine pixi environment for the sandbox clone and puts the
# helper scripts on PATH. Leaves you in the clone so `git`, `gh` and `claude`
# all act on it.

# Resolve this file's directory whether sourced from bash or zsh.
if [ -n "${BASH_SOURCE:-}" ]; then
  _combine_env_self="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  # shellcheck disable=SC2296  # zsh-only expansion, guarded by ZSH_VERSION
  _combine_env_self="${(%):-%x}"
else
  echo "env.sh: unsupported shell; use bash or zsh" >&2
  return 1 2>/dev/null || exit 1
fi

COMBINE_DEV_ROOT=$(cd "$(dirname "$_combine_env_self")" && pwd)
export COMBINE_DEV_ROOT
export COMBINE_MAIN="$COMBINE_DEV_ROOT/HiggsAnalysis/CombinedLimit"
export COMBINE_PR_ROOT="$COMBINE_DEV_ROOT/pr-review"
export COMBINE_BUILD="$COMBINE_DEV_ROOT/HiggsAnalysis/build_combine"

if [ ! -d "$COMBINE_MAIN/.git" ]; then
  echo "env.sh: no clone at $COMBINE_MAIN — run ./setup.sh first" >&2
  return 1 2>/dev/null || exit 1
fi

# `pixi shell-hook` prints the activation script for the environment, which is
# the sourceable equivalent of `pixi shell` (that one spawns a subshell, which
# would swallow the rest of this file).
eval "$(pixi shell-hook --manifest-path "$COMBINE_MAIN/pixi.toml")"

case ":$PATH:" in
  *":$COMBINE_DEV_ROOT:"*) ;;
  *) export PATH="$COMBINE_DEV_ROOT:$PATH" ;;
esac

cd "$COMBINE_MAIN" || return 1

echo "Combine sandbox active"
echo "  clone   : $COMBINE_MAIN  ($(git -C "$COMBINE_MAIN" rev-parse --abbrev-ref HEAD))"
echo "  build   : $COMBINE_BUILD"
echo "  combine : $(command -v combine || echo 'not built yet - run: pixi run install-tests')"
echo
echo "  combine-pr <N> [--test]   check out and build a PR"
echo "  combine-docs [--build]    preview the documentation site"
echo "  claude                    start Claude Code in the clone"
