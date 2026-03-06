---
name: blog-writing
description: Use when writing or editing blog post content and you need consistent author voice, structure, and quality using a reusable voice profile file.
---

# Blog Writing

Use this skill when drafting, revising, or polishing post content for the inkwell blog.

## Voice Profile Contract

Primary voice file path (default):
- `content/voice-profile.md`

If the file is missing:
1. Offer to create it from `templates/voice-profile-template.md`.
2. Gather preferences collaboratively (tone, audience, themes, boundaries).
3. Save the completed profile before writing the post draft.

## Writing Workflow

1. Read `content/voice-profile.md`.
2. Extract constraints (tone, style, formatting, banned patterns).
3. Propose a compact post outline (hook -> body sections -> close).
4. Draft content in the configured voice.
5. Self-check against profile requirements.
6. Revise for clarity, specificity, and narrative flow.

## Default Post Shape

- Opening: concrete hook in 2-4 sentences.
- Main body: 2-4 sections with clear section headings.
- Closing: practical takeaway and optional next action.

## Guardrails

- Prefer specific anecdotes/examples over abstraction.
- Avoid generic motivational filler.
- Keep sentence length varied and readable.
- Preserve technical accuracy and uncertainty markers.
- Match the intended audience from the voice profile.

## Collaborative Voice-Profile Mode

When the user says they need help defining their voice:
- Ask one focused question at a time.
- Start with purpose and audience.
- Then capture style dimensions (directness, humor, vulnerability, detail depth).
- Add "always do" and "never do" writing rules.
- Write results into `content/voice-profile.md` using the template structure.

## Quick Commands

- Create profile starter: copy `templates/voice-profile-template.md` -> `content/voice-profile.md`
- Draft new post: `inkwell post new "Title"`
- Build preview after editing: `inkwell build && inkwell serve`
