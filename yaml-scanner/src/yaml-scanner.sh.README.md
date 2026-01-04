# YAML Scanner for GitHub Repository Metadata

A Bash-based tool for parsing YAML configuration files to extract GitHub repository metadata.

## Boolean Value Normalization

The scanner implements strict boolean normalization to ensure compatibility between YAML inputs and JSON outputs. 

### Supported Values
The following values are normalized to lowercase strings `"true"` or `"false"`:
- **True**: `true`, `True`, `TRUE`
- **False**: `false`, `False`, `FALSE`

### Default Behaviors
- **`private`**: Defaults to `"true"` if omitted.
- **`forcePush`**: Defaults to `"true"` if omitted.
- **`githubPages`**: Defaults to `"false"` if omitted.

## Path Resolution

- **Absolute paths**: Used as-is.
- **Relative paths**: Resolved relative to the directory containing the `.github-sync.yaml` file.

## Debugging

If you suspect configuration is being parsed incorrectly, run with `DEBUG=true` to see the `[EXTRACTOR]` trace:
```bash
DEBUG=true yaml_scanner

```

This will dump the raw values being passed from the YAML to the intermediate JSON file.
