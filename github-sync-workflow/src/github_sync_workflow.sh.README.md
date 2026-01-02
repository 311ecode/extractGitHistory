# GitHub Sync Workflow

Automates the process of extracting git history from multiple project paths and syncing them to GitHub repositories.

## Overview

The GitHub Sync Workflow orchestrates the complete process of:
1. **YAML Scanning** - Reading project configuration from `.github-sync.yaml`
2. **Git History Extraction** - Extracting and flattening git history for each project
3. **GitHub Repository Management** - Creating/updating repositories and pushing history

## Quick Start

### Prerequisites

- `git-filter-repo` (install: `pip install git-filter-repo`)
- `yq` (install: `pip install yq`)
- `jq`
- GitHub personal access token

### Basic Usage

```bash
# Set credentials
export GITHUB_TOKEN="your_token"
export GITHUB_USER="your_username"

# Run workflow with default config (.github-sync.yaml)
github_sync_workflow

# Dry-run mode (preview without actual changes)
github_sync_workflow .github-sync.yaml true

# Debug mode
DEBUG=true github_sync_workflow
```

## Parameters

### Required Environment Variables
- **`GITHUB_TOKEN`** or **`GITHUB_TEST_TOKEN`**: GitHub personal access token with `repo` scope
- **`GITHUB_USER`** or **`GITHUB_TEST_ORG`**: GitHub username or organization name

### Command Line Parameters
- **`yaml_file`** (optional): Path to YAML configuration file. Defaults to `.github-sync.yaml` in current directory
- **`dry_run`** (optional): Set to "true" for dry-run mode. Defaults to "false"

### Optional Environment Variables
- **`DEBUG`**: Set to "true" or "1" for detailed debug output

## YAML Configuration

Create `.github-sync.yaml` at your repository root:

```yaml
github_user: your-username
json_output: /path/to/output.json  # REQUIRED for workflow

projects:
  - path: /home/user/projects/api-server
    repo_name: company-api
    private: false
    forcePush: false
  - path: /home/user/projects/website
    repo_name: company-site
    githubPages: true
    githubPagesBranch: main
    githubPagesPath: /
  - path: /home/user/projects/docs
    repo_name: documentation
    githubPages: true
    githubPagesBranch: gh-pages
    githubPagesPath: /docs
```

### YAML Fields

#### Top Level Fields
- **`github_user`** (required): Your GitHub username/organization
- **`json_output`** (required): Path where intermediate JSON will be saved

#### Project Fields
- **`path`** (required): Absolute or relative path to the local repository
- **`repo_name`** (optional): Custom repository name. If omitted, derived from directory name
- **`private`** (optional): Repository visibility. Defaults to "true" (private)
- **`forcePush`** (optional): Whether to force push to GitHub. Defaults to "true"
- **`githubPages`** (optional): Enable GitHub Pages. Defaults to "false"
- **`githubPagesBranch`** (optional): Branch to serve Pages from. Defaults to "main"
- **`githubPagesPath`** (optional): Path within branch to serve Pages from. Defaults to "/"

## Usage Examples

### Basic Configuration

```bash
# Create config
cat > .github-sync.yaml <<'EOF'
github_user: johndoe
json_output: /tmp/projects.json

projects:
  - path: /home/john/work/api-server
    repo_name: company-api
  - path: /home/john/work/frontend
    repo_name: company-frontend
EOF

# Run workflow
github_sync_workflow
```

### Dry Run Mode

```bash
# Preview what would happen without making changes
github_sync_workflow .github-sync.yaml true
```

Output:
```
[DRY RUN] Would create repository: johndoe/company-api
[DRY RUN] Would create repository: johndoe/company-frontend
```

### Debug Mode

```bash
# See detailed processing information
DEBUG=true github_sync_workflow
```

### Relative Paths

```yaml
github_user: testuser
json_output: ./sync-output.json

projects:
  - path: ./subprojects/api
    repo_name: relative-api
  - path: subprojects/web
    repo_name: relative-web
```

## Workflow Steps

For each project in the YAML configuration:

### 1. YAML Scanning
- Parses `.github-sync.yaml` configuration
- Validates required fields and dependencies
- Generates JSON output with project metadata
- Handles relative path resolution

### 2. Git History Extraction
- Extracts git history for the specified path
- Flattens directory structure to repository root
- Preserves complete commit history
- Generates commit mappings between original and extracted hashes
- Creates `extract-git-path-meta.json` with extraction metadata

### 3. GitHub Repository Management
- Creates new repository or updates existing one
- Pushes extracted git history to GitHub
- Updates repository description from README.md
- Configures repository visibility (public/private)
- Enables GitHub Pages if requested
- Updates sync status in metadata file

## Output and Reporting

### Success Output
```
Found 2 project(s) to sync

========================================
Processing: johndoe/company-api
Path: /home/john/work/api-server
Private: false
Force Push: false
GitHub Pages: disabled
========================================
✓ Successfully synced: https://github.com/johndoe/company-api

========================================
Processing: johndoe/company-frontend
Path: /home/john/work/frontend
Private: true
Force Push: true
GitHub Pages: enabled (branch=main, path=/)
========================================
✓ Successfully synced: https://github.com/johndoe/company-frontend

========================================
Sync Complete
========================================
Success: 2
Failed:  0
```

### Error Handling
- Continues processing remaining projects if one fails
- Reports detailed error messages for failed projects
- Provides success/failure summary at the end
- Exit code 1 if any project fails, 0 if all succeed

## Advanced Features

### GitHub Pages Configuration

The workflow can automatically enable and configure GitHub Pages:

```yaml
projects:
  - path: /home/user/website
    repo_name: my-site
    githubPages: true
    githubPagesBranch: main
    githubPagesPath: /
  - path: /home/user/docs
    repo_name: documentation
    githubPages: true
    githubPagesBranch: gh-pages
    githubPagesPath: /docs
```

**Notes:**
- Non-root paths (`/docs`) are validated to ensure they exist in the repository
- If path validation fails, Pages won't be enabled but repository creation continues
- Public repositories may be required for GitHub Pages on free plans

### Force Push Control

Control whether to overwrite remote changes:

```yaml
projects:
  - path: /home/user/critical-repo
    repo_name: important-code
    forcePush: false  # Will fail if remote has diverged
  - path: /home/user/experimental
    repo_name: playground
    forcePush: true   # Will overwrite remote changes
```

### Repository Visibility

```yaml
projects:
  - path: /home/user/open-source
    repo_name: public-project
    private: false
  - path: /home/user/proprietary
    repo_name: private-code
    private: true    # Default
```

## Testing

Run the complete test suite:

```bash
./tests/github-sync-workflow/test_gitHistoryTools_githubSyncWorkflow.sh
```

### Test Coverage
- **Integration tests**: End-to-end workflow with real GitHub operations
- **Pages testing**: GitHub Pages enablement and configuration
- **Error handling**: Graceful failure and continuation
- **Path validation**: Relative and absolute path resolution

## Troubleshooting

### Common Issues

1. **Missing Dependencies**
   ```
   ERROR: git-filter-repo is not installed
   ```
   Solution: `pip install git-filter-repo`

2. **Invalid YAML**
   ```
   ERROR: Invalid YAML syntax in .github-sync.yaml
   ```
   Solution: Validate YAML with `yq eval '.' .github-sync.yaml`

3. **Missing JSON Output**
   ```
   ERROR: json_output not defined in YAML config
   ```
   Solution: Add `json_output: /path/to/output.json` to your YAML

4. **Permission Errors**
   ```
   ERROR: Your GitHub token does not have admin permissions
   ```
   Solution: Ensure token has `repo` scope and admin access to repositories

### Debug Mode

Enable detailed logging to diagnose issues:

```bash
DEBUG=true github_sync_workflow
```

Debug output includes:
- YAML parsing details
- Git extraction progress
- GitHub API requests and responses
- Error stack traces

## Design Principles

### Batch Processing
- Processes multiple projects in a single run
- Continues on individual project failures
- Provides comprehensive summary report

### Data Preservation
- Maintains complete git history and commit metadata
- Tracks sync status for auditability
- Preserves commit hash mappings

### Safety Features
- Dry-run mode for previewing changes
- Force push control to prevent data loss
- Path validation for GitHub Pages
- Clear error messages and status reporting

## Integration with Other Tools

This workflow is part of the larger Git History Tools ecosystem:

- **`gitHistoryTools_extractGitPath`**: Core extraction functionality
- **`github_pusher`**: GitHub repository management
- **`yaml_scanner`**: Configuration parsing

See the main README.md for complete documentation of all components.

## Security Notes

- GitHub tokens are used for API authentication
- Temporary directories contain extracted git history
- No sensitive data is logged in normal operation
- Use test credentials (`GITHUB_TEST_TOKEN`, `GITHUB_TEST_ORG`) for development

## License

[Your License Here]
