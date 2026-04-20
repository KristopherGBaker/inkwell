# Contributing

## Requirements

- macOS 14+
- Swift 6.0+
- [Mint](https://github.com/yonaskolb/Mint) for pinned tooling

Install tools:

```bash
make bootstrap
```

## Build & Test

```bash
make build
make test
make lint
make verify
make install
```

## Releases

Releases are tagged `v*` and published as universal macOS binaries on GitHub Releases. The Homebrew tap is updated automatically from the release workflow.

To cut a release:

1. Run `python3 Scripts/bump_version.py X.Y.Z`
2. Review the diff, commit it, then tag and push: `git tag vX.Y.Z && git push origin vX.Y.Z`
