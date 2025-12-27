# Git Path Transplanter 🩺

Replays isolated directory history back into a monorepo at a new destination path while preserving original metadata.

## Overview
This tool is the second half of the monorepo movement workflow. It takes the output from `extract_git_path` and grafts it onto the current `HEAD`.

## Usage
```bash
git_path_transplant ./metadata.json packages/new-feature-location

```

## Features

* **Metadata Preservation**: Maintains original Author and Committer timestamps.
* **Path Re-prefixing**: Automatically moves files from the extracted "root" into the specified sub-directory.
* **Safety**: Performs work on a temporary branch to prevent history loss.

```
