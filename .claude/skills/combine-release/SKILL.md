---
name: combine-release
description: Use when cutting a new tagged release of CMS Combine (HiggsAnalysis-CombinedLimit) — bumping the version string across bin/combine.cpp, docs/index.md, and the test reference files on a cut_vX.Y.Z branch, validating with scripts/check-version.sh, pushing the branch to the user's fork for a PR, and after the PR is merged creating the tag and GitHub release. Triggers on "release vX.Y.Z", "cut a Combine release", "bump the Combine version", "make a new tag".
---

# Cutting a Combine release

Automates the release checklist in `contributing.md` ("Creating a New
Release"). The **golden rule**: the repo ships its own validator,
`scripts/check-version.sh vX.Y.Z`, which checks every file that must be
updated. Your job is to make that script pass, then handle git and the
GitHub release. Treat a clean `check-version.sh` as the definition of
"the edits are done".

Run everything from the repository root (the dir containing
`bin/combine.cpp` and `scripts/check-version.sh`).

**`main` is protected upstream: nothing is ever pushed to it directly.**
The version bump goes in through a pull request like any other change:

1. commit on a local branch `cut_vX.Y.Z`, created from up-to-date
   upstream `main`;
2. push that branch to the user's fork (remote `myself`,
   `maxgalli/HiggsAnalysis-CombinedLimit`);
3. the user opens the PR from the GitHub web UI and merges it once CI
   passes — you do not open or merge it;
4. after the merge, the tag and GitHub release are created together with
   `gh release create`, which puts the tag on upstream `main`.

Remotes in the clone: `origin` = `cms-analysis` upstream, `myself` = the
user's fork. Check with `git remote -v` before pushing.

## Input

The target version, `vX.Y.Z` (e.g. `v10.7.0`). If the user didn't give
one, ask. Validate the format `^v[0-9]+\.[0-9]+\.[0-9]+$` — reject
anything else (that's the same regex `check-version.sh` enforces).

## Hard guardrails

- **Never push anything to `origin` (upstream)** — no branch, no `main`,
  no tag. Upstream `main` only changes through the merged PR, and the tag
  is created by `gh release create` (step 8).
- **Never push to the fork or create a GitHub release without explicit
  confirmation** in that turn — these are public and hard to undo. Never
  open or merge the PR yourself; the user does that in the GitHub UI.
  Creating the branch, editing files, running the checker, and
  committing locally are fine to do directly.
- **Never create the tag locally or before the PR is merged.** GitHub may
  merge with a new commit (merge/squash/rebase), so the release commit is
  only known once it is on upstream `main`.
- **`check-version.sh` MUST pass before you commit.** Do not commit a
  partial bump.
- **Never claim the test references were regenerated unless you
  actually ran the regeneration** (or the checker confirms they already
  carry the new version). Fabricating this ships broken tests.

## Procedure

### 1. Preflight

- Make sure the tree has no uncommitted changes (`git status`). If it
  does, stop and ask — do not stash or discard them yourself.
- Make sure the tag and branch are new: `git ls-remote --tags origin
  vX.Y.Z` must print nothing, and `cut_vX.Y.Z` must not exist locally or
  on `myself` (`git branch --list cut_vX.Y.Z`,
  `git ls-remote --heads myself cut_vX.Y.Z`). If either exists, stop and
  ask.
- Create the release branch from **up-to-date upstream** `main` (not a
  possibly stale local `main`):
  ```bash
  git fetch origin
  git switch -c cut_vX.Y.Z origin/main
  ```
- Find the **current** version so replacements are exact:
  `grep combineTagString bin/combine.cpp` → e.g. `v10.6.0`. Call it
  `vOLD`. You'll replace `vOLD` → the new version in the edits below.

### 2. Edit `bin/combine.cpp`

Change the tag line:
`std::string combineTagString = "vOLD";` → `"vX.Y.Z";`
(around line 36; it's the only `combineTagString` assignment).

### 3. Edit `docs/index.md`

Three edits on the "recommended tag" block:

- The recommended-tag sentence:
  `Currently, the recommended tag is **vOLD**` → `**vX.Y.Z**`
- The release-notes link on that same line:
  `.../releases/tag/vOLD` → `.../releases/tag/vX.Y.Z`
- The clone command: `--branch vOLD` → `--branch vX.Y.Z`

(The CMSSW release name, e.g. `CMSSW_14_1_0_pre4`, changes only if the
release actually moves CMSSW versions — leave it unless the user says
so.)

### 4. Update the test reference files — ASK the user which path

The reference `.out` files in `test/references/` embed the version as a
marker `<<< vX.Y.Z >>>`, which `check-version.sh` verifies. There are
**two legitimate ways** to update them, and you must **ask the user
which applies** — do not assume:

> *"Does this release change anything that affects Combine's numerical
> output or behaviour, or are the results unchanged (docs-only,
> refactor, build/tooling)? If results are unchanged I can just bump the
> version marker in the reference files; otherwise they must be
> regenerated."*

**Path A — regenerate** (results may have changed). Requires a build
compiled with `-DBUILD_TESTS=TRUE`. In this sandbox the build tree is
out of source at `$COMBINE_BUILD` (`../build_combine`), and
`pixi run install-tests` produces a tests-enabled build. The reference
files are re-produced by actually re-running Combine:
```bash
pixi run install-tests
cd "$COMBINE_BUILD/test"
sh create_reference_files.sh
cp *.out "$COMBINE_MAIN/test/references"
cd "$COMBINE_MAIN"
```
If `$COMBINE_BUILD/test/create_reference_files.sh` does not exist, the
build was configured without tests: run `pixi run install-tests` first —
**do not fake it.**

**Path B — version-marker replacement only** (results unchanged). When
the release does not affect results, the outputs are identical except
for the embedded version, so replace the marker in the reference files
that carry one.

**First, inspect what markers are actually present** — do NOT assume
every file is at the current version. Some files can lag at an older tag
(they were not regenerated in a past release):
```bash
grep -rho "<<< v[0-9.]* >>>" test/references/*.out | sort | uniq -c
```
If any file's marker is **not** the current `vOLD` (e.g. one shows an
older `v10.5.1` while the repo is at `v10.6.0`), **surface it to the
user**: that file was not regenerated last time, so "results unchanged"
may not truly hold for it — they may want Path A for those specific
files. Do not silently bump a file that could be genuinely stale.

Then replace **any** version marker (not just `vOLD`) with the target:
```bash
# Linux:
grep -rlE "<<< v[0-9]+\.[0-9]+\.[0-9]+ >>>" test/references/*.out \
  | xargs sed -i -E "s/<<< v[0-9]+\.[0-9]+\.[0-9]+ >>>/<<< vX.Y.Z >>>/g"
# macOS: use `sed -i ''` instead of `sed -i`.
```
This touches only files that contain a marker (some `.out` files, e.g.
`text2workspace` output, have none and need nothing).

Either path, `check-version.sh` in the next step validates the result —
so a wrong choice or a missed file is caught, not shipped.

### 5. Validate — the gate for committing

```bash
./scripts/check-version.sh vX.Y.Z
```

Read its output and **fix what it reports**, then re-run until clean:

- `bin/combine.cpp` FAIL → revisit step 2.
- `docs/index.md` (recommended tag / git clone branch) FAIL → step 3.
- release-notes link **WARNING** → **expected and OK** pre-release; the
  link resolves only once the GitHub release exists (step 8).
- `test/references/*.out` FAIL → step 4 (references are stale / wrong
  version).

Only proceed when the script reports no FAILs (the release-notes WARNING
is acceptable).

### 6. Commit on the release branch (local — safe)

Confirm you are on `cut_vX.Y.Z` (`git branch --show-current`), then:

```bash
git add bin/combine.cpp docs/index.md test/references/*.out
git commit -m "Update version to vX.Y.Z"
```

### 7. Push to the fork and hand over the PR — CONFIRM FIRST

Show the user the commit (`git show --stat HEAD`), then **stop and
confirm** before pushing. After explicit confirmation, push to the fork
only:

```bash
git push -u myself cut_vX.Y.Z
```

Then hand over to the user. They open the PR themselves in the GitHub
UI, from `maxgalli:cut_vX.Y.Z` into `cms-analysis:main`. Give them the
compare link:
`https://github.com/cms-analysis/HiggsAnalysis-CombinedLimit/compare/main...maxgalli:HiggsAnalysis-CombinedLimit:cut_vX.Y.Z`

They merge it once CI passes. **Do not open or merge the PR, and do not
continue to step 8 until the user says it is merged.** While waiting you
may help read CI results (`gh pr checks <N>`); if CI fails, fix it with
new commits on `cut_vX.Y.Z`, re-run `check-version.sh`, and push to
`myself` again (with confirmation).

### 8. Tag + GitHub release after the merge — CONFIRM FIRST

Once the user says the PR is merged:

1. Fetch and verify that upstream `main` really carries the release:
   ```bash
   git fetch origin
   git show origin/main:bin/combine.cpp | grep combineTagString   # must show vX.Y.Z
   ```
   Use the merged commit on `origin/main` as the release target:
   `REL_SHA=$(git rev-parse origin/main)`. If more PRs were merged after
   the release PR, ask the user which commit to tag instead of assuming
   the tip.
2. Draft release notes. They need real content — offer to summarize
   changes since `vOLD` (`git log vOLD..$REL_SHA --oneline`) as a starting
   point, but let the user edit them.
3. After explicit confirmation, create the release. `gh release create`
   also creates the tag `vX.Y.Z` on upstream at `--target` — no local tag
   and no `git push` of a tag:
   ```bash
   gh release create vX.Y.Z --repo cms-analysis/HiggsAnalysis-CombinedLimit \
     --target "$REL_SHA" --title "vX.Y.Z" --notes-file <notes>
   ```
   Or the user creates it in the Releases page UI, choosing "Create new
   tag: vX.Y.Z on publish" with target `main`.

Creating the release is what makes the docs release-notes link (the
step-5 WARNING) resolve. Afterwards, `git fetch origin --tags` so the new
tag is visible locally, and offer to delete the merged local branch
(`git branch -d cut_vX.Y.Z`).

### 9. Verify docs deployment

Remind the user: CI builds and deploys the docs for the new tag
automatically. Once it finishes, confirm the
[published docs](http://cms-analysis.github.io/HiggsAnalysis-CombinedLimit/)
show `vX.Y.Z`.

## Summary of what you automate vs. gate

- **Automate directly:** create `cut_vX.Y.Z` from `origin/main`, find
  current version, edit the 3 files, and — once the reference-file path
  is decided (step 4) — run the checker in a fix→recheck loop,
  `git add`/`commit` once clean. The Path B marker replacement is safe to
  do directly.
- **Ask the user:** which reference-file path to take (step 4) — results
  changed → regenerate (Path A), unchanged → marker replacement (Path B).
- **Gate (confirm first):** regenerating references needs a
  `BUILD_TESTS` build (step 4 Path A); pushing `cut_vX.Y.Z` to `myself`
  (step 7); creating the tag + GitHub release after the merge (step 8).
- **User does it, never you:** opening and merging the PR (step 7).
- **Never:** any push to `origin`, a local tag, or a direct change to
  `main`.
