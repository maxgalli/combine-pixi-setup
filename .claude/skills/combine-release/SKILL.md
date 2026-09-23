---
name: combine-release
description: Use when cutting a new tagged release of CMS Combine (HiggsAnalysis-CombinedLimit) — bumping the version string across bin/combine.cpp, docs/index.md, and the test reference files, validating with scripts/check-version.sh, committing, tagging, and drafting the GitHub release. Triggers on "release vX.Y.Z", "cut a Combine release", "bump the Combine version", "make a new tag".
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

## Input

The target version, `vX.Y.Z` (e.g. `v10.7.0`). If the user didn't give
one, ask. Validate the format `^v[0-9]+\.[0-9]+\.[0-9]+$` — reject
anything else (that's the same regex `check-version.sh` enforces).

## Hard guardrails

- **Never `git push`, push a tag, or create a GitHub release without
  explicit confirmation** in that turn — these are public and hard to
  undo. Editing files, running the checker, tagging locally, and
  committing locally are fine to do directly.
- **`check-version.sh` MUST pass before you commit.** Do not commit a
  partial bump.
- **Never claim the test references were regenerated unless you
  actually ran the regeneration** (or the checker confirms they already
  carry the new version). Fabricating this ships broken tests.

## Procedure

### 1. Preflight

- Confirm the working branch is the release branch (usually `main`) and
  the tree has no unrelated uncommitted changes (`git status`).
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

### 6. Commit (local — safe)

```bash
git add bin/combine.cpp docs/index.md test/references/*.out
git commit -m "Update version to vX.Y.Z"
```

### 7. Tag and push — CONFIRM FIRST

Create the annotated tag locally, then **stop and confirm with the user
before pushing** (this publishes the release commit and tag):

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
# after explicit confirmation:
git push origin main
git push origin vX.Y.Z
```

### 8. GitHub release — CONFIRM FIRST

Draft the release from the tag. Release notes need real content — offer
to summarize changes since `vOLD` (`git log vOLD..vX.Y.Z --oneline`) as
a starting point, but let the user edit them. With the `gh` CLI, after
confirmation:

```bash
gh release create vX.Y.Z --title "vX.Y.Z" --notes-file <notes>
```

Or point them at the Releases page to draft it manually. Creating the
release is what makes the docs release-notes link (the step-5 WARNING)
resolve.

### 9. Verify docs deployment

Remind the user: CI builds and deploys the docs for the new tag
automatically. Once it finishes, confirm the
[published docs](http://cms-analysis.github.io/HiggsAnalysis-CombinedLimit/)
show `vX.Y.Z`.

## Summary of what you automate vs. gate

- **Automate directly:** find current version, edit the 3 files, and —
  once the reference-file path is decided (step 4) — run the checker in a
  fix→recheck loop, `git add`/`commit` once clean. The Path B marker
  replacement is safe to do directly.
- **Ask the user:** which reference-file path to take (step 4) — results
  changed → regenerate (Path A), unchanged → marker replacement (Path B).
- **Gate (confirm first):** regenerating references needs a
  `BUILD_TESTS` build (step 4 Path A); pushing branch + tag (step 7);
  creating the GitHub release + notes (step 8).
