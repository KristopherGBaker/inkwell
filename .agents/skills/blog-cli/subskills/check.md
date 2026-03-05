# `blog check`

Validates generated output for broken internal links.

## Usage
```bash
blog check
blog check --json
```

## Behavior
- Passes when all internal links resolve.
- Prints `broken link: <path>` and exits non-zero on failure.

## Release Guidance
Treat non-zero exit as a deploy blocker.
