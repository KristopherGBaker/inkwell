# `blog init`

Initialize a new blog project in the current directory.

## What It Creates
- `blog.config.json`
- `content/posts/`
- `themes/default/theme.json`
- `themes/default/templates/layout.html`
- `themes/default/assets/css/prism.css`
- `themes/default/assets/js/prism.js`
- `public/`

## Usage
```bash
blog init
```

## Verify
```bash
test -f blog.config.json
test -d content/posts
test -f themes/default/assets/css/prism.css
```
