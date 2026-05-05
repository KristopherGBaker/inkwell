import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'

const [specB64] = process.argv.slice(2)
if (!specB64) {
  process.stderr.write('usage: render-og.mjs <base64-spec>\n')
  process.exit(2)
}

let spec
try {
  spec = JSON.parse(Buffer.from(specB64, 'base64').toString('utf8'))
} catch (err) {
  process.stderr.write(`bad spec: ${err.message}\n`)
  process.exit(2)
}

const { template, data, fontPaths, outputPath, width, height, background } = spec
if (!template || !outputPath) {
  process.stderr.write('spec needs template + outputPath\n')
  process.exit(2)
}

let fontData = null
for (const path of fontPaths || []) {
  try {
    if (existsSync(path)) {
      fontData = readFileSync(path)
      break
    }
  } catch (_) { /* probe next */ }
}

if (!fontData) {
  process.stderr.write('no usable font found among candidate paths\n')
  process.exit(3)
}

let satori, Resvg
try {
  satori = (await import('satori')).default
  Resvg = (await import('@resvg/resvg-js')).Resvg
} catch (err) {
  process.stderr.write(`missing deps: ${err.message}\n`)
  process.exit(3)
}

function substitute(node, ctx) {
  if (typeof node === 'string') {
    return node.replace(/\{\{(\w+)\}\}/g, (_, key) => (ctx[key] ?? ''))
  }
  if (Array.isArray(node)) return node.map((child) => substitute(child, ctx))
  if (node && typeof node === 'object') {
    const out = {}
    for (const [key, value] of Object.entries(node)) {
      out[key] = substitute(value, ctx)
    }
    return out
  }
  return node
}

const element = substitute(template, data || {})

const svg = await satori(element, {
  width: width ?? 1200,
  height: height ?? 630,
  fonts: [
    { name: 'Inkwell OG', data: fontData, weight: 400, style: 'normal' }
  ]
})

const resvg = new Resvg(svg, {
  background: background ?? '#0d1117',
  fitTo: { mode: 'width', value: width ?? 1200 }
})
const png = resvg.render().asPng()

mkdirSync(dirname(outputPath), { recursive: true })
writeFileSync(outputPath, png)
process.stdout.write(outputPath)
