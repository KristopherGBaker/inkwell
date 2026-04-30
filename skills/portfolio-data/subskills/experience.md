# `data/experience.yml`

Convert a résumé's work-history section into structured YAML for the inkwell portfolio's résumé page.

## Schema

```yaml
- org: "Company name as it appears on the résumé"
  role: "Role/title for this position"
  years: "Date range — preserve source format (e.g. '2023 — Now', 'Jan 2019 – Apr 2023')"
  location: "City, Country (or 'Remote')"
  bullets:
    - "First impact bullet, verbatim from source where possible"
    - "Second bullet"
    - "..."
```

The file is a YAML array; each entry is one role. Reverse-chronological order (most recent first).

See `templates/experience.yml` for an annotated example.

## Extraction Rules

1. **One entry per role.** A promotion at the same company is two entries (with the same `org`, different `role` and `years`). An internal team move with the same title is one entry; mention the move in a bullet if it matters.
2. **Preserve dates verbatim.** If the résumé says "2023 — Now", don't normalize to "2023 – Present". If it says "Jan 2019", keep that granularity.
3. **Bullets stay close to source.** Light normalization (punctuation, em-dash style, removing résumé-isms like "Responsible for") is fine. Substantive rewording is not.
4. **Numbers are sacred.** "+29.8%", "27,000", "tens of millions" — copy exactly. Never round, generalize, or compress ("over 27k" is not the same as "+27,000").
5. **Order bullets by impact.** Most résumés already do this. If yours doesn't, ask the user before reordering.
6. **Skip headers and decoration.** Section titles, separators, page numbers, and contact-info reprints in the footer aren't entries.
7. **Honor unusual job shapes.** Contract roles, fellowships, sabbaticals — render with whatever role/org best matches the source. If the source omits a location, omit `location` rather than guessing.

## What To Ask The User

- If two roles at the same company overlap or have unclear boundaries: "Were these concurrent or sequential? Same role with a title change, or two distinct roles?"
- If a role uses "Present" / "Now" / "Current": "How would you like the end date phrased on the rendered page?"
- If bullets exceed 6–8 per role: "Want me to keep all of these or trim to the strongest ones?"

## Common Pitfalls

- Merging two distinct roles at the same company because the bullets blur together.
- Rewriting bullets in a uniform voice. Each bullet's phrasing is the user's; preserve it.
- Translating dates ("Jan 2023 – Mar 2025") into the prototype's style ("2023 — 2025") without asking.
- Dropping a bullet because it's not impressive. The user wrote it on purpose.
- Adding a missing role from LinkedIn that wasn't on the résumé. If sources disagree, ask.

## Output Sequence

1. Show the proposed YAML in the chat.
2. Wait for confirmation or edits.
3. Write to `data/experience.yml` (creating the `data/` directory if it doesn't exist).
4. Confirm the write and the entry count.
