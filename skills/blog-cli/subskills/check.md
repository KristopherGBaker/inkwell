# `inkwell check`

Validates the project before deploy. Catches problems that `build` would either silently accept or surface late.

## Usage

```bash
inkwell check
inkwell check --json
```

## What It Checks

- **Front matter schema.** Required fields present, field types correct.
- **Front matter parse errors.** Files where YAML doesn't parse get clear "invalid front matter: ..." errors.
- **Asset paths in front matter.** For `coverImage`, `shots`, `featuredImage`, `ogImage`, `thumbnail`:
  - Relative paths like `assets/foo.png` are rejected (must be `/assets/...` or fully-qualified `https://...`).
  - `/assets/<path>` is checked against `static/assets/<path>` and `public/assets/<path>`. Missing files surface as errors.
- **Broken internal links.** Markdown body links to other pages that don't resolve.
- **Malformed `blog.config.json`.** JSON syntax errors, schema mismatches.
- **Taxonomy slug collisions.** When two distinct labels (e.g. `Swift` and `swift!`) normalize to the same slug.

## Output

```
Check passed
```

Or, on failure, a list of errors prefixed with the source file path. Exit code is non-zero on failure.

## Release Guidance

Treat any non-zero exit as a deploy blocker. Wire `inkwell check` into pre-merge CI for v0.3+ projects.
