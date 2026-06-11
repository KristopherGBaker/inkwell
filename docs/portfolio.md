# Building a portfolio

The `quiet` theme plus content collections turn Inkwell into a portfolio generator: case studies, a "what I'm building" feed, a data-driven résumé, and a blog on one site.

## Quick start

```bash
inkwell init
# edit blog.config.json: set theme, add author/nav/home/collections
inkwell content new projects "Wolt Membership"
# add data/experience.yml, data/competencies.yml, data/education.yml
inkwell build
inkwell check
```

## Example config

```json
{
  "title": "Kristopher Baker",
  "baseURL": "https://krisbaker.com/",
  "theme": "quiet",
  "outputDir": "docs",
  "tagline": "Tokyo · Available for new conversations",
  "author": {
    "name": "Kristopher Baker",
    "role": "Senior Software Engineer",
    "location": "Tokyo, Japan",
    "social": [{ "label": "GitHub", "url": "https://github.com/KristopherGBaker" }]
  },
  "nav": [
    { "label": "Work", "route": "/work/" },
    { "label": "Writing", "route": "/posts/" },
    { "label": "Résumé", "route": "/resume/" }
  ],
  "home": {
    "template": "landing",
    "featuredCollection": "projects",
    "featuredCount": 4,
    "buildingCollection": "updates",
    "buildingCount": 3,
    "recentCollection": "posts",
    "recentCount": 2
  },
  "collections": [
    { "id": "posts", "dir": "content/posts", "route": "/posts" },
    {
      "id": "projects",
      "dir": "content/projects",
      "route": "/work",
      "sortBy": "year",
      "taxonomies": ["tags"],
      "detailTemplate": "layouts/case-study"
    },
    {
      "id": "building",
      "dir": "content/building",
      "route": "/building",
      "sortBy": "order",
      "taxonomies": ["tags"],
      "listTemplate": "layouts/building-list",
      "detailTemplate": "layouts/building"
    },
    {
      "id": "updates",
      "dir": "content/updates",
      "route": "/building",
      "parent": "building",
      "parentField": "project",
      "detailTemplate": "layouts/update"
    }
  ]
}
```

See [Concepts](concepts.md) for what collections, child collections, and the `home` block do.

## Résumé page

Drop a one-liner shell into `content/pages/resume.md`:

```markdown
---
title: Résumé
layout: resume
---
```

The `resume` layout ignores the markdown body and reads from `data/experience.yml`, `data/competencies.yml`, and `data/education.yml`.

The `portfolio-data` agent skill walks Claude Code (or any compatible agent) through importing your existing résumé into those files. Run `/portfolio-data` to start.
