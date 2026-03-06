# Swift Blog

Static personal blog generator written in Swift.

## Features
- Markdown posts with front matter
- GFM rendering (tables, task lists, strikethrough, fenced code)
- Syntax highlighting contract via `language-*` classes + Prism assets
- CLI workflow: `init`, `post new`, `post list`, `build`, `serve`, `check`

## Quick Start
```bash
swift run blog init
swift run blog post new "Hello World"
swift run blog build
swift run blog check
```
