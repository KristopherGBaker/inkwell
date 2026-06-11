# Contributing

## Requirements

- macOS 14+
- Swift 6.0+
- [Mint](https://github.com/yonaskolb/Mint) for pinned tooling (SwiftLint)
- Node.js 20+ (Shiki-based syntax highlighting in tests shells out to `node`)

Install tools:

```bash
make brew-strap        # install local tooling via Brewfile
make bootstrap-mint    # install Mint-managed tools (SwiftLint, etc.)
npm ci                 # install shiki for syntax highlighting in tests
```

## Build & test

```bash
swift build            # build the CLI
make lint              # SwiftLint
make test              # run the test suite
make verify            # lint + tests
make install           # install the built binary
```

`make verify` defaults to a Mint-managed SwiftLint pin. Override with `SWIFTLINT=swiftlint make verify` if you have SwiftLint on PATH.

Run a single test target with `swift test --filter <ClassName>`.

## Releases

Releases are tagged `v*` and published as universal macOS binaries on GitHub Releases. The Homebrew tap is updated automatically from the release workflow.

To cut a release:

1. Run `python3 scripts/bump_version.py X.Y.Z` (or `make bump-patch` / `bump-minor` / `bump-major`)
2. Review the diff, commit it, then tag and push: `git tag vX.Y.Z && git push origin vX.Y.Z`
