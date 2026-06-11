# Code highlighting

Inkwell always emits fenced code blocks with `language-*` classes, and the bundled themes include a small client-side highlighter for common languages. That path works from any released Inkwell install with no project setup.

## Build-time highlighting with Shiki

For higher fidelity, Inkwell can highlight code at build time with [Shiki](https://shiki.style/). Build-time Shiki is optional and silent-fallback: if Node, the script, or `shiki` is unavailable, the generated site still builds and the theme's client-side highlighter colors the code in the browser.

To enable build-time Shiki in a site project:

1. Install Node.js 20 or newer.
2. Add Shiki to the site project:

   ```bash
   npm install --save-dev shiki
   ```

3. Add `scripts/highlight-code.mjs` to the site project:

   ```js
   import { codeToHtml } from 'shiki'

   const language = process.argv[2] || 'text'
   const encoded = process.argv[3] || ''

   if (!encoded) {
     process.stdout.write('')
     process.exit(0)
   }

   const code = Buffer.from(encoded, 'base64').toString('utf8')

   try {
     const html = await codeToHtml(code, {
       lang: language,
       theme: 'github-dark-default'
     })
     process.stdout.write(html)
   } catch {
     process.stdout.write('')
     process.exit(0)
   }
   ```

4. Run `inkwell build` from the site project root.

When running Inkwell from a local source checkout, `npm ci` in the Inkwell repo also enables the bundled `scripts/highlight-code.mjs` path for local development and tests.
