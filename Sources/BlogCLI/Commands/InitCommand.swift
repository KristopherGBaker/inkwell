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
          "version": "\(BlogVersion.version)",
          "compatibleCore": ">=\(BlogVersion.version)"
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
          const script = document.currentScript;
          let indexPromise = null;

          function resolveBasePath() {
            if (!script || !script.src) {
              return '';
            }

            try {
              const scriptURL = new URL(script.src, window.location.href);
              const marker = '/assets/js/';
              const markerIndex = scriptURL.pathname.indexOf(marker);
              if (markerIndex >= 0) {
                return scriptURL.pathname.slice(0, markerIndex);
              }
            } catch (_) {
              return '';
            }

            return '';
          }

          const basePath = resolveBasePath();

          function siteURL(path) {
            return `${basePath}${path}`;
          }

          function fetchIndex() {
            if (!indexPromise) {
              indexPromise = fetch(siteURL('/search-index.json'), { cache: 'no-store' })
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
                return `<article class="rounded-xl border border-stone-300/70 bg-stone-50/70 p-4 dark:border-stone-700 dark:bg-stone-900/65"><p class="text-xs uppercase tracking-[0.16em] text-stone-500 dark:text-stone-400">${post.date || ''}</p><h3 class="mt-1 font-display text-xl text-stone-900 dark:text-stone-100"><a class="underline decoration-amber-700/40 underline-offset-4" href="${siteURL(`/posts/${post.slug}/`)}">${safeTitle}</a></h3><p class="mt-2 text-sm text-stone-700 dark:text-stone-300">${safeSummary}</p></article>`;
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
        try defaultTailwindCSSData.write(to: cwd.appendingPathComponent("themes/default/assets/css/tailwind.css"))
        print("Initialized blog project")
    }
}

private let defaultTailwindCSSData = Data(base64Encoded: "Kiw6YWZ0ZXIsOmJlZm9yZXstLXR3LWJvcmRlci1zcGFjaW5nLXg6MDstLXR3LWJvcmRlci1zcGFjaW5nLXk6MDstLXR3LXRyYW5zbGF0ZS14OjA7LS10dy10cmFuc2xhdGUteTowOy0tdHctcm90YXRlOjA7LS10dy1za2V3LXg6MDstLXR3LXNrZXcteTowOy0tdHctc2NhbGUteDoxOy0tdHctc2NhbGUteToxOy0tdHctcGFuLXg6IDstLXR3LXBhbi15OiA7LS10dy1waW5jaC16b29tOiA7LS10dy1zY3JvbGwtc25hcC1zdHJpY3RuZXNzOnByb3hpbWl0eTstLXR3LWdyYWRpZW50LWZyb20tcG9zaXRpb246IDstLXR3LWdyYWRpZW50LXZpYS1wb3NpdGlvbjogOy0tdHctZ3JhZGllbnQtdG8tcG9zaXRpb246IDstLXR3LW9yZGluYWw6IDstLXR3LXNsYXNoZWQtemVybzogOy0tdHctbnVtZXJpYy1maWd1cmU6IDstLXR3LW51bWVyaWMtc3BhY2luZzogOy0tdHctbnVtZXJpYy1mcmFjdGlvbjogOy0tdHctcmluZy1pbnNldDogOy0tdHctcmluZy1vZmZzZXQtd2lkdGg6MHB4Oy0tdHctcmluZy1vZmZzZXQtY29sb3I6I2ZmZjstLXR3LXJpbmctY29sb3I6cmdiYSg1OSwxMzAsMjQ2LC41KTstLXR3LXJpbmctb2Zmc2V0LXNoYWRvdzowIDAgIzAwMDA7LS10dy1yaW5nLXNoYWRvdzowIDAgIzAwMDA7LS10dy1zaGFkb3c6MCAwICMwMDAwOy0tdHctc2hhZG93LWNvbG9yZWQ6MCAwICMwMDAwOy0tdHctYmx1cjogOy0tdHctYnJpZ2h0bmVzczogOy0tdHctY29udHJhc3Q6IDstLXR3LWdyYXlzY2FsZTogOy0tdHctaHVlLXJvdGF0ZTogOy0tdHctaW52ZXJ0OiA7LS10dy1zYXR1cmF0ZTogOy0tdHctc2VwaWE6IDstLXR3LWRyb3Atc2hhZG93OiA7LS10dy1iYWNrZHJvcC1ibHVyOiA7LS10dy1iYWNrZHJvcC1icmlnaHRuZXNzOiA7LS10dy1iYWNrZHJvcC1jb250cmFzdDogOy0tdHctYmFja2Ryb3AtZ3JheXNjYWxlOiA7LS10dy1iYWNrZHJvcC1odWUtcm90YXRlOiA7LS10dy1iYWNrZHJvcC1pbnZlcnQ6IDstLXR3LWJhY2tkcm9wLW9wYWNpdHk6IDstLXR3LWJhY2tkcm9wLXNhdHVyYXRlOiA7LS10dy1iYWNrZHJvcC1zZXBpYTogOy0tdHctY29udGFpbi1zaXplOiA7LS10dy1jb250YWluLWxheW91dDogOy0tdHctY29udGFpbi1wYWludDogOy0tdHctY29udGFpbi1zdHlsZTogfTo6YmFja2Ryb3B7LS10dy1ib3JkZXItc3BhY2luZy14OjA7LS10dy1ib3JkZXItc3BhY2luZy15OjA7LS10dy10cmFuc2xhdGUteDowOy0tdHctdHJhbnNsYXRlLXk6MDstLXR3LXJvdGF0ZTowOy0tdHctc2tldy14OjA7LS10dy1za2V3LXk6MDstLXR3LXNjYWxlLXg6MTstLXR3LXNjYWxlLXk6MTstLXR3LXBhbi14OiA7LS10dy1wYW4teTogOy0tdHctcGluY2gtem9vbTogOy0tdHctc2Nyb2xsLXNuYXAtc3RyaWN0bmVzczpwcm94aW1pdHk7LS10dy1ncmFkaWVudC1mcm9tLXBvc2l0aW9uOiA7LS10dy1ncmFkaWVudC12aWEtcG9zaXRpb246IDstLXR3LWdyYWRpZW50LXRvLXBvc2l0aW9uOiA7LS10dy1vcmRpbmFsOiA7LS10dy1zbGFzaGVkLXplcm86IDstLXR3LW51bWVyaWMtZmlndXJlOiA7LS10dy1udW1lcmljLXNwYWNpbmc6IDstLXR3LW51bWVyaWMtZnJhY3Rpb246IDstLXR3LXJpbmctaW5zZXQ6IDstLXR3LXJpbmctb2Zmc2V0LXdpZHRoOjBweDstLXR3LXJpbmctb2Zmc2V0LWNvbG9yOiNmZmY7LS10dy1yaW5nLWNvbG9yOnJnYmEoNTksMTMwLDI0NiwuNSk7LS10dy1yaW5nLW9mZnNldC1zaGFkb3c6MCAwICMwMDAwOy0tdHctcmluZy1zaGFkb3c6MCAwICMwMDAwOy0tdHctc2hhZG93OjAgMCAjMDAwMDstLXR3LXNoYWRvdy1jb2xvcmVkOjAgMCAjMDAwMDstLXR3LWJsdXI6IDstLXR3LWJyaWdodG5lc3M6IDstLXR3LWNvbnRyYXN0OiA7LS10dy1ncmF5c2NhbGU6IDstLXR3LWh1ZS1yb3RhdGU6IDstLXR3LWludmVydDogOy0tdHctc2F0dXJhdGU6IDstLXR3LXNlcGlhOiA7LS10dy1kcm9wLXNoYWRvdzogOy0tdHctYmFja2Ryb3AtYmx1cjogOy0tdHctYmFja2Ryb3AtYnJpZ2h0bmVzczogOy0tdHctYmFja2Ryb3AtY29udHJhc3Q6IDstLXR3LWJhY2tkcm9wLWdyYXlzY2FsZTogOy0tdHctYmFja2Ryb3AtaHVlLXJvdGF0ZTogOy0tdHctYmFja2Ryb3AtaW52ZXJ0OiA7LS10dy1iYWNrZHJvcC1vcGFjaXR5OiA7LS10dy1iYWNrZHJvcC1zYXR1cmF0ZTogOy0tdHctYmFja2Ryb3Atc2VwaWE6IDstLXR3LWNvbnRhaW4tc2l6ZTogOy0tdHctY29udGFpbi1sYXlvdXQ6IDstLXR3LWNvbnRhaW4tcGFpbnQ6IDstLXR3LWNvbnRhaW4tc3R5bGU6IH0vKiEgdGFpbHdpbmRjc3MgdjMuNC4xOSB8IE1JVCBMaWNlbnNlIHwgaHR0cHM6Ly90YWlsd2luZGNzcy5jb20qLyosOmFmdGVyLDpiZWZvcmV7Ym94LXNpemluZzpib3JkZXItYm94O2JvcmRlcjowIHNvbGlkICNlNWU3ZWJ9OmFmdGVyLDpiZWZvcmV7LS10dy1jb250ZW50OiIifTpob3N0LGh0bWx7bGluZS1oZWlnaHQ6MS41Oy13ZWJraXQtdGV4dC1zaXplLWFkanVzdDoxMDAlOy1tb3otdGFiLXNpemU6NDstby10YWItc2l6ZTo0O3RhYi1zaXplOjQ7Zm9udC1mYW1pbHk6TWFucm9wZSxzYW5zLXNlcmlmO2ZvbnQtZmVhdHVyZS1zZXR0aW5nczpub3JtYWw7Zm9udC12YXJpYXRpb24tc2V0dGluZ3M6bm9ybWFsOy13ZWJraXQtdGFwLWhpZ2hsaWdodC1jb2xvcjp0cmFuc3BhcmVudH1ib2R5e21hcmdpbjowO2xpbmUtaGVpZ2h0OmluaGVyaXR9aHJ7aGVpZ2h0OjA7Y29sb3I6aW5oZXJpdDtib3JkZXItdG9wLXdpZHRoOjFweH1hYmJyOndoZXJlKFt0aXRsZV0pey13ZWJraXQtdGV4dC1kZWNvcmF0aW9uOnVuZGVybGluZSBkb3R0ZWQ7dGV4dC1kZWNvcmF0aW9uOnVuZGVybGluZSBkb3R0ZWR9aDEsaDIsaDMsaDQsaDUsaDZ7Zm9udC1zaXplOmluaGVyaXQ7Zm9udC13ZWlnaHQ6aW5oZXJpdH1he2NvbG9yOmluaGVyaXQ7dGV4dC1kZWNvcmF0aW9uOmluaGVyaXR9YixzdHJvbmd7Zm9udC13ZWlnaHQ6Ym9sZGVyfWNvZGUsa2JkLHByZSxzYW1we2ZvbnQtZmFtaWx5OkpldEJyYWlucyBNb25vLG1vbm9zcGFjZTtmb250LWZlYXR1cmUtc2V0dGluZ3M6bm9ybWFsO2ZvbnQtdmFyaWF0aW9uLXNldHRpbmdzOm5vcm1hbDtmb250LXNpemU6MWVtfXNtYWxse2ZvbnQtc2l6ZTo4MCV9c3ViLHN1cHtmb250LXNpemU6NzUlO2xpbmUtaGVpZ2h0OjA7cG9zaXRpb246cmVsYXRpdmU7dmVydGljYWwtYWxpZ246YmFzZWxpbmV9c3Vie2JvdHRvbTotLjI1ZW19c3Vwe3RvcDotLjVlbX10YWJsZXt0ZXh0LWluZGVudDowO2JvcmRlci1jb2xvcjppbmhlcml0O2JvcmRlci1jb2xsYXBzZTpjb2xsYXBzZX1idXR0b24saW5wdXQsb3B0Z3JvdXAsc2VsZWN0LHRleHRhcmVhe2ZvbnQtZmFtaWx5OmluaGVyaXQ7Zm9udC1mZWF0dXJlLXNldHRpbmdzOmluaGVyaXQ7Zm9udC12YXJpYXRpb24tc2V0dGluZ3M6aW5oZXJpdDtmb250LXNpemU6MTAwJTtmb250LXdlaWdodDppbmhlcml0O2xpbmUtaGVpZ2h0OmluaGVyaXQ7bGV0dGVyLXNwYWNpbmc6aW5oZXJpdDtjb2xvcjppbmhlcml0O21hcmdpbjowO3BhZGRpbmc6MH1idXR0b24sc2VsZWN0e3RleHQtdHJhbnNmb3JtOm5vbmV9YnV0dG9uLGlucHV0OndoZXJlKFt0eXBlPWJ1dHRvbl0pLGlucHV0OndoZXJlKFt0eXBlPXJlc2V0XSksaW5wdXQ6d2hlcmUoW3R5cGU9c3VibWl0XSl7LXdlYmtpdC1hcHBlYXJhbmNlOmJ1dHRvbjtiYWNrZ3JvdW5kLWNvbG9yOnRyYW5zcGFyZW50O2JhY2tncm91bmQtaW1hZ2U6bm9uZX06LW1vei1mb2N1c3Jpbmd7b3V0bGluZTphdXRvfTotbW96LXVpLWludmFsaWR7Ym94LXNoYWRvdzpub25lfXByb2dyZXNze3ZlcnRpY2FsLWFsaWduOmJhc2VsaW5lfTo6LXdlYmtpdC1pbm5lci1zcGluLWJ1dHRvbiw6Oi13ZWJraXQtb3V0ZXItc3Bpbi1idXR0b257aGVpZ2h0OmF1dG99W3R5cGU9c2VhcmNoXXstd2Via2l0LWFwcGVhcmFuY2U6dGV4dGZpZWxkO291dGxpbmUtb2Zmc2V0Oi0ycHh9Ojotd2Via2l0LXNlYXJjaC1kZWNvcmF0aW9uey13ZWJraXQtYXBwZWFyYW5jZTpub25lfTo6LXdlYmtpdC1maWxlLXVwbG9hZC1idXR0b257LXdlYmtpdC1hcHBlYXJhbmNlOmJ1dHRvbjtmb250OmluaGVyaXR9c3VtbWFyeXtkaXNwbGF5Omxpc3QtaXRlbX1ibG9ja3F1b3RlLGRkLGRsLGZpZ3VyZSxoMSxoMixoMyxoNCxoNSxoNixocixwLHByZXttYXJnaW46MH1maWVsZHNldHttYXJnaW46MH1maWVsZHNldCxsZWdlbmR7cGFkZGluZzowfW1lbnUsb2wsdWx7bGlzdC1zdHlsZTpub25lO21hcmdpbjowO3BhZGRpbmc6MH1kaWFsb2d7cGFkZGluZzowfXRleHRhcmVhe3Jlc2l6ZTp2ZXJ0aWNhbH1pbnB1dDo6LW1vei1wbGFjZWhvbGRlcix0ZXh0YXJlYTo6LW1vei1wbGFjZWhvbGRlcntvcGFjaXR5OjE7Y29sb3I6IzljYTNhZn1pbnB1dDo6cGxhY2Vob2xkZXIsdGV4dGFyZWE6OnBsYWNlaG9sZGVye29wYWNpdHk6MTtjb2xvcjojOWNhM2FmfVtyb2xlPWJ1dHRvbl0sYnV0dG9ue2N1cnNvcjpwb2ludGVyfTpkaXNhYmxlZHtjdXJzb3I6ZGVmYXVsdH1hdWRpbyxjYW52YXMsZW1iZWQsaWZyYW1lLGltZyxvYmplY3Qsc3ZnLHZpZGVve2Rpc3BsYXk6YmxvY2s7dmVydGljYWwtYWxpZ246bWlkZGxlfWltZyx2aWRlb3ttYXgtd2lkdGg6MTAwJTtoZWlnaHQ6YXV0b31baGlkZGVuXTp3aGVyZSg6bm90KFtoaWRkZW49dW50aWwtZm91bmRdKSl7ZGlzcGxheTpub25lfWJvZHl7Zm9udC1mYW1pbHk6TWFucm9wZSxzYW5zLXNlcmlmfS5jb250YWluZXJ7d2lkdGg6MTAwJX1AbWVkaWEgKG1pbi13aWR0aDo2NDBweCl7LmNvbnRhaW5lcnttYXgtd2lkdGg6NjQwcHh9fUBtZWRpYSAobWluLXdpZHRoOjc2OHB4KXsuY29udGFpbmVye21heC13aWR0aDo3NjhweH19QG1lZGlhIChtaW4td2lkdGg6MTAyNHB4KXsuY29udGFpbmVye21heC13aWR0aDoxMDI0cHh9fUBtZWRpYSAobWluLXdpZHRoOjEyODBweCl7LmNvbnRhaW5lcnttYXgtd2lkdGg6MTI4MHB4fX1AbWVkaWEgKG1pbi13aWR0aDoxNTM2cHgpey5jb250YWluZXJ7bWF4LXdpZHRoOjE1MzZweH19LnBvc3QtY29udGVudCBwe21hcmdpbi10b3A6MXJlbTtmb250LXNpemU6MS4wOHJlbTtsaW5lLWhlaWdodDoxLjl9LnBvc3QtY29udGVudCBhe2NvbG9yOiM5MjQwMGU7dGV4dC1kZWNvcmF0aW9uOnVuZGVybGluZTt0ZXh0LWRlY29yYXRpb24tY29sb3I6cmdiYSgxNDYsNjQsMTQsLjQpO3RleHQtdW5kZXJsaW5lLW9mZnNldDozcHh9LmRhcmsgLnBvc3QtY29udGVudCBhe2NvbG9yOiNmYmJmMjQ7dGV4dC1kZWNvcmF0aW9uLWNvbG9yOnJnYmEoMjUxLDE5MSwzNiwuNDUpfS5wb3N0LWNvbnRlbnQgdWx7bWFyZ2luLXRvcDoxcmVtO2xpc3Qtc3R5bGU6ZGlzYztwYWRkaW5nLWxlZnQ6MS4zcmVtfS5wb3N0LWNvbnRlbnQgbGl7bWFyZ2luLXRvcDouNHJlbX0ucG9zdC1jb250ZW50IHRhYmxle3dpZHRoOjEwMCU7bWFyZ2luLXRvcDoxLjI1cmVtO2JvcmRlci1jb2xsYXBzZTpjb2xsYXBzZX0ucG9zdC1jb250ZW50IHRkLC5wb3N0LWNvbnRlbnQgdGh7Ym9yZGVyOjFweCBzb2xpZCAjZDZkM2QxO3BhZGRpbmc6LjZyZW0gLjdyZW19LnBvc3QtY29udGVudCB0aHtiYWNrZ3JvdW5kOiNmNWY1ZjQ7dGV4dC1hbGlnbjpsZWZ0fS5kYXJrIC5wb3N0LWNvbnRlbnQgdGQsLmRhcmsgLnBvc3QtY29udGVudCB0aHtib3JkZXItY29sb3I6IzU3NTM0ZX0uZGFyayAucG9zdC1jb250ZW50IHRoe2JhY2tncm91bmQ6IzI5MjUyNH0ucG9zdC1jb250ZW50IGNvZGU6bm90KHByZSBjb2RlKXtiYWNrZ3JvdW5kOiNlN2U1ZTQ7Ym9yZGVyLXJhZGl1czouMzVyZW07cGFkZGluZzouMTJyZW0gLjM0cmVtO2ZvbnQtZmFtaWx5OkpldEJyYWlucyBNb25vLG1vbm9zcGFjZTtmb250LXNpemU6LjllbX0uZGFyayAucG9zdC1jb250ZW50IGNvZGU6bm90KHByZSBjb2RlKXtiYWNrZ3JvdW5kOiM0NDQwM2N9LnBvc3QtY29udGVudCBwcmV7bWFyZ2luLXRvcDoxLjJyZW07Ym9yZGVyOjFweCBzb2xpZCByZ2JhKDY4LDY0LDYwLC4yOCl9LnBvc3QtY29udGVudCAubWVybWFpZHttYXJnaW4tdG9wOjEuMnJlbTtib3JkZXItcmFkaXVzOi43NXJlbTtib3JkZXI6MXB4IHNvbGlkICNkNmQzZDE7YmFja2dyb3VuZDpoc2xhKDYwLDklLDk4JSwuOCk7cGFkZGluZzoxcmVtO292ZXJmbG93LXg6YXV0b30uZGFyayAucG9zdC1jb250ZW50IHByZXtib3JkZXItY29sb3I6aHNsYSgyNSw1JSw0NSUsLjQ1KX0uZGFyayAucG9zdC1jb250ZW50IC5tZXJtYWlke2JvcmRlci1jb2xvcjojNTc1MzRlO2JhY2tncm91bmQ6cmdiYSgyOCwyNSwyMywuNzUpfS5wb3N0LWNvbnRlbnQgYmxvY2txdW90ZXttYXJnaW4tdG9wOjEuMnJlbTtib3JkZXItbGVmdDozcHggc29saWQgcmdiYSgxNDYsNjQsMTQsLjcpO3BhZGRpbmctbGVmdDoxcmVtO2NvbG9yOiM0NDQwM2N9LmRhcmsgLnBvc3QtY29udGVudCBibG9ja3F1b3Rle2JvcmRlci1sZWZ0LWNvbG9yOnJnYmEoMjUxLDE5MSwzNiwuNik7Y29sb3I6I2Q2ZDNkMX0uYWxlcnR7bWFyZ2luLXRvcDoxLjJyZW07Ym9yZGVyLXJhZGl1czouNzVyZW07Ym9yZGVyOjFweCBzb2xpZCAjZDZkM2QxO2JhY2tncm91bmQ6aHNsYSg2MCw1JSw5NiUsLjc1KTtwYWRkaW5nOi44NXJlbSAuOTVyZW19LmRhcmsgLmFsZXJ0e2JvcmRlci1jb2xvcjojNTc1MzRlO2JhY2tncm91bmQ6cmdiYSg0MSwzNywzNiwuNyl9LmFsZXJ0LXRpdGxle21hcmdpbjowO2ZvbnQtc2l6ZTouNzJyZW07bGV0dGVyLXNwYWNpbmc6LjEyZW07dGV4dC10cmFuc2Zvcm06dXBwZXJjYXNlO2ZvbnQtd2VpZ2h0OjcwMDtjb2xvcjojNzgzNTBmfS5hbGVydD5wOmxhc3QtY2hpbGR7bWFyZ2luLXRvcDouNXJlbX0uZGFyayAuc2hpa2l7Ym9yZGVyLWNvbG9yOmhzbGEoMjUsNSUsNDUlLC40NSl9LnBvaW50ZXItZXZlbnRzLW5vbmV7cG9pbnRlci1ldmVudHM6bm9uZX0uc3RhdGlje3Bvc2l0aW9uOnN0YXRpY30uZml4ZWR7cG9zaXRpb246Zml4ZWR9LnJlbGF0aXZle3Bvc2l0aW9uOnJlbGF0aXZlfS5pbnNldC0we2luc2V0OjB9Li16LTEwe3otaW5kZXg6LTEwfS5teC1hdXRve21hcmdpbi1sZWZ0OmF1dG87bWFyZ2luLXJpZ2h0OmF1dG99Lm1iLTEye21hcmdpbi1ib3R0b206M3JlbX0ubXQtMXttYXJnaW4tdG9wOi4yNXJlbX0ubXQtMTB7bWFyZ2luLXRvcDoyLjVyZW19Lm10LTJ7bWFyZ2luLXRvcDouNXJlbX0ubXQtM3ttYXJnaW4tdG9wOi43NXJlbX0ubXQtNHttYXJnaW4tdG9wOjFyZW19Lm10LTV7bWFyZ2luLXRvcDoxLjI1cmVtfS5tdC02e21hcmdpbi10b3A6MS41cmVtfS5tdC03e21hcmdpbi10b3A6MS43NXJlbX0ubXQtOHttYXJnaW4tdG9wOjJyZW19LmJsb2Nre2Rpc3BsYXk6YmxvY2t9LmlubGluZXtkaXNwbGF5OmlubGluZX0uZmxleHtkaXNwbGF5OmZsZXh9LmlubGluZS1mbGV4e2Rpc3BsYXk6aW5saW5lLWZsZXh9LnRhYmxle2Rpc3BsYXk6dGFibGV9LmdyaWR7ZGlzcGxheTpncmlkfS5oaWRkZW57ZGlzcGxheTpub25lfS5oLWF1dG97aGVpZ2h0OmF1dG99LnctZnVsbHt3aWR0aDoxMDAlfS5tYXgtdy0yeGx7bWF4LXdpZHRoOjQycmVtfS5tYXgtdy0zeGx7bWF4LXdpZHRoOjQ4cmVtfS5tYXgtdy01eGx7bWF4LXdpZHRoOjY0cmVtfS5mbGV4LXdyYXB7ZmxleC13cmFwOndyYXB9Lml0ZW1zLWNlbnRlcnthbGlnbi1pdGVtczpjZW50ZXJ9Lmp1c3RpZnktYmV0d2VlbntqdXN0aWZ5LWNvbnRlbnQ6c3BhY2UtYmV0d2Vlbn0uZ2FwLTJ7Z2FwOi41cmVtfS5nYXAtM3tnYXA6Ljc1cmVtfS5nYXAtNHtnYXA6MXJlbX0uZ2FwLTV7Z2FwOjEuMjVyZW19Lm92ZXJmbG93LWhpZGRlbntvdmVyZmxvdzpoaWRkZW59LnJvdW5kZWQtMnhse2JvcmRlci1yYWRpdXM6MXJlbX0ucm91bmRlZC1mdWxse2JvcmRlci1yYWRpdXM6OTk5OXB4fS5yb3VuZGVkLXhse2JvcmRlci1yYWRpdXM6Ljc1cmVtfS5ib3JkZXJ7Ym9yZGVyLXdpZHRoOjFweH0uYm9yZGVyLWJ7Ym9yZGVyLWJvdHRvbS13aWR0aDoxcHh9LmJvcmRlci1hbWJlci03MDB7LS10dy1ib3JkZXItb3BhY2l0eToxO2JvcmRlci1jb2xvcjpyZ2IoMTgwIDgzIDkvdmFyKC0tdHctYm9yZGVyLW9wYWNpdHksMSkpfS5ib3JkZXItc3RvbmUtMzAwey0tdHctYm9yZGVyLW9wYWNpdHk6MTtib3JkZXItY29sb3I6cmdiKDIxNCAyMTEgMjA5L3ZhcigtLXR3LWJvcmRlci1vcGFjaXR5LDEpKX0uYm9yZGVyLXN0b25lLTMwMFwvNzB7Ym9yZGVyLWNvbG9yOmhzbGEoMjQsNiUsODMlLC43KX0uYm9yZGVyLXN0b25lLTMwMFwvODB7Ym9yZGVyLWNvbG9yOmhzbGEoMjQsNiUsODMlLC44KX0uYm9yZGVyLXN0b25lLTQwMFwvNTB7Ym9yZGVyLWNvbG9yOmhzbGEoMjQsNSUsNjQlLC41KX0uYm9yZGVyLXN0b25lLTQwMFwvNzB7Ym9yZGVyLWNvbG9yOmhzbGEoMjQsNSUsNjQlLC43KX0uYmctYW1iZXItMTAwey0tdHctYmctb3BhY2l0eToxO2JhY2tncm91bmQtY29sb3I6cmdiKDI1NCAyNDMgMTk5L3ZhcigtLXR3LWJnLW9wYWNpdHksMSkpfS5iZy1zdG9uZS01MFwvNjB7YmFja2dyb3VuZC1jb2xvcjpoc2xhKDYwLDklLDk4JSwuNil9LmJnLXN0b25lLTUwXC83MHtiYWNrZ3JvdW5kLWNvbG9yOmhzbGEoNjAsOSUsOTglLC43KX0uYmctd2hpdGVcLzgwe2JhY2tncm91bmQtY29sb3I6aHNsYSgwLDAlLDEwMCUsLjgpfS5iZy1cW3JhZGlhbC1ncmFkaWVudFwoY2lyY2xlX2F0XzIwXCVfMTBcJVwyYyByZ2JhXCgyNDVcMmMgMTU4XDJjIDExXDJjIDBcLjEzXClcMmMgdHJhbnNwYXJlbnRfNDhcJVwpXDJjIHJhZGlhbC1ncmFkaWVudFwoY2lyY2xlX2F0XzgwXCVfMFwlXDJjIHJnYmFcKDI4XDJjIDI1XDJjIDIzXDJjIDBcLjA4XClcMmMgdHJhbnNwYXJlbnRfMzVcJVwpXDJjIGxpbmVhci1ncmFkaWVudFwodG9fYm90dG9tXDJjIFwjZmFmN2YyXDJjIFwjZjRlZmU3XClcXXtiYWNrZ3JvdW5kLWltYWdlOnJhZGlhbC1ncmFkaWVudChjaXJjbGUgYXQgMjAlIDEwJSxyZ2JhKDI0NSwxNTgsMTEsLjEzKSx0cmFuc3BhcmVudCA0OCUpLHJhZGlhbC1ncmFkaWVudChjaXJjbGUgYXQgODAlIDAscmdiYSgyOCwyNSwyMywuMDgpLHRyYW5zcGFyZW50IDM1JSksbGluZWFyLWdyYWRpZW50KDE4MGRlZywjZmFmN2YyLCNmNGVmZTcpfS5vYmplY3QtY292ZXJ7LW8tb2JqZWN0LWZpdDpjb3ZlcjtvYmplY3QtZml0OmNvdmVyfS5wLTR7cGFkZGluZzoxcmVtfS5wLTZ7cGFkZGluZzoxLjVyZW19LnB4LTJcLjV7cGFkZGluZy1sZWZ0Oi42MjVyZW07cGFkZGluZy1yaWdodDouNjI1cmVtfS5weC0ze3BhZGRpbmctbGVmdDouNzVyZW07cGFkZGluZy1yaWdodDouNzVyZW19LnB4LTR7cGFkZGluZy1sZWZ0OjFyZW07cGFkZGluZy1yaWdodDoxcmVtfS5weC02e3BhZGRpbmctbGVmdDoxLjVyZW07cGFkZGluZy1yaWdodDoxLjVyZW19LnB5LTF7cGFkZGluZy10b3A6LjI1cmVtO3BhZGRpbmctYm90dG9tOi4yNXJlbX0ucHktM3twYWRkaW5nLXRvcDouNzVyZW07cGFkZGluZy1ib3R0b206Ljc1cmVtfS5wYi0xNntwYWRkaW5nLWJvdHRvbTo0cmVtfS5wYi0yMHtwYWRkaW5nLWJvdHRvbTo1cmVtfS5wYi02e3BhZGRpbmctYm90dG9tOjEuNXJlbX0ucGItOHtwYWRkaW5nLWJvdHRvbToycmVtfS5wdC0xMHtwYWRkaW5nLXRvcDoyLjVyZW19LnB0LTEye3BhZGRpbmctdG9wOjNyZW19LmZvbnQtZGlzcGxheXtmb250LWZhbWlseTpGcmF1bmNlcyxzZXJpZn0udGV4dC0yeGx7Zm9udC1zaXplOjEuNXJlbTtsaW5lLWhlaWdodDoycmVtfS50ZXh0LTR4bHtmb250LXNpemU6Mi4yNXJlbTtsaW5lLWhlaWdodDoyLjVyZW19LnRleHQtXFsxMXB4XF17Zm9udC1zaXplOjExcHh9LnRleHQtYmFzZXtmb250LXNpemU6MXJlbTtsaW5lLWhlaWdodDoxLjVyZW19LnRleHQtc217Zm9udC1zaXplOi44NzVyZW07bGluZS1oZWlnaHQ6MS4yNXJlbX0udGV4dC14bHtmb250LXNpemU6MS4yNXJlbTtsaW5lLWhlaWdodDoxLjc1cmVtfS50ZXh0LXhze2ZvbnQtc2l6ZTouNzVyZW07bGluZS1oZWlnaHQ6MXJlbX0uZm9udC1tZWRpdW17Zm9udC13ZWlnaHQ6NTAwfS51cHBlcmNhc2V7dGV4dC10cmFuc2Zvcm06dXBwZXJjYXNlfS5sZWFkaW5nLVxbMVwuMDVcXXtsaW5lLWhlaWdodDoxLjA1fS5sZWFkaW5nLXJlbGF4ZWR7bGluZS1oZWlnaHQ6MS42MjV9LmxlYWRpbmctdGlnaHR7bGluZS1oZWlnaHQ6MS4yNX0udHJhY2tpbmctXFswXC4xMmVtXF17bGV0dGVyLXNwYWNpbmc6LjEyZW19LnRyYWNraW5nLVxbMFwuMTRlbVxde2xldHRlci1zcGFjaW5nOi4xNGVtfS50cmFja2luZy1cWzBcLjE2ZW1cXXtsZXR0ZXItc3BhY2luZzouMTZlbX0udHJhY2tpbmctXFswXC4xOGVtXF17bGV0dGVyLXNwYWNpbmc6LjE4ZW19LnRyYWNraW5nLVxbMFwuMjJlbVxde2xldHRlci1zcGFjaW5nOi4yMmVtfS50cmFja2luZy1cWzBcLjI4ZW1cXXtsZXR0ZXItc3BhY2luZzouMjhlbX0udGV4dC1hbWJlci04MDB7LS10dy10ZXh0LW9wYWNpdHk6MTtjb2xvcjpyZ2IoMTQ2IDY0IDE0L3ZhcigtLXR3LXRleHQtb3BhY2l0eSwxKSl9LnRleHQtYW1iZXItOTAwey0tdHctdGV4dC1vcGFjaXR5OjE7Y29sb3I6cmdiKDEyMCA1MyAxNS92YXIoLS10dy10ZXh0LW9wYWNpdHksMSkpfS50ZXh0LXN0b25lLTUwMHstLXR3LXRleHQtb3BhY2l0eToxO2NvbG9yOnJnYigxMjAgMTEzIDEwOC92YXIoLS10dy10ZXh0LW9wYWNpdHksMSkpfS50ZXh0LXN0b25lLTYwMHstLXR3LXRleHQtb3BhY2l0eToxO2NvbG9yOnJnYig4NyA4MyA3OC92YXIoLS10dy10ZXh0LW9wYWNpdHksMSkpfS50ZXh0LXN0b25lLTcwMHstLXR3LXRleHQtb3BhY2l0eToxO2NvbG9yOnJnYig2OCA2NCA2MC92YXIoLS10dy10ZXh0LW9wYWNpdHksMSkpfS50ZXh0LXN0b25lLTgwMHstLXR3LXRleHQtb3BhY2l0eToxO2NvbG9yOnJnYig0MSAzNyAzNi92YXIoLS10dy10ZXh0LW9wYWNpdHksMSkpfS50ZXh0LXN0b25lLTkwMHstLXR3LXRleHQtb3BhY2l0eToxO2NvbG9yOnJnYigyOCAyNSAyMy92YXIoLS10dy10ZXh0LW9wYWNpdHksMSkpfS51bmRlcmxpbmV7dGV4dC1kZWNvcmF0aW9uLWxpbmU6dW5kZXJsaW5lfS5kZWNvcmF0aW9uLWFtYmVyLTcwMFwvNDB7dGV4dC1kZWNvcmF0aW9uLWNvbG9yOnJnYmEoMTgwLDgzLDksLjQpfS51bmRlcmxpbmUtb2Zmc2V0LTR7dGV4dC11bmRlcmxpbmUtb2Zmc2V0OjRweH0uYW50aWFsaWFzZWR7LXdlYmtpdC1mb250LXNtb290aGluZzphbnRpYWxpYXNlZDstbW96LW9zeC1mb250LXNtb290aGluZzpncmF5c2NhbGV9LnNoYWRvdy1cWzBfMTBweF80MHB4Xy0yMnB4X3JnYmFcKDI4XDJjIDI1XDJjIDIzXDJjIDBcLjQ1XClcXXstLXR3LXNoYWRvdzowIDEwcHggNDBweCAtMjJweCByZ2JhKDI4LDI1LDIzLC40NSk7LS10dy1zaGFkb3ctY29sb3JlZDowIDEwcHggNDBweCAtMjJweCB2YXIoLS10dy1zaGFkb3ctY29sb3IpO2JveC1zaGFkb3c6dmFyKC0tdHctcmluZy1vZmZzZXQtc2hhZG93LDAgMCAjMDAwMCksdmFyKC0tdHctcmluZy1zaGFkb3csMCAwICMwMDAwKSx2YXIoLS10dy1zaGFkb3cpfS5zaGFkb3ctXFswXzE0cHhfNDhweF8tMjhweF9yZ2JhXCgyOFwyYyAyNVwyYyAyM1wyYyAwXC42XClcXXstLXR3LXNoYWRvdzowIDE0cHggNDhweCAtMjhweCByZ2JhKDI4LDI1LDIzLC42KTstLXR3LXNoYWRvdy1jb2xvcmVkOjAgMTRweCA0OHB4IC0yOHB4IHZhcigtLXR3LXNoYWRvdy1jb2xvcil9LnNoYWRvdy1cWzBfMTRweF80OHB4Xy0yOHB4X3JnYmFcKDI4XDJjIDI1XDJjIDIzXDJjIDBcLjZcKVxdLC5zaGFkb3ctc217Ym94LXNoYWRvdzp2YXIoLS10dy1yaW5nLW9mZnNldC1zaGFkb3csMCAwICMwMDAwKSx2YXIoLS10dy1yaW5nLXNoYWRvdywwIDAgIzAwMDApLHZhcigtLXR3LXNoYWRvdyl9LnNoYWRvdy1zbXstLXR3LXNoYWRvdzowIDFweCAycHggMCByZ2JhKDAsMCwwLC4wNSk7LS10dy1zaGFkb3ctY29sb3JlZDowIDFweCAycHggMCB2YXIoLS10dy1zaGFkb3ctY29sb3IpfS5vdXRsaW5lLW5vbmV7b3V0bGluZToycHggc29saWQgdHJhbnNwYXJlbnQ7b3V0bGluZS1vZmZzZXQ6MnB4fS5maWx0ZXJ7ZmlsdGVyOnZhcigtLXR3LWJsdXIpIHZhcigtLXR3LWJyaWdodG5lc3MpIHZhcigtLXR3LWNvbnRyYXN0KSB2YXIoLS10dy1ncmF5c2NhbGUpIHZhcigtLXR3LWh1ZS1yb3RhdGUpIHZhcigtLXR3LWludmVydCkgdmFyKC0tdHctc2F0dXJhdGUpIHZhcigtLXR3LXNlcGlhKSB2YXIoLS10dy1kcm9wLXNoYWRvdyl9LnRyYW5zaXRpb257dHJhbnNpdGlvbi1wcm9wZXJ0eTpjb2xvcixiYWNrZ3JvdW5kLWNvbG9yLGJvcmRlci1jb2xvcix0ZXh0LWRlY29yYXRpb24tY29sb3IsZmlsbCxzdHJva2Usb3BhY2l0eSxib3gtc2hhZG93LHRyYW5zZm9ybSxmaWx0ZXIsLXdlYmtpdC1iYWNrZHJvcC1maWx0ZXI7dHJhbnNpdGlvbi1wcm9wZXJ0eTpjb2xvcixiYWNrZ3JvdW5kLWNvbG9yLGJvcmRlci1jb2xvcix0ZXh0LWRlY29yYXRpb24tY29sb3IsZmlsbCxzdHJva2Usb3BhY2l0eSxib3gtc2hhZG93LHRyYW5zZm9ybSxmaWx0ZXIsYmFja2Ryb3AtZmlsdGVyO3RyYW5zaXRpb24tcHJvcGVydHk6Y29sb3IsYmFja2dyb3VuZC1jb2xvcixib3JkZXItY29sb3IsdGV4dC1kZWNvcmF0aW9uLWNvbG9yLGZpbGwsc3Ryb2tlLG9wYWNpdHksYm94LXNoYWRvdyx0cmFuc2Zvcm0sZmlsdGVyLGJhY2tkcm9wLWZpbHRlciwtd2Via2l0LWJhY2tkcm9wLWZpbHRlcjt0cmFuc2l0aW9uLXRpbWluZy1mdW5jdGlvbjpjdWJpYy1iZXppZXIoLjQsMCwuMiwxKTt0cmFuc2l0aW9uLWR1cmF0aW9uOi4xNXN9LnBsYWNlaG9sZGVyXDp0ZXh0LXN0b25lLTUwMDo6LW1vei1wbGFjZWhvbGRlcnstLXR3LXRleHQtb3BhY2l0eToxO2NvbG9yOnJnYigxMjAgMTEzIDEwOC92YXIoLS10dy10ZXh0LW9wYWNpdHksMSkpfS5wbGFjZWhvbGRlclw6dGV4dC1zdG9uZS01MDA6OnBsYWNlaG9sZGVyey0tdHctdGV4dC1vcGFjaXR5OjE7Y29sb3I6cmdiKDEyMCAxMTMgMTA4L3ZhcigtLXR3LXRleHQtb3BhY2l0eSwxKSl9LmhvdmVyXDotdHJhbnNsYXRlLXktMFwuNTpob3ZlcnstLXR3LXRyYW5zbGF0ZS15Oi0wLjEyNXJlbTt0cmFuc2Zvcm06dHJhbnNsYXRlKHZhcigtLXR3LXRyYW5zbGF0ZS14KSx2YXIoLS10dy10cmFuc2xhdGUteSkpIHJvdGF0ZSh2YXIoLS10dy1yb3RhdGUpKSBza2V3WCh2YXIoLS10dy1za2V3LXgpKSBza2V3WSh2YXIoLS10dy1za2V3LXkpKSBzY2FsZVgodmFyKC0tdHctc2NhbGUteCkpIHNjYWxlWSh2YXIoLS10dy1zY2FsZS15KSl9LmhvdmVyXDpib3JkZXItYW1iZXItNjAwOmhvdmVyey0tdHctYm9yZGVyLW9wYWNpdHk6MTtib3JkZXItY29sb3I6cmdiKDIxNyAxMTkgNi92YXIoLS10dy1ib3JkZXItb3BhY2l0eSwxKSl9LmhvdmVyXDpib3JkZXItYW1iZXItNzAwXC80MDpob3Zlcntib3JkZXItY29sb3I6cmdiYSgxODAsODMsOSwuNCl9LmhvdmVyXDpib3JkZXItYW1iZXItNzAwXC81MDpob3Zlcntib3JkZXItY29sb3I6cmdiYSgxODAsODMsOSwuNSl9LmhvdmVyXDpib3JkZXItYW1iZXItNzAwXC82MDpob3Zlcntib3JkZXItY29sb3I6cmdiYSgxODAsODMsOSwuNil9LmhvdmVyXDp0ZXh0LWFtYmVyLTgwMDpob3ZlcnstLXR3LXRleHQtb3BhY2l0eToxO2NvbG9yOnJnYigxNDYgNjQgMTQvdmFyKC0tdHctdGV4dC1vcGFjaXR5LDEpKX0uaG92ZXJcOnRleHQtYW1iZXItOTAwOmhvdmVyey0tdHctdGV4dC1vcGFjaXR5OjE7Y29sb3I6cmdiKDEyMCA1MyAxNS92YXIoLS10dy10ZXh0LW9wYWNpdHksMSkpfS5ob3Zlclw6c2hhZG93LVxbMF8xOHB4XzUwcHhfLTI0cHhfcmdiYVwoMTQ2XDJjIDY0XDJjIDE0XDJjIDBcLjM1XClcXTpob3ZlcnstLXR3LXNoYWRvdzowIDE4cHggNTBweCAtMjRweCByZ2JhKDE0Niw2NCwxNCwuMzUpOy0tdHctc2hhZG93LWNvbG9yZWQ6MCAxOHB4IDUwcHggLTI0cHggdmFyKC0tdHctc2hhZG93LWNvbG9yKTtib3gtc2hhZG93OnZhcigtLXR3LXJpbmctb2Zmc2V0LXNoYWRvdywwIDAgIzAwMDApLHZhcigtLXR3LXJpbmctc2hhZG93LDAgMCAjMDAwMCksdmFyKC0tdHctc2hhZG93KX0uZm9jdXNcOmJvcmRlci1hbWJlci03MDBcLzYwOmZvY3Vze2JvcmRlci1jb2xvcjpyZ2JhKDE4MCw4Myw5LC42KX0uZm9jdXNcOnJpbmctMjpmb2N1c3stLXR3LXJpbmctb2Zmc2V0LXNoYWRvdzp2YXIoLS10dy1yaW5nLWluc2V0KSAwIDAgMCB2YXIoLS10dy1yaW5nLW9mZnNldC13aWR0aCkgdmFyKC0tdHctcmluZy1vZmZzZXQtY29sb3IpOy0tdHctcmluZy1zaGFkb3c6dmFyKC0tdHctcmluZy1pbnNldCkgMCAwIDAgY2FsYygycHggKyB2YXIoLS10dy1yaW5nLW9mZnNldC13aWR0aCkpIHZhcigtLXR3LXJpbmctY29sb3IpO2JveC1zaGFkb3c6dmFyKC0tdHctcmluZy1vZmZzZXQtc2hhZG93KSx2YXIoLS10dy1yaW5nLXNoYWRvdyksdmFyKC0tdHctc2hhZG93LDAgMCAjMDAwMCl9LmZvY3VzXDpyaW5nLWFtYmVyLTcwMFwvMjA6Zm9jdXN7LS10dy1yaW5nLWNvbG9yOnJnYmEoMTgwLDgzLDksLjIpfS5ncm91cDpob3ZlciAuZ3JvdXAtaG92ZXJcOnVuZGVybGluZXt0ZXh0LWRlY29yYXRpb24tbGluZTp1bmRlcmxpbmV9LmRhcmtcOmJvcmRlci1hbWJlci0zMDA6aXMoLmRhcmsgKil7LS10dy1ib3JkZXItb3BhY2l0eToxO2JvcmRlci1jb2xvcjpyZ2IoMjUyIDIxMSA3Ny92YXIoLS10dy1ib3JkZXItb3BhY2l0eSwxKSl9LmRhcmtcOmJvcmRlci1zdG9uZS02MDA6aXMoLmRhcmsgKil7LS10dy1ib3JkZXItb3BhY2l0eToxO2JvcmRlci1jb2xvcjpyZ2IoODcgODMgNzgvdmFyKC0tdHctYm9yZGVyLW9wYWNpdHksMSkpfS5kYXJrXDpib3JkZXItc3RvbmUtNzAwOmlzKC5kYXJrICopey0tdHctYm9yZGVyLW9wYWNpdHk6MTtib3JkZXItY29sb3I6cmdiKDY4IDY0IDYwL3ZhcigtLXR3LWJvcmRlci1vcGFjaXR5LDEpKX0uZGFya1w6Ym9yZGVyLXN0b25lLTcwMFwvNzA6aXMoLmRhcmsgKil7Ym9yZGVyLWNvbG9yOnJnYmEoNjgsNjQsNjAsLjcpfS5kYXJrXDpib3JkZXItc3RvbmUtNzAwXC84MDppcyguZGFyayAqKXtib3JkZXItY29sb3I6cmdiYSg2OCw2NCw2MCwuOCl9LmRhcmtcOmJnLWFtYmVyLTMwMFwvMTU6aXMoLmRhcmsgKil7YmFja2dyb3VuZC1jb2xvcjpyZ2JhKDI1MiwyMTEsNzcsLjE1KX0uZGFya1w6Ymctc3RvbmUtOTAwXC81NTppcyguZGFyayAqKXtiYWNrZ3JvdW5kLWNvbG9yOnJnYmEoMjgsMjUsMjMsLjU1KX0uZGFya1w6Ymctc3RvbmUtOTAwXC82NTppcyguZGFyayAqKXtiYWNrZ3JvdW5kLWNvbG9yOnJnYmEoMjgsMjUsMjMsLjY1KX0uZGFya1w6Ymctc3RvbmUtOTAwXC84MDppcyguZGFyayAqKXtiYWNrZ3JvdW5kLWNvbG9yOnJnYmEoMjgsMjUsMjMsLjgpfS5kYXJrXDpiZy1zdG9uZS05NTA6aXMoLmRhcmsgKil7LS10dy1iZy1vcGFjaXR5OjE7YmFja2dyb3VuZC1jb2xvcjpyZ2IoMTIgMTAgOS92YXIoLS10dy1iZy1vcGFjaXR5LDEpKX0uZGFya1w6YmctXFtyYWRpYWwtZ3JhZGllbnRcKGNpcmNsZV9hdF8yMFwlXzEwXCVcMmMgcmdiYVwoMjQ1XDJjIDE1OFwyYyAxMVwyYyAwXC4wOFwpXDJjIHRyYW5zcGFyZW50XzQyXCVcKVwyYyByYWRpYWwtZ3JhZGllbnRcKGNpcmNsZV9hdF83NVwlXzBcJVwyYyByZ2JhXCgyNTBcMmMgMjUwXDJjIDI0OVwyYyAwXC4wNlwpXDJjIHRyYW5zcGFyZW50XzI4XCVcKVwyYyBsaW5lYXItZ3JhZGllbnRcKHRvX2JvdHRvbVwyYyBcIzExMTMxNVwyYyBcIzBhMGIwZFwpXF06aXMoLmRhcmsgKil7YmFja2dyb3VuZC1pbWFnZTpyYWRpYWwtZ3JhZGllbnQoY2lyY2xlIGF0IDIwJSAxMCUscmdiYSgyNDUsMTU4LDExLC4wOCksdHJhbnNwYXJlbnQgNDIlKSxyYWRpYWwtZ3JhZGllbnQoY2lyY2xlIGF0IDc1JSAwLGhzbGEoNjAsOSUsOTglLC4wNiksdHJhbnNwYXJlbnQgMjglKSxsaW5lYXItZ3JhZGllbnQoMTgwZGVnLCMxMTEzMTUsIzBhMGIwZCl9LmRhcmtcOnRleHQtYW1iZXItMjAwOmlzKC5kYXJrICopey0tdHctdGV4dC1vcGFjaXR5OjE7Y29sb3I6cmdiKDI1MyAyMzAgMTM4L3ZhcigtLXR3LXRleHQtb3BhY2l0eSwxKSl9LmRhcmtcOnRleHQtYW1iZXItMzAwOmlzKC5kYXJrICopey0tdHctdGV4dC1vcGFjaXR5OjE7Y29sb3I6cmdiKDI1MiAyMTEgNzcvdmFyKC0tdHctdGV4dC1vcGFjaXR5LDEpKX0uZGFya1w6dGV4dC1zdG9uZS0xMDA6aXMoLmRhcmsgKil7LS10dy10ZXh0LW9wYWNpdHk6MTtjb2xvcjpyZ2IoMjQ1IDI0NSAyNDQvdmFyKC0tdHctdGV4dC1vcGFjaXR5LDEpKX0uZGFya1w6dGV4dC1zdG9uZS0yMDA6aXMoLmRhcmsgKil7LS10dy10ZXh0LW9wYWNpdHk6MTtjb2xvcjpyZ2IoMjMxIDIyOSAyMjgvdmFyKC0tdHctdGV4dC1vcGFjaXR5LDEpKX0uZGFya1w6dGV4dC1zdG9uZS0zMDA6aXMoLmRhcmsgKil7LS10dy10ZXh0LW9wYWNpdHk6MTtjb2xvcjpyZ2IoMjE0IDIxMSAyMDkvdmFyKC0tdHctdGV4dC1vcGFjaXR5LDEpKX0uZGFya1w6dGV4dC1zdG9uZS00MDA6aXMoLmRhcmsgKil7LS10dy10ZXh0LW9wYWNpdHk6MTtjb2xvcjpyZ2IoMTY4IDE2MiAxNTgvdmFyKC0tdHctdGV4dC1vcGFjaXR5LDEpKX0uZGFya1w6dGV4dC1zdG9uZS01MDppcyguZGFyayAqKXstLXR3LXRleHQtb3BhY2l0eToxO2NvbG9yOnJnYigyNTAgMjUwIDI0OS92YXIoLS10dy10ZXh0LW9wYWNpdHksMSkpfS5kYXJrXDpzaGFkb3ctXFswXzE2cHhfNDJweF8tMjhweF9yZ2JhXCgwXDJjIDBcMmMgMFwyYyAwXC44XClcXTppcyguZGFyayAqKXstLXR3LXNoYWRvdzowIDE2cHggNDJweCAtMjhweCByZ2JhKDAsMCwwLC44KTstLXR3LXNoYWRvdy1jb2xvcmVkOjAgMTZweCA0MnB4IC0yOHB4IHZhcigtLXR3LXNoYWRvdy1jb2xvcik7Ym94LXNoYWRvdzp2YXIoLS10dy1yaW5nLW9mZnNldC1zaGFkb3csMCAwICMwMDAwKSx2YXIoLS10dy1yaW5nLXNoYWRvdywwIDAgIzAwMDApLHZhcigtLXR3LXNoYWRvdyl9LmRhcmtcOnBsYWNlaG9sZGVyXDp0ZXh0LXN0b25lLTQwMDppcyguZGFyayAqKTo6LW1vei1wbGFjZWhvbGRlcnstLXR3LXRleHQtb3BhY2l0eToxO2NvbG9yOnJnYigxNjggMTYyIDE1OC92YXIoLS10dy10ZXh0LW9wYWNpdHksMSkpfS5kYXJrXDpwbGFjZWhvbGRlclw6dGV4dC1zdG9uZS00MDA6aXMoLmRhcmsgKik6OnBsYWNlaG9sZGVyey0tdHctdGV4dC1vcGFjaXR5OjE7Y29sb3I6cmdiKDE2OCAxNjIgMTU4L3ZhcigtLXR3LXRleHQtb3BhY2l0eSwxKSl9LmRhcmtcOmhvdmVyXDpib3JkZXItYW1iZXItMzAwOmhvdmVyOmlzKC5kYXJrICopey0tdHctYm9yZGVyLW9wYWNpdHk6MTtib3JkZXItY29sb3I6cmdiKDI1MiAyMTEgNzcvdmFyKC0tdHctYm9yZGVyLW9wYWNpdHksMSkpfS5kYXJrXDpob3Zlclw6dGV4dC1hbWJlci0yMDA6aG92ZXI6aXMoLmRhcmsgKil7LS10dy10ZXh0LW9wYWNpdHk6MTtjb2xvcjpyZ2IoMjUzIDIzMCAxMzgvdmFyKC0tdHctdGV4dC1vcGFjaXR5LDEpKX0uZGFya1w6Zm9jdXNcOmJvcmRlci1hbWJlci0zMDA6Zm9jdXM6aXMoLmRhcmsgKil7LS10dy1ib3JkZXItb3BhY2l0eToxO2JvcmRlci1jb2xvcjpyZ2IoMjUyIDIxMSA3Ny92YXIoLS10dy1ib3JkZXItb3BhY2l0eSwxKSl9LmRhcmtcOmZvY3VzXDpyaW5nLWFtYmVyLTMwMFwvMjA6Zm9jdXM6aXMoLmRhcmsgKil7LS10dy1yaW5nLWNvbG9yOnJnYmEoMjUyLDIxMSw3NywuMil9QG1lZGlhIChtaW4td2lkdGg6NzY4cHgpey5tZFw6Z3JpZC1jb2xzLTJ7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOnJlcGVhdCgyLG1pbm1heCgwLDFmcikpfS5tZFw6cHgtMTB7cGFkZGluZy1sZWZ0OjIuNXJlbTtwYWRkaW5nLXJpZ2h0OjIuNXJlbX0ubWRcOnB0LTE0e3BhZGRpbmctdG9wOjMuNXJlbX0ubWRcOnB0LTIwe3BhZGRpbmctdG9wOjVyZW19Lm1kXDp0ZXh0LTV4bHtmb250LXNpemU6M3JlbTtsaW5lLWhlaWdodDoxfS5tZFw6dGV4dC02eGx7Zm9udC1zaXplOjMuNzVyZW07bGluZS1oZWlnaHQ6MX0ubWRcOnRleHQtbGd7Zm9udC1zaXplOjEuMTI1cmVtO2xpbmUtaGVpZ2h0OjEuNzVyZW19fQ==")!
