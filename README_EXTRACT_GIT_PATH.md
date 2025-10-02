# extract-git-path.sh

Extract git history for a specific path, with the path flattened to the root of a new repository.

## Usage

```bash
./extract-git-path.sh <path>
```

**Arguments:**
- `<path>`: Path to extract (absolute or relative)

**Output:**
- Stdout: Absolute path to temporary directory containing extracted git repository
- Stderr: Error messages if any
- Exit code: 0 on success, 1 on error

## Requirements

### Required Dependencies

- **Bash 4+**: Standard shell
- **git**: Version control system
- **git-filter-repo**: Fast git history rewriting tool

### Installing git-filter-repo

```bash
pip install git-filter-repo
```

Or see [official installation instructions](https://github.com/newren/git-filter-repo/blob/main/INSTALL.md).

## Performance Note

This tool uses `git-filter-repo` exclusively for performance. The older `git filter-branch` method is **not** supported as a fallback because:

- `git filter-branch` is 10-100x slower
- `git-filter-repo` is the recommended modern approach
- Installation is simple via pip

If `git-filter-repo` is not available, the script will exit with an error.

## How It Works

1. Resolves input path to absolute path
2. Finds git repository root by walking up directory tree
3. Calculates relative path from repository root
4. Verifies path has git history (has commits)
5. Clones repository to temporary directory
6. Uses `git-filter-repo` to extract path and flatten to root
7. Outputs temporary directory path

## Temporary Directory Management

- Base directory: `$TMPDIR/extract-git-path/` (or `/tmp/extract-git-path/`)
- Each extraction creates: `extract_TIMESTAMP_PID/`
- **No automatic cleanup**: Caller is responsible for removing temporary directories

## Examples

```bash
# Extract a subdirectory
extracted=$(./extract-git-path.sh /path/to/repo/src/subproject)
echo "Extracted to: $extracted"

# Use relative path
cd /path/to/repo
extracted=$(./extract-git-path.sh src/subproject)

# Extract entire repository
extracted=$(./extract-git-path.sh /path/to/repo)

# Cleanup when done
rm -rf "$extracted"
```

## Error Handling

The script will exit with error code 1 and print to stderr if:

- No path argument provided
- Path cannot be resolved
- Path is not inside a git repository
- Path has no git history (never tracked)
- `git-filter-repo` is not installed
- Clone or extraction fails

## Testing

Run the test suite:

```bash
./testExtractGitPath.sh
```

Tests use the bashTestRunner framework and validate:
- Absolute and relative path handling
- Error conditions (non-repo, untracked paths)
- History preservation across multiple commits
- Path flattening to repository root
- Entire repository extraction