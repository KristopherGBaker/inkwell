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

## Multi-language data (v0.5+)

If the site has `i18n` configured and the user wants a translated résumé:

- Add a sibling YAML file with `<base>.<lang>.yml` — `data/experience.yml` (default) plus `data/experience.ja.yml` (Japanese). Same for `competencies.yml`, `education.yml`, `projects.yml`, and `resume.yml`.
- Inkwell prefers the `<lang>` variant when present and falls back to the unsuffixed file when missing — so the user can translate one file at a time.
- The résumé layout's section labels (Summary, Core Competencies, Experience, Projects, Education) and toolbar (← About, Print / Save as PDF) come from `data/resume.yml`'s `labels:` block. Override per language by setting the same `labels:` block in `data/resume.ja.yml`.
- For Japanese, prefer the user's actual `職務経歴書` phrasing if they have one — it's a different register from English résumé style. Don't blindly translate verb-by-verb.

## Multi-Agent Notes

This skill is intended to be portable across agents (Claude Code, Codex, etc.). The body of each subskill is plain markdown describing a workflow — agents read the schema, extraction rules, and pitfalls, then use their own file/read tools to do the work. Frontmatter in this `SKILL.md` and subskills is for Claude Code's skill discovery.
