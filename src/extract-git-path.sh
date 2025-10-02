#!/usr/bin/env bash
# Extract git history for a specific path, flattened to repo root

# Extract git history for a path and output temp directory path
# Usage: extract_git_path <path>
# Returns: 0 on success, 1 on error
# Stdout: Path to meta.json file
# Stderr: Path to extracted repo (for development convenience)


# Helper function that performs the actual git extraction and metadata generation
# Usage: extract_git_path_helper <abs_path> <repo_root> <rel_path>
# Returns: 0 on success, 1 on error
# Stdout: Path to meta.json file
# Stderr: Path to extracted repo (for development convenience)
