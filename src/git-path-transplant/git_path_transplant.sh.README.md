# Git Path Transplanter – History-Preserving Move & Copy

This toolset enables moving or copying directories (or files) inside a Git repository while **preserving the full history** of the affected paths in a semantically correct way.

Unlike classical `git mv` (which only renames files in the index) or plain filesystem `mv`/`cp` (which breaks history), this solution:

- extracts the history of the selected path(s)
- rewrites the paths inside the commit objects
- grafts the rewritten history back into the main repository

## Core Concepts & Behaviors

### 1. Move operation (history rewrite + source removal)

**Behavior**:  
The entire history of the source path is relocated to the destination path.  
The source path ceases to exist in the repository after the operation.

**Before**  
```
/src/featureX/
  commit A ──► commit B ──► commit C    (history of featureX)
```

**After**  
```
/internal/modules/feature-new/
  commit A' ──► commit B' ──► commit C'   (same metadata, different tree)
```

- Original commits A/B/C are no longer reachable through the current branch
- New commits A'/B'/C' have **identical** author, committer, dates and messages
- Tree objects are different → commit hashes are necessarily different

### 2. Copy operation (history forking)

**Behavior**:  
The history of the source path remains unchanged.  
A **parallel** history chain is created for the destination path.

**Before**  
```
/src/featureX/
  commit A ──► commit B ──► commit C
```

**After**  
```
/src/featureX/
  commit A ──► commit B ──► commit C

/internal/modules/feature-legacy/
  commit A' ──► commit B' ──► commit C'     ← exact metadata copy
```

### 3. Command shading logic – When is history preserved?

| Command                  | Arguments count | Flags present? | Inside git repo? | Result                              |
|--------------------------|-----------------|----------------|------------------|-------------------------------------|
| `mv src dst`             | exactly 2       | no             | yes              | **History move** (source removed)   |
| `cp src dst`             | exactly 2       | no             | yes              | **History copy** (fork)             |
| `cp -r src dst`          | exactly 2       | only -r        | yes              | **History recursive copy** (fork)   |
| any other combination    | any             | any            | any              | Standard shell command (bypass)     |

## Shading Control Functions

```bash
# Enable/disable individual commands
register_git_mv_shade
deregister_git_mv_shade

register_git_cp_shade
deregister_git_cp_shade

# Enable/disable both at once (most common usage)
register_all_git_shades
deregister_all_git_shades
```

## High-Level Workflow (Implementation)

1. **Isolation**  
   Extract all commits that touch the source path into a temporary, flat (root-level) repository.

2. **Path rewriting**  
   Use `git filter-repo --to-subdirectory-filter <destination>`  
   → moves all files into the target directory prefix

3. **Object transfer**  
   Fetch rewritten objects into the original repository

4. **Integration**  
   - Create an orphan branch `history/<destination-path-slug>`  
   - Merge it into current branch with `--allow-unrelated-histories`

## Important Technical Notes

- **Commit hashes always change**  
  Because file paths are part of the tree object, and tree is part of the commit object.

- **Metadata preservation**  
  Author name/email, committer name/email, author date, commit date, and commit message are copied verbatim.

- **Merge nature of operation**  
  Both move and copy end with a merge commit (usually an octopus or simple two-parent merge).

- **Conflict handling**  
  If destination path already contains files, a regular merge conflict occurs and must be resolved manually.

## Limitations & Known Issues

- Does **not** handle submodules correctly (submodule pointers usually break)
- Large directories with thousands of commits can be slow (but still much faster than `filter-branch`)
- Binary files are preserved correctly, but delta compression may suffer after rewrite

## Dependencies

- `git` ≥ 2.25 (recommended ≥ 2.35)
- `git-filter-repo` (Python version ≥ 0.30, commit a40bce5 or newer recommended)
- `jq` (for metadata/branch name parsing)
- standard shell utilities (`mktemp`, `sed`, `grep`, etc.)

## Related Testing Evidence

The following behaviors are explicitly verified by automated tests:

- Full intra-repository move (source disappears, destination appears with history)
- Inter-repository transplant safety (source repository is never modified)
- Deep/nested path creation (`a/b/c` → `x/y/z/deep/feature`)
- Copy with multiple commits + file modifications
- Metadata parity (author, date, message) between original and transplanted chain
- Relative path handling (`../..`, `.`, etc.)
- Bypass when flags are used (`-f`, `-v`, `--backup`, etc.)
- Recursive copy (`cp -r`) forks history correctly

