# Git Path Extractor

Extracts a specific file or directory from a Git repository while preserving its complete commit history, creating a new standalone repository with the extracted content.

## Parameters

### Required Parameters
- `<path>` - The path to extract from the Git repository. Can be absolute or relative.
  - **Type**: String
  - **Example**: `/home/user/project/src/utils` or `./src/utils`

### Optional Environment Variables
- `DEBUG` - Enable debug output for troubleshooting
  - **Type**: Boolean (any non-empty value enables)
  - **Default**: Not set
  - **Example**: `DEBUG=1 extract_git_path ./src/utils`

## Usage Examples

### Basic Usage
```bash
# Extract a directory from current location
extract_git_path ./src/utils

# Extract using absolute path
extract_git_path /home/user/projects/myapp/src/components
```

### With Debug Output
```bash
# Enable debug mode to see detailed processing information
DEBUG=1 extract_git_path ./docs/api
```

### Typical Workflow
```bash
# 1. Navigate to your project
cd /path/to/your/project

# 2. Extract a specific directory
extract_git_path ./src/modules/auth

# 3. The script outputs two paths:
#    - To stderr: Path to the extracted repository
#    - To stdout: Path to the metadata JSON file
```

## Output

The script produces two outputs:

1. **To stderr**: Path to the extracted Git repository
   ```
   /tmp/extract-git-path/extract_1704067200_12345/repo
   ```

2. **To stdout**: Path to the metadata JSON file (`extract-git-path-meta.json`)
   ```
   /tmp/extract-git-path/extract_1704067200_12345/extract-git-path-meta.json
   ```

### Metadata File Structure
The generated `extract-git-path-meta.json` contains:
```json
{
  "original_path": "/absolute/path/to/extracted/item",
  "original_repo_root": "/path/to/original/repository",
  "relative_path": "path/within/repo",
  "extracted_repo_path": "/tmp/path/to/extracted/repo",
  "extraction_timestamp": "2024-01-01T12:00:00Z",
  "commit_mappings": {
    "old_commit_hash1": "new_commit_hash1",
    "old_commit_hash2": "new_commit_hash2"
  },
  "sync_status": {
    "synced": false,
    "github_url": null,
    "github_owner": null,
    "github_repo": null,
    "synced_at": null,
    "synced_by": null
  }
}
```

## Dependencies

The script requires the following tools to be installed:

1. **Git** - Version control system
   - Usually pre-installed on most systems
   - Verify with: `git --version`

2. **git-filter-repo** - Advanced Git history filtering tool
   - Install via pip: `pip install git-filter-repo`
   - Verify with: `git-filter-repo --version`

## Error Handling

The script will exit with an error and appropriate message if:

1. **Incorrect number of arguments**: `ERROR: Usage: extract_git_path <path>`
2. **Missing dependencies**: `ERROR: git is not installed` or `ERROR: git-filter-repo is not installed`
3. **Invalid path**: `ERROR: Cannot resolve path: <path>`
4. **Not in Git repository**: `ERROR: Path is not inside a git repository: <path>`
5. **No Git history**: `ERROR: Path has no git history (never tracked): <path>`
6. **Extraction failure**: `ERROR: Failed to extract history for path: <path>`

## Technical Details

### Process Flow
1. **Path Resolution**: Converts relative paths to absolute paths
2. **Repository Detection**: Traverses up the directory tree to find the Git repository root
3. **History Verification**: Checks that the path has Git history
4. **Temporary Workspace**: Creates a temporary directory for extraction
5. **Repository Clone**: Clones the original repository to a temporary location
6. **Path Extraction**: Uses `git-filter-repo` to extract only the specified path and flatten it to the repository root
7. **Commit Mapping**: Creates a mapping between original and new commit hashes
8. **Metadata Generation**: Produces a JSON file with extraction details and commit mappings

### Temporary Files
- Created in: `${TMPDIR:-/tmp}/extract-git-path/`
- Pattern: `extract_<timestamp>_<PID>/`
- Contains:
  - `repo/` - The extracted Git repository
  - `extract-git-path-meta.json` - Metadata file

### Commit Mapping Logic
The script matches commits between original and extracted repositories using:
- Commit date (`%aI` - strict ISO 8601 format)
- Author email (`%ae`)
- Commit message (`%s`)

This ensures accurate mapping even when commit hashes change due to the filtering process.

## Notes

- The extracted repository will contain only the specified path's content, with all other files removed
- Commit history is preserved but may have different commit hashes due to the filtering process
- The original repository is not modified
- Temporary files are not automatically cleaned up (manual cleanup may be required)
- For large repositories, the extraction process may take several minutes

## Troubleshooting

### Common Issues

1. **"git-filter-repo is not installed"**
   ```bash
   # Install using pip
   pip install git-filter-repo
   
   # Or using package manager (Ubuntu/Debian)
   sudo apt-get install git-filter-repo
   ```

2. **"Path has no git history"**
   - Ensure the file/directory has been committed at least once
   - Check with: `git log --oneline -- <path>`

3. **Permission errors**
   - Ensure you have read access to the original repository
   - Ensure you have write access to the temporary directory

### Debug Mode
Enable debug output to see detailed processing information:
```bash
DEBUG=1 extract_git_path ./path/to/extract
```

This will show:
- Path resolution steps
- Repository detection process
- Commit mapping details
- Temporary directory locations
