# Swift Blog

Static personal blog generator written in Swift.

## Features
- Markdown posts with front matter
- GFM rendering (tables, task lists, strikethrough, fenced code)
- Build-time syntax highlighting with Shiki
- CLI workflow: `init`, `post new`, `post list`, `build`, `serve`, `check`

## Quick Start
```bash
swift run inkwell init
swift run inkwell post new "Hello World"
swift run inkwell build
swift run inkwell check
```

## Developer Tooling
```bash
brew install xcodegen swiftlint
xcodegen generate
swiftlint lint --strict
```
