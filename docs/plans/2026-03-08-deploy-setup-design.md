# Optional Deployment Setup Design

## Context

`inkwell init` currently creates a local blog scaffold. Deployment hosting is a separate concern, and GitHub Pages should be opt-in so the CLI can support other hosting targets later.

## Decision

Add a new command path: `inkwell deploy setup github-pages`.

The command will:
- create a GitHub Pages workflow at `.github/workflows/pages.yml`
- read `blog.config.json` if present so the workflow uploads the configured `outputDir`
- avoid rewriting `blog.config.json`
- print a short reminder about checking `baseURL` and enabling Pages in repository settings

## Alternatives Considered

1. Keep GitHub Pages setup inside `init`
   - Rejected because it mixes local scaffolding with host-specific deployment concerns.
2. Add a flat command like `inkwell github-pages setup`
   - Rejected because it does not scale as cleanly to future deployment providers.
3. Automatically rewrite `blog.config.json`
   - Rejected because `baseURL` and output settings vary by repo and host mode.

## Testing

Add CLI tests that verify:
- the new command is registered
- the workflow file is created in a temp project
- the generated workflow uses the configured `outputDir`
- the command does not rewrite the existing `blog.config.json`
