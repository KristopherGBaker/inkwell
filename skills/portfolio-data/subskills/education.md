# `data/education.yml`

Render the résumé's education section as a structured YAML object.

## Schema

```yaml
school: "Institution name"
degree: "Degree, field of study, optional minors"
honors: "Honors, GPA, distinctions (omit field entirely if none)"
```

Single object. See `templates/education.yml` for an annotated example.

## Extraction Rules

1. **One degree.** The current schema is a single object — typically the most recent or highest degree. If the user has multiple degrees they want shown, ask whether to:
   - Keep only the highest/most recent (recommended), or
   - Note in the open issues that the schema needs to extend to an array (defer; out of scope for v0.3).
2. **Preserve formatting verbatim.** "B.S. Computer Science" not "BS in Computer Science". Whatever the user has on the source.
3. **`honors` is optional.** Omit the key entirely if the source doesn't list any. Don't write `honors: ""` or `honors: null`.
4. **Combine degree + minor / concentration into one field.** Use the source's separator style: "B.S. Computer Science · Minor in Mathematics" or "B.S. Computer Science, Minor in Mathematics".
5. **No dates required.** The schema doesn't include graduation year today. If the user wants it shown, ask whether to extend the schema (defer) or include it inline in `degree`.

## What To Ask The User

- **If multiple degrees are listed**: which to feature?
- **If GPA appears**: include it under `honors` or omit? (Most senior résumés omit; ask.)
- **If certifications are mixed in with education**: they don't belong here. Ask if the user wants a separate `data/certifications.yml` (would require a schema/template addition; defer).

## Common Pitfalls

- Inventing honors. "Magna Cum Laude" must come from the source.
- Translating institution names. Use the source's spelling/casing.
- Padding with coursework or thesis title unless the user explicitly wants it shown.

## Output Sequence

1. Show proposed YAML.
2. Confirm.
3. Write `data/education.yml`.
