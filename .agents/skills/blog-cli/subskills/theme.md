# `inkwell theme`

Manage available themes and active theme selection.

## Usage
```bash
inkwell theme list
inkwell theme use default
```

## Behavior
- `list` prints theme directories from `themes/`.
- `use` updates `blog.config.json` `theme` value.

## Failure Mode
`theme use` fails if target theme directory does not exist.
