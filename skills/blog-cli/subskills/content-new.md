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

`content new` reads the collection config and produces a scaffold whose shape depends on `sortBy` (and on whether the collection is a child collection):

| Collection | Filename | Front matter |
|----------|----------|--------------|
| `sortBy: date` (default) | `YYYY-MM-DD-<slug>.md` | `title`, `date`, `slug`, `draft: true` |
| `sortBy: year` | `<slug>.md` | `title`, `slug`, `year`, `summary`, `tags: []` |
| anything else | `<slug>.md` | `title`, `slug` |
| **child collection** (`parent` set) | `YYYY-MM-DD-<slug>.md` | `title`, `date`, `slug`, `<parentField>:`, `draft: true` |

The slug is derived from the title.

## Child collections (e.g. project updates)

A collection with `parent` set is a *child collection*: its items hang off a parent item and are routed under it at `<parentRoute>/<parentSlug>/<slug>/` (no list/taxonomy of their own). The canonical use is a "Building" section where each project (`building`) has a chronological stream of `updates`.

```json
{
  "collections": [
    { "id": "building", "dir": "content/building", "route": "/building",
      "sortBy": "order", "listTemplate": "layouts/building-list", "detailTemplate": "layouts/building" },
    { "id": "updates", "dir": "content/updates", "route": "/building",
      "parent": "building", "parentField": "project", "detailTemplate": "layouts/update" }
  ]
}
```

For a child collection, `content new` always produces a dated file pre-seeded with the parent-link field, so posting an update is low-friction:

```bash
inkwell content new updates "Streaming tool calls"
# → content/updates/2026-06-04-streaming-tool-calls.md
# front matter: title, date, slug, project: (blank), draft: true
```

Fill in the `project:` value with the parent's slug. An update whose `project:` matches no parent slug is flagged by `inkwell check` (it would otherwise drop silently from the build). The newest updates also surface on the parent's detail-page timeline and, if configured, in the home `buildingCollection` feed.

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
