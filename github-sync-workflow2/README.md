# GitHub Sync Workflow v2 (Sidecar Discovery)

## The Origin & Rational
The original `github-sync-workflow` relied on a centralized `.github-sync.yaml` file. While effective for small setups, it became a **maintenance bottleneck** in a rapidly evolving monorepo:
1. **Fragility**: Renaming a folder required a manual update to the central YAML, or the sync would break.
2. **History Pollution**: Configuration files placed *inside* project folders were accidentally exported to the public GitHub repositories.
3. **Scalability**: A single master list is a "hot spot" for merge conflicts in a multi-user monorepo.

**The Solution**: `github-sync-workflow2` introduces **Locality without Pollution**. By using "Sidecar" directories, we keep the sync configuration right next to the code, but technically outside the export path.

---

## Architecture: The Sidecar Pattern
Instead of a central registry, the workflow performs a recursive discovery of project "markers."

### Directory Structure


```text
monorepo/
├── util/
│   ├── memoize/                 <-- The "Origin" Project (Pure Code)
│   └── memoize-github-sync.d/   <-- The "Sidecar" (Metadata)
│       └── sync                 <-- The Marker File

```

* **Origin Project**: The actual source code directory. It remains 100% clean of sync-related metadata.
* **Sidecar Directory**: Must be named exactly `<origin-folder-name>-github-sync.d`.
* **Marker File**: A file named `sync` inside the sidecar. Its existence signals that the sibling folder should be synced.

---

## Configuration (`sync` file)

The `sync` file is a simple key-value Bash-compatible file. If the file is empty, the system uses smart defaults.

### Available Variables

| Variable | Default | Description |
| --- | --- | --- |
| `repo_name` | Folder Name | The name of the repository on GitHub. |
| `private` | `true` | Visibility of the GitHub repo. |
| `githubPages` | `false` | Enables GitHub Pages (Requires `private=false` on free accounts). |
| `githubPagesBranch` | `main` | The branch used for GitHub Pages hosting. |
| `githubPagesPath` | `/` | The directory within the repo for Pages (e.g., `/docs`). |
| `forcePush` | `false` | Overwrites remote history if `true`. |

### Example: High-Magic Config

To sync a public documentation site with GitHub Pages enabled:

```bash
# util/docs-site-github-sync.d/sync
repo_name="project-docs"
private=false
githubPages=true
githubPagesBranch="main"

```

---

## How to Run

### Discovery Mode

To sync everything discovered from the current directory:

```bash
github_sync_workflow2 .

```

### Dry Run

To see what would happen without actually pushing to GitHub:

```bash
github_sync_workflow2 . true

```

### Debug Mode

To trace the discovery logic and API payloads:

```bash
DEBUG=true github_sync_workflow2 .

```

---

## Technical Tally

* **Discovery Engine**: `github_sync_discover_projects2.sh` (Uses `find` and `jq`).
* **Processing Engine**: Reuses the robust `github_sync_workflow_process_projects` logic from v1.
* **Requirement**: `jq`, `curl`, and your existing `extract-git-path` tool.

