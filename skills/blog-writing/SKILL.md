---
name: blog-writing
description: Use when drafting or editing prose content (blog posts, project case studies, standalone pages, about copy) for an inkwell site. Reads a voice profile, proposes a structure, then drafts in the configured voice.
---

# Inkwell Writing

Use this skill when drafting, revising, or polishing prose content for an inkwell site. Works for posts, project case studies, and pages alike — the core loop (read voice profile → identify tension → propose shape → draft → self-check) is the same; only the structure differs.

## Voice Profile Contract

Primary voice file path (default):
- `content/voice-profile.md`

If the file is missing:
1. Offer to create it from `templates/voice-profile-template.md`.
2. Gather preferences collaboratively (tone, audience, themes, boundaries).
3. Save the completed profile before writing the draft.

## Writing Workflow

1. Read `content/voice-profile.md`.
2. Extract constraints (tone, style, formatting, banned patterns).
3. Before drafting, identify:
   - the central tension
   - the real constraint
   - the thing that changed
4. Propose a compact outline appropriate for the content type (see "Structure by Type" below).
5. Draft content in the configured voice.
6. Self-check against profile requirements.
7. Revise for clarity, specificity, and narrative flow.

## Structure by Type

### Blog post (`content/posts/`)
- Opening: concrete hook in 2–4 sentences.
- Main body: 2–4 sections with clear headings.
- Closing: practical takeaway and optional next action.

### Project case study (`content/projects/<slug>.md` with `quiet` theme's `case-study` layout)
- Front matter carries the headline metrics in a `metrics:` array — write those first; they anchor the rest.
- Opening paragraph: what the project was, your role, the time window.
- Sections that work well:
  - Context
  - Constraints
  - Approach
  - What changed
  - What I'd do differently
- Closing: durable lesson or what shipped beyond the headline metric.
- The body is technical-but-readable. The metrics row carries the numbers; the prose carries the story.

### Standalone page (`content/pages/<name>.md`)
- About / Now / Colophon-style pages: usually one section, conversational, no eyebrow needed.
- Pages can be data-driven shells (empty body, theme template reads from `data/*.yml`) — the résumé page is one of these. For shells, you don't write prose at all; the structured data is the content.

## Default Post Shape

- Opening: concrete hook.
- 2–4 body sections with headings.
- Closing with takeaway or reflection.

## Guardrails

- Prefer specific anecdotes / examples / numbers over abstraction.
- Avoid generic motivational filler.
- Keep sentence length varied and readable.
- Preserve technical accuracy and uncertainty markers.
- Match the intended audience from the voice profile.
- Prefer real constraints over abstract framing.
- Show trade-offs honestly, including unresolved ones.
- Ground observations in workflows, behavior changes, or lived experience.
- Explain why the system mattered before diving deeply into implementation details.
- Preserve nuance instead of flattening everything into a strong opinion.
- For case studies: numbers are sacred. Don't soften "+29.8%" to "~30%" or "nearly 30%". Match the source material's exact phrasing.

## Self-Check Pass

Before finalizing, verify:

- Could this paragraph apply to almost anyone?
- Does this section contain a real constraint, trade-off, or decision?
- Are there enough concrete details?
- Is the technical depth earned by context?
- Did the writing accidentally become motivational, preachy, or self-important?
- Are opposing viewpoints acknowledged fairly?
- Does the draft sound like someone who actually used the workflow being described?
- Are there places where uncertainty or awkwardness should be admitted more honestly?
- Are small environmental or lived details helping ground the writing?

If the answer to several of these is "no", revise before finalizing.

## Collaborative Voice-Profile Mode

When the user says they need help defining their voice:
- Ask one focused question at a time.
- Start with purpose and audience.
- Then capture style dimensions (directness, humor, vulnerability, detail depth).
- Add "always do" and "never do" writing rules.
- Look for recurring themes, tensions, and lived constraints in the user's answers.
- Write results into `content/voice-profile.md` using the template structure.

## Quick Commands

- Create voice profile starter:
  - copy `templates/voice-profile-template.md` → `content/voice-profile.md`
- Draft a blog post:
  - `inkwell post new "Title"`
- Draft a project case study:
  - `inkwell content new projects "Title"`
- Build preview after editing:
  - `inkwell serve --watch`

## Related Skills

- `portfolio-data` for résumé / experience content (those go in `data/*.yml`, not prose).
- `site-setup` for initial project configuration.
- `blog-cli` for build / preview / publish commands.
