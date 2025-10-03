# YAML Scanner for GitHub Repository Metadata

A Bash-based tool for parsing YAML configuration files to extract GitHub repository metadata.

## Overview

The YAML scanner reads a configuration file (`.github-sync.yaml`) and extracts project information including paths and repository names. It's designed for managing multiple GitHub repositories from a single configuration file.

## YAML Configuration Format

```yaml
github_user: your-github-username

projects:
  - path: /home/user/projects/repo1
    repo_name: custom-repo-1
  - path: /home/user/projects/repo2
  - path: /path/to/another-project
    repo_name: special-name
```

### Configuration Fields

- **`github_user`** (required): Your GitHub username, defined once at the top level
- **`projects`** (required): Array of project configurations
  - **`path`** (required): Absolute path to the local repository
  - **`repo_name`** (optional): Custom repository name. If omitted, derived from the directory name

## Dependencies

- `yq` - YAML processor (install: `pip install yq`)
- `jq` - JSON processor (for parsing output)
- `bash` 4.0+

## Usage

### Basic Usage

```bash
# Use default config file (.github-sync.yaml in current directory)
yaml_scanner

# Specify custom config file
yaml_scanner /path/to/config.yaml
```

### Enable Debug Mode

```bash
DEBUG=true yaml_scanner
```

### Output Format

The scanner outputs JSON:

```json
[
  {
    "github_user": "your-username",
    "path": "/home/user/projects/repo1",
    "repo_name": "custom-repo-1"
  },
  {
    "github_user": "your-username",
    "path": "/home/user/projects/repo2",
    "repo_name": "repo2"
  }
]
```

### Parsing Output

```bash
# Get all repository names
yaml_scanner | jq -r '.[].repo_name'

# Get all paths
yaml_scanner | jq -r '.[].path'

# Get specific project
yaml_scanner | jq -r '.[0]'
```

## Testing

Run the test suite:

```bash
./tests/yaml-scanner/test_gitHistoryTools_yamlScanner.sh
```

### Test Coverage

- **`test_yamlScanner_multipleProjects`**: Verifies extraction of multiple projects with custom and derived repository names
- **`test_yamlScanner_emptyProjects`**: Validates error handling for empty project lists

## Error Handling

The scanner handles various error conditions:

- Missing YAML file
- Missing `yq` dependency
- Missing `github_user` field
- Empty projects list
- Invalid YAML syntax

Error messages are written to stderr with appropriate exit codes.

## Design Principles

### Single User Per Config

The configuration follows the principle that **one token = one user**. The `github_user` is defined once at the top level rather than per-project, which:

- Reduces redundancy
- Simplifies maintenance
- Reflects the typical use case of managing multiple repos under a single GitHub account

### Repository Name Derivation

If `repo_name` is not explicitly provided, it's automatically derived from the last component of the `path`:

```yaml
projects:
  - path: /home/user/my-awesome-project  # repo_name = "my-awesome-project"
```

## Functions

### Public API

- **`yaml_scanner [yaml_file]`**: Main entry point for scanning YAML files

### Internal Functions

- **`yaml_scanner_parse_config`**: Validates YAML file and checks dependencies
- **`yaml_scanner_get_github_user`**: Extracts top-level GitHub username
- **`yaml_scanner_get_project_count`**: Returns number of projects in config
- **`yaml_scanner_extract_project`**: Extracts individual project metadata

## Example Workflow

```bash
# Create config file
cat > .github-sync.yaml <<EOF
github_user: johndoe

projects:
  - path: /home/johndoe/work/api-server
    repo_name: company-api
  - path: /home/johndoe/work/frontend
  - path: /home/johndoe/personal/dotfiles
EOF

# Scan and process
yaml_scanner | jq -r '.[] | "\(.github_user)/\(.repo_name) -> \(.path)"'
```

Output:
```
johndoe/company-api -> /home/johndoe/work/api-server
johndoe/frontend -> /home/johndoe/work/frontend
johndoe/dotfiles -> /home/johndoe/personal/dotfiles
```

## License

[Your License Here]