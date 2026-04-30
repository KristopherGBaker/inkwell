# `data/competencies.yml`

Group the user's skills into themed competency areas with one-line descriptions, suitable for the résumé page's "Core Competencies" section.

## Schema

```yaml
"Area Name": "Comma-separated description of the skills/tools/techniques in this area."
"Another Area": "..."
```

The file is an ordered YAML map. Order is meaningful — top entries appear first on the rendered page. See `templates/competencies.yml` for an annotated example.

## Extraction Rules

1. **3–6 areas.** Fewer reads thin; more starts to look like an unranked tag cloud.
2. **Areas are descriptive, not generic.** "Product & Growth" beats "Skills". "AI-Enabled Product" beats "AI". The area name should suggest what kind of work the user does there.
3. **Descriptions are sentence fragments, not lists.** Comma-separated noun phrases, no bullets, no terminal period needed (but consistent if used).
4. **Specific over generic.** "Swift concurrency (async/await, actors, Sendable)" beats "Swift". Concrete library/tool names beat categorical names.
5. **Don't repeat across areas.** Each tool/skill lands in exactly one area. If something genuinely spans two, place it where the user does the most work with it.
6. **Preserve technical naming.** "SwiftUI" not "Swift UI". "Anthropic" not "anthropic". Trademarks and product names retain capitalization from the source.

## What To Ask The User

- **If the source presents skills as a flat list** ("Skills: Swift, Python, AWS, Docker, ..."): propose a grouping and confirm before writing. Show the proposed area names + the skills landing under each.
- **If the source has area names that feel weak** ("Technical Skills", "Tools"): suggest stronger area names that describe the kind of work, not the kind of tool.
- **If an entry could go in multiple areas** (e.g., "Telemetry design" — Product? Architecture?): ask which one fits the user's self-image better.
- **If the count is off** (1–2 areas or 8+): suggest a regrouping.

## Common Pitfalls

- Over-engineering area names ("AI-Powered Product Engineering with LLM Orchestration"). Keep them tight.
- Alphabetizing. Order should reflect what the user wants emphasized first.
- Adding proficiency levels ("Expert in Swift, Proficient in Python") unless the source uses them — most modern résumés don't and shouldn't.
- Padding with buzzwords. If the user doesn't use "synergy" or "best-in-class," don't introduce them.
- Splitting too narrowly. "Swift Concurrency" and "Swift Performance" as separate areas is usually wrong; combine into "Concurrency & Performance".

## Output Sequence

1. Propose area names + their contents to the user.
2. Iterate on grouping until they agree.
3. Show the final YAML.
4. Write to `data/competencies.yml` after confirmation.
