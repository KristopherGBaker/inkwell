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
          const terms = query.split(/\s+/).filter(Boolean);
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
