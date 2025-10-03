# yaml-scanner

Extract GitHub repository metadata from YAML configuration files.

## Usage

```bash
yaml_scanner [yaml_file]
```

**Arguments:**
- `[yaml_file]`: Path to YAML config file (default: `.github-sync.yaml` in current directory)

**Output:**
- Stdout: JSON object with `github_user` and `repo_name`
- Stderr: Error messages if any
- Exit code: 0 on success, 1 on error

## Requirements

### Required Dependencies

- **Bash 4+**: Standard shell
- **yq** (Python version): YAML processor wrapper for jq

### Installing yq

```bash
# Using pip
pip install yq

# Using pipx (recommended)
pipx install yq
```

**Note:** This requires the Python-based `yq` (wrapper around `jq`), which uses jq syntax: `yq -r '.key' file.yaml`

## YAML File Format

The scanner looks for GitHub metadata in the following formats:

### Option 1: Direct repo_name

```yaml
github_user: myusername
repo_name: my-repository
```

### Option 2: Path-based (repo name derived from last directory)

```yaml
github_user: myusername
path: /path/to/repo
# repo_name will be: "repo"
```

### Alternative Key Names

The scanner also supports these alternative key names:

```yaml
github:
  user: myusername
  repo: my-repository
```

## Examples

```bash
# Scan default file (.github-sync.yaml in current directory)
yaml_scanner

# Scan specific file
yaml_scanner config/github.yaml

# Parse output with jq
github_user=$(yaml_scanner | jq -r '.github_user')
repo_name=$(yaml_scanner | jq -r '.repo_name')
```

## Error Handling

The script will exit with error code 1 and print to stderr if:

- YAML file not found
- `yq` is not installed
- No `github_user` found in YAML
- No `repo_name` or `path` found in YAML
- YAML file is malformed

## Testing

Run the test suite:

```bash
./testYamlScanner.sh
```

Tests validate:
- Direct repo_name extraction
- Path-based repo_name derivation
- Alternative key name support
- Error handling for missing fields