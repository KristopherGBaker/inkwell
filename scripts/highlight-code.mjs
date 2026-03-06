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
