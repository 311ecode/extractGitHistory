# Git History Tools - Extract and Sync Repository Subdirectories

A comprehensive toolkit for extracting git history from subdirectories and syncing them to individual GitHub repositories. This project enables you to split a monorepo into multiple independent repositories while preserving full commit history.

**Note:** This repository was itself extracted from a larger monorepo using these very tools.

## Core Components

### 1. Extract Git Path
Extracts git history for a specific path, with the path flattened to the root of a new repository.

**Features:**
- Fast extraction using `git-filter-repo`
- Preserves complete commit history
- Flattens directory structure to repository root
- Generates commit mappings between original and extracted hashes
- Creates metadata file for tracking

See [README_EXTRACT_GIT_PATH.md](README_EXTRACT_GIT_PATH.md) for detailed documentation.

### 2. GitHub Pusher
Creates GitHub repositories and pushes extracted git history.

**Features:**
- Automatic repository creation via GitHub API
- Pushes git history to GitHub
- Uses README.md first line as repository description
- Updates existing repositories
- Tracks sync status in metadata

### 3. GitHub Sync Workflow
Orchestrates the complete workflow from YAML configuration to GitHub.

**Features:**
- YAML-based configuration for multiple projects
- Processes multiple repositories in batch
- Handles errors gracefully with per-project reporting
- Supports dry-run mode

See [README_GITHUB_SYNC_WORKFLOW.md](README_GITHUB_SYNC_WORKFLOW.md) for workflow documentation.

## Quick Start

### Prerequisites

- `git-filter-repo` (install: `pip install git-filter-repo`)
- `yq` (install: `pip install yq`)
- `jq`
- GitHub personal access token

### Configuration

Create `.github-sync.yaml` at your repository root:

```yaml
github_user: your-username
json_output: /path/to/output.json

projects:
  - path: /home/user/monorepo/subdirectory1
    repo_name: extracted-repo-1
  - path: /home/user/monorepo/subdirectory2
    repo_name: extracted-repo-2
```

### Usage

```bash
# Set credentials
export GITHUB_TOKEN="your_token"
export GITHUB_USER="your_username"

# Run workflow
github_sync_workflow

# Or with debug output
DEBUG=1 github_sync_workflow
```

## Use Case: From Monorepo to Multiple Repos

This toolkit solves the common problem of splitting a monorepo:

1. **You have:** A large monorepo with multiple independent projects
2. **You want:** Each project in its own repository with full git history
3. **Challenge:** Standard git operations lose history or are extremely slow
4. **Solution:** These tools extract, preserve history, and automate GitHub sync

## Architecture

```
YAML Config → YAML Scanner → JSON Metadata
                                    ↓
                            Extract Git Path → Temporary Repo + Metadata
                                                        ↓
                                                GitHub Pusher → GitHub Repository
```

## Testing

```bash
# Run all tests
./tests/test_extractGitHistory2_unified.sh

# Run specific component tests
./tests/extract-git-path/test_gitHistoryTools_extractGitPath.sh
./tests/github-pusher/test_gitHistoryTools_githubPusher.sh
./tests/github-sync-workflow/test_gitHistoryTools_githubSyncWorkflow.sh
```

## Documentation

- [Extract Git Path](README_EXTRACT_GIT_PATH.md) - Detailed extraction documentation
- [GitHub Sync Workflow](README_GITHUB_SYNC_WORKFLOW.md) - Workflow orchestration guide

## Design Principles

- **Performance First:** Uses `git-filter-repo` for 10-100x faster operations
- **Data Preservation:** Maintains complete commit history and metadata
- **Automation:** Batch processing with error handling
- **Flexibility:** Works with any subdirectory structure
- **Traceability:** Tracks all operations in metadata files

## License

[Your License Here]