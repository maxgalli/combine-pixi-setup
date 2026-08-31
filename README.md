# Combine review sandbox

A self-contained environment for building Combine, reviewing PRs, and driving
all of it with Claude Code. Native macOS/arm64 — no container, no CVMFS, no
CMSSW. `pixi.lock` carries `root 6.34.10` for `osx-arm64`, so everything builds
directly on Apple Silicon.

Files that need CERN storage are out of scope by design: `scp` them from lxplus.

## Layout

Everything lives under this directory and nothing leaks into your other
checkouts:

```
pixi_dev/
├── setup.sh                        one-time setup (idempotent)
├── env.sh                          source this in every new shell
├── combine-pr                      PR checkout + build + test
├── HiggsAnalysis/
│   ├── CombinedLimit/              the clone  (origin=cms-analysis, myself=fork)
│   │   └── .pixi/                  the pixi environment
│   └── build_combine/              out-of-source build tree
└── pr-review/                      per-PR worktrees (only with --worktree)
```

## First time

```sh
./setup.sh
```

Clones Combine, adds your fork as `myself`, solves the pixi environment with
`--locked`, builds with tests, and smoke-tests the binary. Re-running it is
safe — it skips what already exists.

## Every session

```sh
source ~/Software/Postdoc/Combine/combine-dev/pixi_dev/env.sh
```

That activates the pixi environment (via `pixi shell-hook`, so it works in your
current shell instead of spawning a subshell), puts `combine-pr` on `PATH`,
exports `COMBINE_MAIN` / `COMBINE_BUILD` / `COMBINE_PR_ROOT`, and drops you in
the clone. Afterwards `combine`, `text2workspace.py` and friends are just on
your `PATH`.

Worth adding to `~/.zshrc` as an alias:

```sh
alias combine-sandbox='source ~/Software/Postdoc/Combine/combine-dev/pixi_dev/env.sh'
```

## Reviewing a PR

```sh
combine-pr 1250 --test      # check out, build with tests, run ctest
combine-pr 1250             # build only
combine-pr 1250 --worktree  # isolate in its own worktree
combine-pr 1250 --rm        # remove that worktree
combine-pr --list           # show worktrees
```

In-place checkout is the default: this clone exists only for reviewing, so
moving its branch costs nothing and one shared pixi environment gives you fast
incremental rebuilds. Reach for `--worktree` only when two PRs need to be alive
at once — each worktree gets its own `.pixi/` environment.

## Driving it with Claude

Start Claude Code from inside the sandbox (`env.sh` already put you there):

```sh
claude
```

`gh` is authenticated from your normal login, so Claude can read PRs, diffs,
review comments and CI results directly. Things it can do from here:

- *"Check out PR 1250 and run the tests"* — it runs `combine-pr 1250 --test`.
- *"Show me the review comments from guitargeek on PR 1250 and implement them"*
  — it reads them via `gh api .../pulls/1250/comments` and edits the code.
- *"Why is the codecov check failing?"* — `gh pr checks` plus the codecov API.
- *"Build this and run the RooBernsteinFast test"* — `pixi run install-tests`
  then ctest.
- `/code-review 1250` — the built-in review skill, with `--comment` to post
  findings as inline PR comments.

Because Claude is working in *this* clone, nothing it checks out or rebuilds
touches whatever branch you have open in your own working copy.

## Running the tests by hand

```sh
pixi run ctest --test-dir ../build_combine/test --output-on-failure
```

**Note the `/test` suffix.** `enable_testing()` is called in
`test/CMakeLists.txt`, not at the top level, so tests register in the `test/`
subdirectory of the build tree. Pointing ctest at `../build_combine` instead
reports **0 tests and exits 0** — a green run that proves nothing. There are 40
registered tests.

## Layout constraints (do not "tidy" these away)

- The source must sit at a path ending in `HiggsAnalysis/CombinedLimit`, because
  `CMakeLists.txt` symlinks `build/HiggsAnalysis/CombinedLimit` back to the
  source root.
- The build dir must live *outside* the source tree, or that symlink becomes an
  infinite path cycle. The `pixi.toml` tasks use `../build_combine`.

## Housekeeping

- `pixi install --locked` fails when `pixi.lock` is out of sync with
  `pixi.toml` — the same guard the Pixi CI job uses. If a PR touches
  dependencies, that is the failure you will see first.
- `pixi run install-tests` leaves `BUILD_TESTS:BOOL=ON` in the CMake cache, so a
  later plain `pixi run install` in the same build dir still builds tests.
  Harmless; delete `HiggsAnalysis/build_combine` if you want a clean slate.
- To reset everything: `rm -rf HiggsAnalysis pr-review && ./setup.sh`.
