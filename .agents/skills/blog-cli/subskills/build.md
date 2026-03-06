# `inkwell build`

Builds static output into `docs/`.

## Usage
```bash
inkwell build
inkwell build --json
```

## Build Output
- `docs/index.html`
- `docs/posts/<slug>/index.html`
- `docs/assets/css/prism.css`
- `docs/assets/js/prism.js`

## Common Failure Causes
- Invalid front matter (`title`, `date`, `slug` required)
- Malformed markdown fences

Fix content and rerun.
