# `inkwell content new`

Scaffold a new content item in any declared collection.

## Usage

```bash
inkwell content new <collection> "<title>"
```

Examples:
```bash
inkwell content new posts "Hello World"
inkwell content new projects "Wolt Membership"
inkwell content new notes "On editorial sites"
```

## Prerequisite

The collection must be declared in `blog.config.json`:

```json
{
  "collections": [
    { "id": "projects", "dir": "content/projects", "route": "/work", "sortBy": "year" }
  ]
}
```

If the collection ID isn't found, the command fails with `Unknown collection '<id>'`.

## Behavior

`content new` reads the collection config and produces a scaffold whose shape depends on `sortBy`:

| `sortBy` | Filename | Front matter |
|----------|----------|--------------|
| `date` (default) | `YYYY-MM-DD-<slug>.md` | `title`, `date`, `slug`, `draft: true` |
| `year` | `<slug>.md` | `title`, `slug`, `year`, `summary`, `tags: []` |
| anything else | `<slug>.md` | `title`, `slug` |

The slug is derived from the title.

## Why this exists

`inkwell post new` is hardcoded to the `posts` collection and the date-shaped scaffold. `content new` works for any collection and picks a scaffold based on how that collection is sorted, so a year-organized projects list gets a `year:` field, a date-organized posts list gets a `date:` field, etc.

## Next Steps

- Edit the new file to fill in `summary`, `tags`, body content.
- For project case studies in the `quiet` theme, add `metrics` and `shots` fields if you want a metrics row and screenshot grid:

```yaml
metrics:
  - label: Conversion lift
    value: "+29.8%"
shots:
  - /assets/shots/wolt-1.png
```

- Run `inkwell build` to render.
