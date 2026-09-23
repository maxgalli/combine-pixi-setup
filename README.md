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
combine-pixi-setup/
├── setup.sh                        one-time setup (idempotent)
├── env.sh                          source this in every new shell
├── combine-pr                      PR checkout + build + test
├── .claude/skills/                 Claude skills (symlinked into the clone)
├── HiggsAnalysis/
│   ├── CombinedLimit/              the clone  (origin=cms-analysis, myself=fork)
│   │   └── .pixi/                  the pixi environment
│   └── build_combine/              out-of-source build tree
└── pr-review/                      per-PR worktrees (only with --worktree)
```

## Prerequisites

- [`pixi`](https://pixi.sh) — everything else (ROOT, Python, CMake) comes from it
- `git` and a C++ compiler (on macOS: `xcode-select --install`)
- [`gh`](https://cli.github.com), authenticated (`gh auth login`) — needed for PR checkout
- [Claude Code](https://claude.com/claude-code), optional

Verified on macOS/arm64 with `root 6.34.10` from conda-forge. `pixi.toml` also
lists `linux-64`, `linux-aarch64` and `osx-64`, so Linux should work too, though
it is untested here.

## First time

```sh
./setup.sh
```

To also register your fork as remote `myself`:

```sh
COMBINE_FORK=git@github.com:<you>/HiggsAnalysis-CombinedLimit.git ./setup.sh
```

Clones Combine, adds your fork as `myself`, solves the pixi environment with
`--locked`, builds with tests, and smoke-tests the binary. Re-running it is
safe — it skips what already exists.

## Every session

```sh
source /path/to/combine-pixi-setup/env.sh
```

That activates the pixi environment (via `pixi shell-hook`, so it works in your
current shell instead of spawning a subshell), puts `combine-pr` on `PATH`,
exports `COMBINE_MAIN` / `COMBINE_BUILD` / `COMBINE_PR_ROOT`, and drops you in
the clone. Afterwards `combine`, `text2workspace.py` and friends are just on
your `PATH`.

Worth adding to `~/.zshrc` as an alias:

```sh
alias combine-sandbox='source /path/to/combine-pixi-setup/env.sh'
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

## Previewing the documentation

Combine's docs are a [mkdocs-material](https://squidfunk.github.io/mkdocs-material/)
site under `docs/` in the clone. To see a change rendered before pushing it:

```sh
combine-docs                # live preview on http://127.0.0.1:8000, Ctrl-C to stop
combine-docs --build        # one-off build into the clone's ./site
combine-docs --port 8001    # another port
```

The preview reloads as you edit, so leave it running while you work on a page.

The mkdocs toolchain lives in **this** repo's `pixi.toml`, not in Combine's.
Combine's manifest describes what it takes to *build Combine*, and its docs are
published by `.github/workflows/docs.yml`, which pip-installs mkdocs itself;
adding a docs environment there would push a second environment into that
repo's `pixi.lock` for everyone, to serve a preview only doc authors run. The
versions here match what that workflow installs, so a local preview matches
what gets published.

`site/` is written inside the clone, where Combine's own `.gitignore` already
covers it.

## The Combine MCP server

`.mcp.json` registers the Combine documentation/code MCP server:

```json
{ "mcpServers": { "combine": {
    "type": "http",
    "url": "https://combine-mcp-git-combine-mcp.app.cern.ch/mcp" } } }
```

`setup.sh` symlinks it into the clone, because `env.sh` leaves you *inside* the
clone and that is where Claude Code looks for `.mcp.json`. The symlink is added
to the clone's `.git/info/exclude`, so it never appears as an untracked file
while you review a PR.

MCP servers are registered at startup, so start `claude` after sourcing
`env.sh` — an already-running session will not pick it up. Claude will ask you
to approve the server the first time.

## Claude skills

Sandbox-specific [skills](https://docs.claude.com/en/docs/claude-code/skills)
live in this repo under `.claude/skills/`:

- `combine-release` — cut a tagged Combine release: bump the version in
  `bin/combine.cpp`, `docs/index.md` and the test references, validate with
  `scripts/check-version.sh`, commit and tag locally, and draft the GitHub
  release. It always asks before pushing or publishing anything.

Unlike `CLAUDE.md`, which Claude Code also reads from parent directories,
skills are read only from the `.claude/skills/` of the directory Claude starts
in, which here is the clone. So `setup.sh` symlinks
`HiggsAnalysis/CombinedLimit/.claude/skills` to this repo's `.claude/skills`
and excludes it locally, as it does for `.mcp.json`. Only `skills/` is linked,
so the clone keeps its own `.claude/settings.local.json`. Add new skills here
and they show up in the next `claude` session.

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
