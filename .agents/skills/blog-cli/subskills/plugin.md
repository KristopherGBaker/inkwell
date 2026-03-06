# `inkwell plugin`

Manage plugin state in v1 local-only mode.

## Usage
```bash
inkwell plugin list
inkwell plugin enable my-plugin
inkwell plugin disable my-plugin
```

## Notes
- v1 behavior is lightweight command signaling.
- `list` currently reports local-only model.
- `enable/disable` currently acknowledge action textually.
