# GitHub Pusher

A Bash utility for automating GitHub repository creation and management from extracted code repositories.

## Parameters

### Required Parameters

1. **Meta File** (`$1`)
   - **Type**: File path (string)
   - **Description**: Path to the `meta.json` file containing repository metadata
   - **Required**: Yes
   - **Example**: `./extracted/meta.json`

### Optional Parameters

2. **Dry Run Mode** (`$2`)
   - **Type**: Boolean string
   - **Description**: When set to `"true"`, performs all operations except actual GitHub API calls
   - **Default**: `"false"`
   - **Required**: No
   - **Example**: `"true"` or `"false"`

### Environment Variables

- **`GITHUB_TOKEN`** or **`GITHUB_TEST_TOKEN`**
  - **Type**: String
  - **Description**: GitHub personal access token with appropriate permissions
  - **Required**: Yes
  - **Permissions**: `repo` (full control of private repositories) for private repos, `public_repo` for public repos

- **`GITHUB_USER`** or **`GITHUB_TEST_ORG`**
  - **Type**: String
  - **Description**: GitHub username or organization name
  - **Required**: Yes

- **`DEBUG`**
  - **Type**: Boolean string or `1`
  - **Description**: Enable debug output
  - **Default**: `"false"`
  - **Values**: `"true"`, `"false"`, or `1` (treated as `"true"`)

## Usage Examples

### Basic Usage

```bash
# Set required environment variables
export GITHUB_TOKEN="your_personal_access_token"
export GITHUB_USER="your_username"

# Run the pusher
github_pusher "./extracted/meta.json"
```

### Dry Run Mode

```bash
# Preview what would happen without making changes
github_pusher "./extracted/meta.json" "true"
```

### Debug Mode

```bash
# Enable debug output
export DEBUG="true"
github_pusher "./extracted/meta.json"
```

### Using Test Credentials

```bash
# Use test credentials instead of production
export GITHUB_TEST_TOKEN="test_token"
export GITHUB_TEST_ORG="test_org"
github_pusher "./extracted/meta.json"
```

## Meta.json Configuration

The `meta.json` file can contain the following custom fields:

### Repository Configuration

- **`custom_repo_name`** (string, optional)
  - Override the automatically generated repository name
  - If not provided, derived from the relative path

- **`custom_private`** (boolean string, optional)
  - Control repository visibility
  - **Default**: `"true"` (private repository)
  - **Values**: `"true"` or `"false"`

- **`custom_forcePush`** (boolean string, optional)
  - Control whether to force push when remote has diverged
  - **Default**: `"true"` (force push enabled)
  - **Values**: `"true"` or `"false"`

### GitHub Pages Configuration

- **`custom_githubPages`** (boolean string, optional)
  - Enable GitHub Pages for the repository
  - **Default**: `"false"` (disabled)
  - **Values**: `"true"` or `"false"`

- **`custom_githubPagesBranch`** (string, optional)
  - Branch to use for GitHub Pages
  - **Default**: `"main"`

- **`custom_githubPagesPath`** (string, optional)
  - Path within the repository to serve as Pages root
  - **Default**: `"/"` (repository root)
  - **Example**: `"/docs"` for a docs folder

### Example meta.json

```json
{
  "original_path": "/path/to/source",
  "relative_path": "my-project",
  "extracted_repo_path": "./extracted/my-project",
  "custom_repo_name": "my-awesome-project",
  "custom_private": "false",
  "custom_forcePush": "true",
  "custom_githubPages": "true",
  "custom_githubPagesBranch": "gh-pages",
  "custom_githubPagesPath": "/docs"
}
```

## Detailed Information

### Repository Creation Flow

1. **Parse Metadata**: Validates and extracts information from `meta.json`
2. **Generate Repository Name**: Uses `custom_repo_name` or derives from path
3. **Check Existence**: Verifies if repository already exists on GitHub
4. **Create/Update Repository**:
   - New repository: Creates with specified visibility and description
   - Existing repository: Updates description and visibility
5. **Push Git History**: Pushes the extracted repository's git history
6. **Enable GitHub Pages**: If configured, sets up GitHub Pages
7. **Update Metadata**: Updates `meta.json` with sync status

### Description Generation

The repository description is automatically generated:
1. **Primary**: First non-empty line from `README.md` (stripping leading `#` and whitespace)
2. **Fallback**: "Extracted from [original_path]"

### Error Handling

- **Missing Credentials**: Fails immediately with clear error messages
- **API Failures**: Provides detailed error messages from GitHub API
- **Cleanup**: If repository creation succeeds but push fails, automatically deletes the repository
- **Visibility Mismatch**: Warns when requested visibility doesn't match actual (often due to organization policies)

### Token Permissions

Required GitHub token scopes:
- **For private repositories**: `repo` (full control)
- **For public repositories**: `public_repo`
- **For organization repositories**: Additional admin permissions may be required for visibility changes

### Force Push Behavior

- **Enabled (`forcePush: true`)**: Overwrites remote changes if they exist
- **Disabled (`forcePush: false`)**: Fails if remote has diverged
- **Use case**: Enable force push when you want to ensure your local history becomes the source of truth

### GitHub Pages Integration

- **Path Validation**: Verifies the Pages path exists in the repository
- **API Compatibility**: Uses both POST (create) and PUT (update) APIs
- **Error Tolerance**: Pages failure doesn't fail the entire operation

## Output

### Success Output

```
✓ Created repository: https://github.com/username/repo-name
✓ Git history pushed successfully
✓ GitHub Pages enabled successfully
https://github.com/username/repo-name
```

### Dry Run Output

```
[DRY RUN] Would create repository: username/repo-name
[DRY RUN] Description: My Project Description
[DRY RUN] Private: true
https://github.com/username/repo-name

[DRY RUN] Proposed sync_status update:
{
  "sync_status": {
    "synced": true,
    "github_url": "https://github.com/username/repo-name",
    "github_owner": "username",
    "github_repo": "repo-name",
    "synced_at": "[DRY-RUN: would be populated with current timestamp]",
    "synced_by": "username"
  }
}
```

## Troubleshooting

### Common Issues

1. **Permission Denied for Visibility Change**
   - **Cause**: Organization policies or insufficient token permissions
   - **Solution**: Ensure token has admin access or check organization settings

2. **Push Fails with Non-Fast-Forward Error**
   - **Cause**: Remote has different history and `forcePush` is disabled
   - **Solution**: Set `custom_forcePush: "true"` in `meta.json`

3. **GitHub Pages Path Not Found**
   - **Cause**: Specified path doesn't exist in the repository
   - **Solution**: Verify the path exists or use `"/"` for repository root

4. **Repository Already Exists**
   - **Behavior**: Updates description and visibility instead of creating new

### Debug Information

Enable debug mode to see:
- API requests and responses
- JSON payloads being sent
- Step-by-step execution details
- Normalized configuration values

## Related Files

The GitHub Pusher consists of several modular functions:

- `github_pusher.sh` - Main orchestration function
- `github_pusher_check_repo_exists.sh` - Repository existence check
- `github_pusher_create_repo.sh` - Repository creation
- `github_pusher_delete_repo.sh` - Repository cleanup
- `github_pusher_enable_pages.sh` - GitHub Pages setup
- `github_pusher_generate_repo_name.sh` - Name generation
- `github_pusher_get_description.sh` - Description extraction
- `github_pusher_parse_meta_json.sh` - Metadata parsing
- `github_pusher_push_git_history.sh` - Git operations
- `github_pusher_update_meta_json.sh` - Metadata updates
- `github_pusher_update_repo_description.sh` - Description updates
- `github_pusher_update_repo_visibility.sh` - Visibility updates

## Notes

- All boolean values in `meta.json` should be lowercase strings: `"true"` or `"false"`
- The utility handles string normalization for case variations (`True`, `TRUE`, etc.)
- Organization repositories may have visibility restrictions that override your settings
- Dry run mode is useful for validating configuration before making actual changes
- The sync status in `meta.json` is updated upon successful completion
