# yaml-scanner

Extract GitHub repository metadata from YAML configuration files containing multiple projects.

## Usage

```bash
yaml_scanner [yaml_file]
```

**Arguments:**
- `[yaml_file]`: Path to YAML config file (default: `.github-sync.yaml` in current directory)

**Output:**
- Stdout: JSON array of projects with `github_user`, `path`, and `repo_name`
- Stderr: Error messages if any
- Exit code: 0 on success, 1 on error

## Requirements

### Required Dependencies

- **Bash 4+**: Standard shell
- **yq** (Python version): YAML processor wrapper for jq
- **jq**: JSON processor (for parsing output)

### Installing dependencies

```bash
# Using pip
pip install yq

# Using pipx (recommended)
pipx install yq
```

## YAML File Format

The YAML file must contain a `projects` list with each entry having:

```yaml
projects:
  - github_user: username1
    path: /path/to/repo1
    repo_name: custom-name  # optional - overrides name derived from path
    
  - github_user: username2
    path: /path/to/repo2
    # repo_name derived from path: "repo2"
    
  - github_user: username3
    path: /home/projects/another
    repo_name: special-repo-name
```

**Fields:**
- `github_user` (required): GitHub username or organization
- `path` (required): Local filesystem path to repository
- `repo_name` (optional): Explicit repository name; if omitted, derived from last directory of `path`

## Examples

```bash
# Scan default file
yaml_scanner

# Scan specific file
yaml_scanner config/projects.yaml

# Process each project
yaml_scanner | jq -c '.[]' | while read -r project; do
    user=$(echo "$project" | jq -r '.github_user')
    repo=$(echo "$project" | jq -r '.repo_name')
    path=$(echo "$project" | jq -r '.path')
    echo "Processing: $user/$repo from $path"
done
```

## Error Handling

The script will exit with error code 1 and print to stderr if:

- YAML file not found
- `yq` is not installed
- No `projects` array found
- Empty `projects` array
- Missing required fields (`github_user` or `path`)

## Testing

Run the test suite:

```bash
./test_gitHistoryTools_yamlScanner.sh
```