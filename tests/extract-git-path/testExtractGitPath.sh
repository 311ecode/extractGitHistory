#!/usr/bin/env bash
# Test suite for extract-git-path.sh



# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_gitHistoryTools_extractGitPath
fi