# Git Path Transplanter & Shaded Move 🩺

The Git Path Transplanter suite enables the movement or copying of files and directories while **fully preserving their Git history**. Unlike a standard `mv` or `cp`, which often breaks history or requires complex `subtree` commands, this tool rewrites history into a "monorepo-ready" format and integrates it seamlessly.

---

## 1. How it Works: The History Transformation

When you move or copy a path using this suite, the Git history is rewritten using a `filter-repo` strategy. This ensures that when you run `git log` on the new path, you see the entire timeline as if the files had always lived there.



### The History Branching Logic
When `ACT_LIKE_CP=1` is triggered, the history effectively "forks." The original directory stays at its current commit, while the new directory receives a parallel set of commits that mirror the ancestral history but point to the new location.



---

## 2. Command Shading (The "mv" and "cp" Wrapper)

By using the **Shading Manager**, you can replace standard `mv` and `cp` commands with history-aware versions. 

### Registration Functions
The suite provides 6 functions for granular environment control:

* **`register_git_mv_shade`**: Redirects `mv` to `git_mv_shaded`.
* **`deregister_git_mv_shade`**: Restores standard `mv`.
* **`register_git_cp_shade`**: Redirects `cp` to `git_cp_shaded`.
* **`deregister_git_cp_shade`**: Restores standard `cp`.
* **`register_all_git_shades`**: Enables both enhancements.
* **`deregister_all_git_shades`**: Cleans the environment.

### Shading Decision Logic
The shaded commands only trigger history preservation if:
1.  Exactly **two arguments** are provided (`source` and `destination`).
2.  **No flags** (like `-v`, `-f`, or `-r`) are used.
3.  The operation is occurring **inside a Git repository**.



---

## 3. Usage Examples

### History-Aware Move (Intra-repo)
```bash
# Register shades in your session
register_all_git_shades

# Move a folder; history is automatically extracted, re-prefixed, and merged
mv src/old_feature internal/modules/new_feature

```

### History-Aware Copy (Forking History)

```bash
# This creates a new folder 'legacy_v1' with the full history of 'current_api'
# 'current_api' remains untouched.
cp current_api legacy_v1

```

### Inter-Repo Transplant

```bash
# 1. In Source Repo
extract_git_path ./tools/validator

# 2. In Destination Monorepo
git_path_transplant /tmp/meta_123.json packages/validator-tool

```

---

## 4. Technical Details

### Branch Strategy

The tool creates branches following the pattern: `history/<destination_path>`.

* These are **orphan branches** containing the re-prefixed history.
* Original commit timestamps, authors, and messages are preserved.
* **SHA-1 Hashes** change because the file paths inside the commit objects are modified to match the new destination.

### Path Transformation

Standard extraction creates a root-level history. The transplanter "shifts" this history:

* **Original State:** `Commit A: modified file.js`
* **Transplanted State:** `Commit A: modified packages/new-feature/file.js`

---

## 5. Troubleshooting & FAQ

**Why did my hashes change?**
Git hashes are a checksum of the content *and* the file paths. Since the tool moves files to a new subdirectory within the history, the hashes must be recalculated.

**Can I undo a move?**
Since the tool creates a merge commit, you can undo the operation by resetting your branch:
`git reset --hard HEAD~1`

**Does this work with large repos?**
Yes. Because it uses `git-filter-repo`, it is significantly faster and more memory-efficient than `git filter-branch` or standard `subtree` merges.

---

**Dependencies:**

* `git`
* `git-filter-repo` (Python version a40bce548d2c surely works)
* `jq` (for metadata parsing)
