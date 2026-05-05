import katex from 'katex'

const encoded = process.argv[2] || ''

if (!encoded) {
  process.stdout.write('{}')
  process.exit(0)
}

let runs
try {
  runs = JSON.parse(Buffer.from(encoded, 'base64').toString('utf8'))
} catch {
  process.stdout.write('{}')
  process.exit(0)
}

if (!Array.isArray(runs)) {
  process.stdout.write('{}')
  process.exit(0)
}

const result = {}
for (const run of runs) {
  if (typeof run !== 'object' || run === null) continue
  const id = run.id
  const source = typeof run.source === 'string' ? run.source : ''
  const isBlock = run.isBlock === true
  if (id === undefined || id === null) continue
  try {
    result[String(id)] = katex.renderToString(source, {
      displayMode: isBlock,
      throwOnError: false,
      output: 'html',
      strict: false
    })
  } catch {
    // Skip on render failure; restitcher will fall back to raw source.
  }
}

process.stdout.write(JSON.stringify(result))
