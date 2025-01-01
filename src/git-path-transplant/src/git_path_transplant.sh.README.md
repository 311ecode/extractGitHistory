# git-path-transplant – History-Preserving Path Transplant & Move

**Move or copy files/directories inside a git repository (or between repositories) while preserving full history.**

Two main commands:

- `git_path_move`       → move (source disappears, like `git mv` with history)
- `git_path_transplant` → copy/transplant history into new location (source preserved)

## Main Features

- Preserves full commit history of moved/copied path
- Works with deep/nested paths (automatically creates parent directories)
- Supports intra-repo moves, inter-repo transplants
- Optional **copy-like** behavior (`cp -r` semantics)
- Optional **rebase** instead of merge when transplanting
- Shaded aliases: `mv` / `cp` can be overridden to use git-aware versions

## Basic Usage

```bash
# Simple intra-repo move (like git mv but with history)
git_path_move old/path new/location

# Transplant (copy with history) from another repo using metadata
git_path_transplant /path/to/meta.json new/destination

# Copy instead of move (source preserved)
GIT_PATH_TRANSPLANT_ACT_LIKE_CP=1 git_path_move dir_a backup/dir_a
```

## All Supported Environment Variables

| Variable                                      | Default       | Meaning / Effect                                                                                  | Typical values / examples                   |
|-----------------------------------------------|---------------|---------------------------------------------------------------------------------------------------|---------------------------------------------|
| `GIT_PATH_TRANSPLANT_ACT_LIKE_CP`             | unset         | When set (any value), `git_path_move` behaves like copy instead of move (source is preserved)    | `1`, `true`, `yes`                          |
| `GIT_PATH_TRANSPLANT_USE_REBASE`              | unset         | When set, use `git rebase` instead of `git merge` when transplanting history (cleaner linear history) | `1`, `true`                                 |
| `GIT_PATH_TRANSPLANT_SKIP_DIRTY_CHECK`        | unset         | Skip dirty working directory check before transplant (dangerous – use only if you know what you're doing) | `1`                                         |
| `GIT_PATH_TRANSPLANT_SKIP_DESTINATION_CHECK`  | unset         | Skip checking if destination path already exists (can overwrite – dangerous)                     | `1`                                         |
| `GIT_PATH_TRANSPLANT_FORCE`                   | unset         | Force operation even in unsafe conditions (implies above two skips + more aggressive behavior)  | `1`                                         |
| `GIT_PATH_TRANSPLANT_NO_HISTORY_BRANCH`       | unset         | Do not create `history/<new-path>` backup branch after operation                                 | `1`                                         |
| `GIT_PATH_TRANSPLANT_DEBUG`                   | unset         | Enable verbose debug output during transplant/move operations                                    | `1`, `true`                                 |
| `GIT_PATH_TRANSPLANT_VERBOSE`                 | unset         | Slightly less noisy verbose output (progress messages)                                           | `1`                                         |
| `DEBUG`                                       | unset         | General debug flag – enables extra output in many parts of the codebase                          | `1`, `true` (very common convention)        |

### Shading-related environment variables (rarely used directly)

| Variable                              | Meaning                                                                                 | Recommended way to control                  |
|---------------------------------------|-----------------------------------------------------------------------------------------|---------------------------------------------|
| `GIT_PATH_TRANSPLANT_NO_SHADE_MV`     | Prevent automatic creation of `mv` alias (shaded git-aware version)                    | Use `register_git_mv_shade` / `deregister`  |
| `GIT_PATH_TRANSPLANT_NO_SHADE_CP`     | Prevent automatic creation of `cp` alias                                                | Use `register_git_cp_shade` / `deregister`  |
| `GIT_PATH_TRANSPLANT_NO_AUTO_REGISTER`| Do not automatically register shades on script load                                     | —                                           |

## Recommended Safety Workflow (Most Common)

```bash
# 1. Extract path from source repo (creates metadata + clean repo)
meta=$(extract_git_path ./src/featureX)

# 2. Transplant safely into current repo
git_path_transplant "$meta" modules/featureX-v2

# Or with rebase for cleaner history:
GIT_PATH_TRANSPLANT_USE_REBASE=1 git_path_transplant "$meta" modules/featureX-v2

# 3. Or just copy inside same repo with history:
GIT_PATH_TRANSPLANT_ACT_LIKE_CP=1 git_path_move legacy/code new-home/code-v2
```

## Quick Reference Table – What to Set When

Goal                                            | Recommended ENV setting(s)                              | Command example
-----------------------------------------------|----------------------------------------------------------|--------------------------------------------------------------------------------
Classic move + history                            | (default)                                                | `git_path_move old new`
Copy instead of move                              | `GIT_PATH_TRANSPLANT_ACT_LIKE_CP=1`                      | `git_path_move ...`
Clean linear history on transplant                | `GIT_PATH_TRANSPLANT_USE_REBASE=1`                       | `git_path_transplant ...`
Debug problems                                    | `DEBUG=1` or `GIT_PATH_TRANSPLANT_DEBUG=1`               | — 
Very dangerous override (not recommended)         | `GIT_PATH_TRANSPLANT_FORCE=1`                            | — 
Skip safety checks (experts only)                 | `GIT_PATH_TRANSPLANT_SKIP_DIRTY_CHECK=1` + destination skip | — 

## Important Notes

- All safety checks (dirty tree, destination exists, ignored path) are **on by default**
- Force flags should be used **very carefully** – they can cause data loss
- History branches (`history/...`) are created by default for traceability
- Temporary files from `extract_git_path` are **not** automatically cleaned (good practice: clean `/tmp/extract-git-path/*` occasionally)

Good transplanting! 🌱→🌳

