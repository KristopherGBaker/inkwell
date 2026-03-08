# Swift Blog

Static personal blog generator written in Swift.

## Features
- Markdown posts with front matter
- GFM rendering (tables, task lists, strikethrough, fenced code)
- Build-time syntax highlighting with Shiki
- CLI workflow: `init`, `post new`, `post list`, `build`, `serve`, `check`

## Install with Mint
```bash
brew install mint
mint install KristopherGBaker/inkwell
```

Run `inkwell` from anywhere after installation:

```bash
inkwell init
inkwell post new "Hello World"
inkwell build
inkwell check
```

Or run the latest version without installing it globally:

```bash
mint run KristopherGBaker/inkwell inkwell init
mint run KristopherGBaker/inkwell inkwell post new "Hello World"
mint run KristopherGBaker/inkwell inkwell build
mint run KristopherGBaker/inkwell inkwell check
```

## Optional GitHub Pages Setup

If you want to deploy with GitHub Pages, generate the workflow after initialization:

```bash
inkwell init
inkwell deploy setup github-pages
```

This setup is optional and does not rewrite `blog.config.json`; review `baseURL` for your Pages URL before publishing.

## Quick Start From Repo
```bash
swift run inkwell init
swift run inkwell post new "Hello World"
swift run inkwell build
swift run inkwell check
```

## Developer Tooling
```bash
make brew-strap
make bootstrap-mint
make verify
```
