---
name: portfolio-data
description: Use when populating an inkwell portfolio site's structured data — converting an existing résumé/CV (PDF, Word, plain text, LinkedIn export, or pasted notes) into `data/experience.yml`, `data/competencies.yml`, `data/education.yml`, and the `author` block in `blog.config.json`. Triggers on requests like "import my resume", "set up portfolio data", "convert CV to yml", "fill in experience.yml from this PDF".
---

# Portfolio Data

Use this skill to populate the structured data files that drive an inkwell portfolio's résumé page, work history, and site identity.

## When To Use

- User has a résumé/CV/LinkedIn export and wants it in inkwell's data format.
- User is setting up a new portfolio site and needs `data/*.yml` populated.
- User wants to extend or correct existing data files from updated source material.

## Input Sources Supported

- PDF résumé (`Read` the PDF directly, including multi-page).
- Plain text or markdown CV.
- Word doc (`.docx`) — read via PDF export or text extraction.
- LinkedIn "Save to PDF" export.
- Raw notes pasted into the conversation.

If multiple sources are available, prefer the most recent and most complete; ask the user which to treat as authoritative when they conflict.

## Output Files

| Target file | Purpose | Subskill |
|---|---|---|
| `data/experience.yml` | Work history (résumé page + about page hints) | `subskills/experience.md` |
| `data/competencies.yml` | Skill areas + descriptions (résumé page) | `subskills/competencies.md` |
| `data/education.yml` | School/degree/honors (résumé page) | `subskills/education.md` |
| `blog.config.json` (`author` block) | Site identity (header, footer, résumé header) | `subskills/author.md` |

## Standard Workflow

1. Ask the user where the source material lives. Read it.
2. Confirm scope: is this a fresh import, an update, or a partial fill?
3. Run each subskill in order, surfacing the proposed YAML/JSON for the user to review before writing.
4. Write files only after the user confirms the diff for that file. Never overwrite existing data without an explicit go-ahead.
5. After all writes, run `inkwell build` (or ask the user to) and spot-check the rendered résumé page.

## Guardrails

- **Preserve numbers verbatim.** "+29.8%" never becomes "~30%" or "nearly 30%". Metrics, percentages, dollar amounts, user counts, and dates carry exact wording from the source.
- **Don't fabricate.** If the source doesn't say it, don't write it. Flag missing fields explicitly and ask the user to supply them.
- **Flag uncertainty.** If a job's end date is ambiguous ("Present" vs. "Now" vs. a specific month), ask. If a competency could fit two areas, ask.
- **Preserve voice.** Bullet phrasing comes from the source. Lightly normalize for consistency (terminal punctuation, dash style) but don't rewrite.
- **One job = one entry.** Don't merge two roles at the same company. Don't split a single role across rows even if it spans years.
- **No proficiency levels invented.** "Expert in Swift" is not a phrase to add unless the source uses it.
- **Order matters.** Experience is reverse-chronological. Competencies preserve the order the user agrees on; don't alphabetize.

## Verification Pass

After writing all files, summarize for the user:

- Each role with start/end dates.
- Number of bullets per role.
- Competency area names + word count of each description.
- Education entry.
- Author identity fields populated.

Ask the user to scan for:
- Wrong dates or company names.
- Missing roles (gaps in chronology).
- Bullets that softened a number.
- Competency groupings they'd reorganize.

## Downloadable PDF résumé (v0.8.1+)

The `quiet` theme's résumé toolbar can either trigger `window.print()` (default) or link to a pre-rendered PDF download. Wire it up via `data/resume.yml`:

```yaml
pdf: /Kristopher_Baker_Resume.pdf
labels:
  download: Download résumé   # button copy when pdf: is set; defaults to "Download PDF"
  print: Print / Save as PDF  # button copy when pdf: is unset; the toolbar falls back to window.print()
```

When `pdf:` is set, the toolbar renders `<a href="…" download>…</a>` instead of the print button. Drop the actual PDF in `static/` so it lands at the URL you wrote. Per-language PDFs work naturally: `data/resume.ja.yml` with `pdf: /Kristopher_Baker_職務経歴書.pdf` ships the Japanese résumé to `/ja/resume/`.

## Page eyebrow

The bundled `resume` layout reads `page.eyebrow` from the page's front matter (v0.8.2+ — same surface as collection-list pages). Set `eyebrow: "05 · Résumé"` in `content/pages/resume.md` (and the equivalent in `resume.ja.md`) to match a numbered nav convention. Defaults to plain `"Résumé"` when unset.

## Multi-language data (v0.5+)

If the site has `i18n` configured and the user wants a translated résumé:

- Add a sibling YAML file with `<base>.<lang>.yml` — `data/experience.yml` (default) plus `data/experience.ja.yml` (Japanese). Same for `competencies.yml`, `education.yml`, `projects.yml`, and `resume.yml`.
- Inkwell prefers the `<lang>` variant when present and falls back to the unsuffixed file when missing — so the user can translate one file at a time.
- The résumé layout's section labels (Summary, Core Competencies, Experience, Projects, Education) and toolbar (`download` / `print`) come from `data/resume.yml`'s `labels:` block. Override per language by setting the same `labels:` block in `data/resume.ja.yml`.
- For Japanese, prefer the user's actual `職務経歴書` phrasing if they have one — it's a different register from English résumé style. Don't blindly translate verb-by-verb.

> Toolbar history: in v0.8.0 the bundled `← About` back-link was replaced by the page eyebrow on the left. Sites still using a `back:` label in `data/resume.yml` can drop it.

## Multi-Agent Notes

This skill is intended to be portable across agents (Claude Code, Codex, etc.). The body of each subskill is plain markdown describing a workflow — agents read the schema, extraction rules, and pitfalls, then use their own file/read tools to do the work. Frontmatter in this `SKILL.md` and subskills is for Claude Code's skill discovery.
