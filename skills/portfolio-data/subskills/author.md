# `author` block in `blog.config.json`

Populate the site identity fields from the résumé's header (name, role, location, contact, social links).

## Schema

```json
{
  "author": {
    "name": "Full name as user wants it shown",
    "role": "Headline role/title (e.g., 'Senior Software Engineer')",
    "location": "City, Country",
    "email": "contact@example.com",
    "social": [
      { "label": "LinkedIn", "url": "https://linkedin.com/in/handle" },
      { "label": "GitHub",   "url": "https://github.com/handle" }
    ]
  }
}
```

This block lives inside `blog.config.json`, alongside `title`, `baseURL`, etc. It is consumed by templates as `site.author.*` (header, footer, résumé header).

## Extraction Rules

1. **`name` is the rendered display name.** Match how the user spells their name on the résumé header. If they go by "Kris" professionally but "Kristopher" on the résumé, ask which to use.
2. **`role` is a single headline.** Not "Senior Software Engineer · iOS · Growth · AI" with a stack — that belongs in `description` or the home page hero. Keep `role` to the title that would print under the name on a résumé.
3. **`location` matches résumé.** "Tokyo, Japan" or "Remote" — whatever the user uses.
4. **`email` is the contact email, not a Git commit email.** Ask if multiple are present.
5. **Social links.**
   - Always full HTTPS URLs in `url`. Don't store handles only.
   - `label` is the human label rendered on the page. Use canonical capitalization: "LinkedIn", "GitHub", "Mastodon", "Bluesky", "X" (or "Twitter" if the user prefers).
   - Don't include phone numbers, addresses, or other PII the user didn't ask to publish.
   - If the résumé lists a personal site, include it as a social link with label "Website" or omit (it'll often equal the site being built).

## What To Ask The User

- If the résumé header lists multiple emails, phones, or sites: which should be public on the site?
- If the user has socials not on the résumé (e.g., a Mastodon handle): should those be added?
- If the role on the résumé is verbose ("Sr. Software Engineer II – Membership Growth, Mobile"): propose a tightened headline.
- Confirm whether the user wants the email rendered as plain text or a `mailto:` link only (templates handle this; the data is the same).

## Common Pitfalls

- Putting site title or tagline into `role` — those belong in `title`/`description` at the top level of `blog.config.json`.
- Using bare URLs without scheme: `linkedin.com/in/handle` will not render as a working link in most templates. Use `https://linkedin.com/in/handle`.
- Inferring social handles from email addresses or names. If the source doesn't have it, ask.
- Adding social platforms the user doesn't actively use. Better to omit than to have a stale link.

## Merging With Existing Config

`blog.config.json` likely already exists with `title`, `baseURL`, `theme`, etc. The author block is *added*, not replacing the file. Read the current JSON, merge the `author` key, write back preserving the rest. Maintain key order if practical (place `author` after `head` and before any later keys like `nav`/`collections`/`home`).

## Output Sequence

1. Show the proposed `"author": { ... }` block.
2. Confirm.
3. Read the existing `blog.config.json`, merge the block in, write back.
4. Confirm the file's other fields are intact.
