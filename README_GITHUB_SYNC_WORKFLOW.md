# GitHub Sync Workflow

Orchestrates the complete workflow: YAML scanning → Git history extraction → GitHub repository creation.

## Overview

The GitHub Sync Workflow ties together three tools:
1. **YAML Scanner** - Reads project configuration
2. **Extract Git Path** - Extracts git history for each project
3. **GitHub Pusher** - Creates GitHub repositories

## Usage

```bash
# Run workflow (requires json_output in YAML config)
github_sync_workflow

# Specify custom YAML file
github_sync_workflow /path/to/config.yaml

# Dry-run mode (doesn't create repos)
github_sync_workflow .github-sync.yaml true

# Debug mode
DEBUG=true github_sync_workflow
```

## YAML Configuration

The workflow requires `json_output` to be defined in your YAML config:

```yaml
github_user: your-username
json_output: /tmp/github-sync-output.json  # REQUIRED for workflow

projects:
  - path: /home/user/bash.sh/vcs/git/git/history/extractGitHistory2
    repo_name: extractGitHistory
```

## Environment Variables

Required for actual GitHub operations (not needed for dry-run):

- `GITHUB_TOKEN` or `GITHUB_TEST_TOKEN` - GitHub personal access token
- `GITHUB_USER` or `GITHUB_TEST_ORG` - GitHub username/organization

## Workflow Steps

For each project in the YAML config:

1. **Scan** - Parse YAML and generate projects JSON
2. **Extract** - Extract git history for project path
   - Creates temporary repo with flattened history
   - Generates `extract-git-path-meta.json` with commit mappings
3. **Push** - Create GitHub repository
   - Creates repo via GitHub API
   - Updates meta.json with sync status

## Example

```bash
# Create config at bash.sh root
cat > /home/imre/bash.sh/.github-sync.yaml <<'EOF'
github_user: imre
json_output: /home/imre/bash.sh/.github-sync-output.json

projects:
  - path: /home/imre/bash.sh/vcs/git/git/history/extractGitHistory2
    repo_name: extractGitHistory
EOF

# Set credentials
export GITHUB_TOKEN="your_token_here"
export GITHUB_USER="imre"

# Run workflow
cd /home/imre/bash.sh
github_sync_workflow
```

Output:
```
Found 1 project(s) to sync

========================================
Processing: imre/extractGitHistory
Path: /home/imre/bash.sh/vcs/git/git/history/extractGitHistory2
========================================
✓ Successfully synced: https://github.com/imre/extractGitHistory

========================================
Sync Complete
========================================
Success: 1
Failed:  0
```

## Testing

```bash
./tests/github-sync-workflow/test_gitHistoryTools_githubSyncWorkflow.sh
```

## Error Handling

The workflow will:
- Continue processing remaining projects if one fails
- Report success/failure counts at the end
- Exit with code 1 if any project fails
- Exit with code 0 if all projects succeed