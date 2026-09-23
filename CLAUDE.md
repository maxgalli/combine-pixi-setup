# Combine review sandbox

Claude is usually started inside `HiggsAnalysis/CombinedLimit/` (the Combine
clone), but that clone lives inside this sandbox repo, which provides the
tooling below. Prefer these helpers over ad-hoc commands, and mention them when
the user asks how to check out, build, test or preview something. Full details
are in `README.md` next to this file.

- `combine-pr <N> [--test|--worktree|--rm]`, `combine-pr --list`: check out a
  PR (`gh pr checkout`), `pixi install --locked`, build (`pixi run install`),
  and with `--test` also `pixi run install-tests` + ctest. It does NOT rebase:
  to rebase a PR onto main, check out, `git rebase origin/main`, then build.
- `combine-docs [--build] [--port N]`: mkdocs preview of the clone's docs
  (toolchain in this repo's `pixi.toml`, not Combine's).
- `env.sh`: sourced before starting Claude; activates the Combine pixi env,
  puts these scripts on PATH, exports `COMBINE_MAIN`, `COMBINE_BUILD`,
  `COMBINE_PR_ROOT`.
- Tests: `pixi run ctest --test-dir ../build_combine/test --output-on-failure`.
  The `/test` suffix is required; without it ctest finds 0 tests and exits 0.
- Remotes in the clone: `origin` = cms-analysis upstream, `myself` = user's fork.
- Layout constraints: source must end in `HiggsAnalysis/CombinedLimit`; build
  dir `HiggsAnalysis/build_combine` must stay outside the source tree.
