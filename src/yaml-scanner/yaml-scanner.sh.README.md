# YAML Scanner for GitHub Repository Metadata

A Bash-based tool for parsing YAML configuration files to extract GitHub repository metadata.

## Overview

The YAML scanner reads a configuration file (`.github-sync.yaml`) and extracts project information including paths and repository names. It's designed for managing multiple GitHub repositories from a single configuration file.

## Quick Start

### Prerequisites

- `yq` - YAML processor (install: `pip install yq`)
- `jq` - JSON processor (for parsing output)
- `bash` 4.0+

### Basic Usage

```bash
# Use default config file (.github-sync.yaml in current directory)
# Output to stdout
yaml_scanner

# Specify custom config file
yaml_scanner /path/to/config.yaml

# Enable debug mode
DEBUG=true yaml_scanner
```

## Parameters

### Required Environment Variables
- None for scanning (only needed for GitHub operations)

### Command Line Parameters
- `yaml_file` (optional): Path to YAML configuration file. Defaults to `.github-sync.yaml` in current directory

### YAML Configuration Fields

#### Top Level Fields
- **`github_user`** (required): Your GitHub username, defined once at the top level
- **`json_output`** (optional): Path where JSON output will be saved. If omitted, output goes to stdout

#### Project Fields
- **`path`** (required): Absolute or relative path to the local repository
- **`repo_name`** (optional): Custom repository name. If omitted, derived from the directory name
- **`private`** (optional): Whether the repository should be private. Defaults to `true`
- **`forcePush`** (optional): Whether to force push to GitHub. Defaults to `true`. When `false`, push will fail if remote has diverged
- **`githubPages`** (optional): Whether to enable GitHub Pages. Defaults to `false`
- **`githubPagesBranch`** (optional): Branch to serve Pages from. Defaults to `main`. Only used if `githubPages: true`
- **`githubPagesPath`** (optional): Path within branch to serve Pages from. Defaults to `/` (root). Common values: `/`, `/docs`. Only used if `githubPages: true`

## Usage Examples

### Basic Configuration

```yaml
github_user: your-github-username

projects:
  - path: /home/user/projects/repo1
    repo_name: custom-repo-1
  - path: /home/user/projects/repo2
```

### Advanced Configuration with GitHub Pages

```yaml
github_user: johndoe
json_output: /tmp/github-projects.json

projects:
  - path: /home/user/work/api-server
    repo_name: company-api
    private: false
    forcePush: false
  - path: /home/user/personal/blog
    githubPages: true
    githubPagesBranch: main
    githubPagesPath: /
  - path: /home/user/docs-site
    githubPages: true
    githubPagesBranch: gh-pages
    githubPagesPath: /docs
```

### Relative Paths

```yaml
github_user: testuser

projects:
  - path: ./projects/subdir1
    repo_name: relative-with-dot
  - path: projects/subdir2
    repo_name: relative-without-dot
```

## Output Formats

### Stdout Mode (Default)

When `json_output` is not specified, JSON is printed to stdout:

```bash
yaml_scanner | jq -r '.[].repo_name'
```

Output:
```json
[
  {
    "github_user": "your-username",
    "path": "/home/user/projects/repo1",
    "repo_name": "custom-repo-1",
    "private": "false",
    "forcePush": "false",
    "githubPages": "true",
    "githubPagesBranch": "main",
    "githubPagesPath": "/"
  }
]
```

### File Mode

When `json_output` is specified in YAML, output is saved to file:

```yaml
github_user: testuser
json_output: /tmp/projects.json
```

```bash
yaml_scanner
# Output: "JSON output saved to: /tmp/projects.json" (to stderr)
# File /tmp/projects.json is created with JSON content
```

## Detailed Information

### Path Resolution

The scanner handles both absolute and relative paths:

- **Absolute paths** (`/home/user/project`): Used as-is
- **Relative paths** (`./project` or `project`): Resolved relative to the YAML file's directory

### Repository Name Derivation

If `repo_name` is not provided, it's automatically derived from the last component of the path:

```yaml
projects:
  - path: /home/user/my-awesome-project  # repo_name = "my-awesome-project"
```

### Boolean Value Normalization

All boolean fields (`private`, `forcePush`, `githubPages`) are normalized to string values "true" or "false":

- Accepts: `true`, `True`, `TRUE`, `false`, `False`, `FALSE`
- Defaults: `private="true"`, `forcePush="true"`, `githubPages="false"`
- Output: Always lowercase strings "true" or "false"

### GitHub Pages Configuration

GitHub Pages settings are validated:

- `githubPagesBranch` and `githubPagesPath` are only meaningful when `githubPages="true"`
- Defaults: `githubPagesBranch="main"`, `githubPagesPath="/"`
- Non-root paths (`/docs`) will be validated during GitHub sync to ensure they exist

### Error Handling

The scanner provides clear error messages for:

- Missing YAML file
- Missing `yq` dependency
- Missing `github_user` field
- Empty projects list
- Invalid YAML syntax
- Failed file write operations
- Invalid relative paths

### Debug Mode

Enable detailed logging with `DEBUG=true`:

```bash
DEBUG=true yaml_scanner
```

Debug output includes:
- YAML file parsing details
- Path resolution steps
- Field extraction values
- JSON generation process

## Integration with GitHub Sync Workflow

This scanner is designed to work with the complete GitHub sync workflow:

```bash
# 1. Scan YAML and save to JSON
yaml_scanner

# 2. Use JSON output in workflow
github_sync_workflow
```

The JSON output format matches exactly what the `github_sync_workflow` expects for processing multiple repositories.

## Testing

Run the test suite:

```bash
./tests/yaml-scanner/test_gitHistoryTools_yamlScanner.sh
```

### Test Coverage

- **Multiple Projects**: Extraction with custom and derived repository names
- **Empty Projects**: Error handling for empty project lists
- **JSON Output**: File output functionality
- **Relative Paths**: Path resolution from YAML file location
- **Mixed Paths**: Handling both absolute and relative paths
- **Invalid Paths**: Error handling for non-existent relative paths
- **GitHub Pages**: Default and custom Pages configuration

## Design Principles

### Single User Per Config

The configuration follows the principle that **one token = one user**. The `github_user` is defined once at the top level rather than per-project, which:

- Reduces redundancy
- Simplifies maintenance
- Reflects the typical use case of managing multiple repos under a single GitHub account

### Output Flexibility

The scanner supports two output modes:

1. **Stdout mode**: JSON printed to stdout for piping to other commands
2. **File mode**: JSON saved to specified path for persistent storage

File mode automatically creates parent directories if they don't exist.

## Functions

### Public API

- **`yaml_scanner [yaml_file]`**: Main entry point for scanning YAML files

### Internal Functions

- **`yaml_scanner_parse_config`**: Validates YAML file and checks dependencies
- **`yaml_scanner_get_github_user`**: Extracts top-level GitHub username
- **`yaml_scanner_get_json_output_path`**: Extracts optional JSON output path
- **`yaml_scanner_get_project_count`**: Returns number of projects in config
- **`yaml_scanner_extract_project`**: Extracts individual project metadata

## Common Use Cases

### Batch Repository Management

```yaml
github_user: company
json_output: /home/user/.config/company-repos.json

projects:
  - path: /home/user/work/frontend
    repo_name: company-frontend
    private: false
  - path: /home/user/work/backend
    repo_name: company-backend
  - path: /home/user/work/docs
    repo_name: company-docs
    githubPages: true
```

### Personal Project Organization

```yaml
github_user: myusername

projects:
  - path: /home/user/dotfiles
  - path: /home/user/scripts
    repo_name: utility-scripts
  - path: /home/user/blog
    githubPages: true
```

## Troubleshooting

### Common Issues

1. **Missing yq**: Install with `pip install yq`
2. **Relative path errors**: Ensure paths exist relative to YAML file location
3. **JSON output directory**: Parent directories are created automatically
4. **Boolean values**: Use string "true"/"false" or let defaults apply

### Debugging Steps

```bash
# 1. Check YAML syntax
yq eval '.' .github-sync.yaml

# 2. Enable debug mode
DEBUG=true yaml_scanner

# 3. Verify individual field extraction
yq eval '.github_user' .github-sync.yaml
yq eval '.projects[0].path' .github-sync.yaml
```

## License

[Your License Here]
