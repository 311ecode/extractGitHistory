# GitHub Sync Workflow

Automates the process of extracting git history from multiple project paths and syncing them to GitHub repositories.

## Overview

The GitHub Sync Workflow orchestrates the complete process of:
1. **YAML Scanning** - Reading project configuration from `.github-sync.yaml`
2. **Git History Extraction** - Extracting and flattening git history for each project
3. **GitHub Repository Management** - Creating/updating repositories and pushing history

## Parameters

### Required Environment Variables
- **`GITHUB_TOKEN`** or **`GITHUB_TEST_TOKEN`**: GitHub personal access token with `repo` scope
- **`GITHUB_USER`** or **`GITHUB_TEST_ORG`**: GitHub username or organization name

## YAML Configuration

### Project Fields
- **`path`** (required): Absolute or relative path to the local repository
- **`repo_name`** (optional): Custom repository name.
- **`private`** (optional): Repository visibility. Defaults to `"true"`.
- **`githubPages`** (optional): Enable GitHub Pages. Defaults to `"false"`.

> [!IMPORTANT]
> **GitHub Pages & Visibility**: On standard (free) GitHub accounts, GitHub Pages can only be enabled for **Public** repositories. If you set `githubPages: true`, you must also set `private: false`.

## Troubleshooting

### HTTP 422: Plan Does Not Support GitHub Pages
This error occurs if you attempt to enable Pages on a **Private** repository while using a GitHub Free plan. 
**Solution**: Set `private: false` in your `.github-sync.yaml`.

### Debug Mode
Enable detailed logging to trace data transformations and API payloads:
```bash
DEBUG=true github_sync_workflow

```

