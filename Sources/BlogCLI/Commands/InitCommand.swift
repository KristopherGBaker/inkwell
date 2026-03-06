import ArgumentParser
import Foundation

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "init", abstract: "Initialize a blog project")

    mutating func run() throws {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        try fm.createDirectory(at: cwd.appendingPathComponent("content/posts"), withIntermediateDirectories: true)
        try fm.createDirectory(at: cwd.appendingPathComponent("themes/default/templates"), withIntermediateDirectories: true)
        try fm.createDirectory(at: cwd.appendingPathComponent("themes/default/assets/css"), withIntermediateDirectories: true)
        try fm.createDirectory(at: cwd.appendingPathComponent("themes/default/assets/js"), withIntermediateDirectories: true)
        try fm.createDirectory(at: cwd.appendingPathComponent("public"), withIntermediateDirectories: true)

        let config = """
        {
          "title": "My Blog",
          "baseURL": "/",
          "theme": "default",
          "outputDir": "docs"
        }
        """
        try config.write(to: cwd.appendingPathComponent("blog.config.json"), atomically: true, encoding: .utf8)

        let themeManifest = """
        {
          "name": "default",
          "version": "0.1.0",
          "compatibleCore": ">=0.1.0"
        }
        """
        try themeManifest.write(to: cwd.appendingPathComponent("themes/default/theme.json"), atomically: true, encoding: .utf8)

        let layout = """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>{{title}}</title>
          <link rel="stylesheet" href="/assets/css/prism.css">
        </head>
        <body>
          <main>{{content}}</main>
          <script defer src="/assets/js/prism.js"></script>
        </body>
        </html>
        """
        try layout.write(to: cwd.appendingPathComponent("themes/default/templates/layout.html"), atomically: true, encoding: .utf8)

        let searchScript = """
        (() => {
          let indexPromise = null;

          function fetchIndex() {
            if (!indexPromise) {
              indexPromise = fetch('/search-index.json', { cache: 'no-store' })
                .then((response) => (response.ok ? response.json() : { posts: [] }))
                .catch(() => ({ posts: [] }));
            }
            return indexPromise;
          }

          function scorePost(post, query, terms) {
            const title = (post.title || '').toLowerCase();
            const summary = (post.summary || '').toLowerCase();
            const body = (post.body || '').toLowerCase();
            const labels = `${(post.tags || []).join(' ')} ${(post.categories || []).join(' ')}`.toLowerCase();
            const haystack = `${title} ${summary} ${labels} ${body}`;

            if (!terms.every((term) => haystack.includes(term))) {
              return -1;
            }

            let score = 0;
            if (title.includes(query)) score += 6;
            if (summary.includes(query)) score += 4;
            if (labels.includes(query)) score += 2;
            if (body.includes(query)) score += 1;
            return score;
          }

          function renderResults(container, status, posts) {
            if (posts.length === 0) {
              container.classList.add('hidden');
              container.innerHTML = '';
              status.textContent = 'No matches yet.';
              return;
            }

            const html = posts
              .map((post) => {
                const safeTitle = (post.title || 'Untitled').replace(/</g, '&lt;').replace(/>/g, '&gt;');
                const safeSummary = (post.summary || '').replace(/</g, '&lt;').replace(/>/g, '&gt;');
                return `<article class="rounded-xl border border-stone-300/70 bg-stone-50/70 p-4 dark:border-stone-700 dark:bg-stone-900/65"><p class="text-xs uppercase tracking-[0.16em] text-stone-500 dark:text-stone-400">${post.date || ''}</p><h3 class="mt-1 font-display text-xl text-stone-900 dark:text-stone-100"><a class="underline decoration-amber-700/40 underline-offset-4" href="/posts/${post.slug}/">${safeTitle}</a></h3><p class="mt-2 text-sm text-stone-700 dark:text-stone-300">${safeSummary}</p></article>`;
              })
              .join('');

            container.innerHTML = html;
            container.classList.remove('hidden');
            status.textContent = `${posts.length} result${posts.length === 1 ? '' : 's'}`;
          }

          function initializeSearch() {
            const input = document.getElementById('search-input');
            const results = document.getElementById('search-results');
            const status = document.getElementById('search-status');
            if (!input || !results || !status) return;

            let timer = null;

            input.addEventListener('focus', () => {
              void fetchIndex();
            });

            input.addEventListener('input', () => {
              const query = input.value.trim().toLowerCase();

              if (timer) {
                clearTimeout(timer);
              }

              if (query.length < 2) {
                results.classList.add('hidden');
                results.innerHTML = '';
                status.textContent = query.length === 0 ? '' : 'Keep typing to search.';
                return;
              }

              status.textContent = 'Searching...';
              timer = setTimeout(() => {
                void fetchIndex().then((payload) => {
                  const terms = query.split(/\\s+/).filter(Boolean);
                  const ranked = (payload.posts || [])
                    .map((post) => ({ post, score: scorePost(post, query, terms) }))
                    .filter((entry) => entry.score >= 0)
                    .sort((left, right) => right.score - left.score)
                    .slice(0, 8)
                    .map((entry) => entry.post);

                  renderResults(results, status, ranked);
                });
              }, 280);
            });
          }

          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', initializeSearch);
          } else {
            initializeSearch();
          }
        })();
        """

        try searchScript.write(to: cwd.appendingPathComponent("themes/default/assets/js/search.js"), atomically: true, encoding: .utf8)
        try "window.Prism = window.Prism || {};\n".write(to: cwd.appendingPathComponent("themes/default/assets/js/prism.js"), atomically: true, encoding: .utf8)
        try "pre[class*=\"language-\"]{background:#0f172a;color:#e2e8f0;padding:1rem;border-radius:8px;overflow-x:auto;}\n".write(to: cwd.appendingPathComponent("themes/default/assets/css/prism.css"), atomically: true, encoding: .utf8)
        print("Initialized blog project")
    }
}
