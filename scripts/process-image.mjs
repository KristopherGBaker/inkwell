import sharp from 'sharp'
import { readFile } from 'node:fs/promises'
import { join, basename, extname } from 'node:path'

const [sourcePath, outDir, key, specJson] = process.argv.slice(2)

if (!sourcePath || !outDir || !key || !specJson) {
  process.stderr.write('usage: process-image.mjs <source> <out-dir> <key> <spec-json>\n')
  process.exit(2)
}

let spec
try {
  spec = JSON.parse(specJson)
} catch (e) {
  process.stderr.write(`bad spec json: ${e.message}\n`)
  process.exit(2)
}

const widths = spec.widths ?? [480, 800, 1200, 1600]
const formats = spec.formats ?? ['avif', 'webp']
const minBytes = spec.minBytes ?? 32768

function emit(payload) {
  process.stdout.write(JSON.stringify(payload))
}

function bypass(reason, metadata = {}) {
  emit({
    metadata: {
      width: metadata.width ?? 0,
      height: metadata.height ?? 0,
      format: metadata.format ?? extname(sourcePath).slice(1).toLowerCase(),
      bypassed: true,
      reason
    },
    variants: []
  })
  process.exit(0)
}

let buffer
try {
  buffer = await readFile(sourcePath)
} catch (e) {
  process.stderr.write(`read failed: ${e.message}\n`)
  process.exit(3)
}

const ext = extname(sourcePath).toLowerCase()
if (ext === '.svg' || ext === '.svgz') {
  bypass('svg', { format: 'svg' })
}

let metadata
try {
  metadata = await sharp(buffer, { animated: true }).metadata()
} catch (e) {
  process.stderr.write(`probe failed: ${e.message}\n`)
  process.exit(3)
}

if ((metadata.pages ?? 1) > 1) {
  bypass('animated', metadata)
}

if (buffer.length < minBytes) {
  bypass('small', metadata)
}

const intrinsicWidth = metadata.width ?? 0
const sourceFormat = metadata.format ?? 'jpeg'

// Cap requested widths at intrinsic. If any requested width was dropped,
// fall back to intrinsic so we still emit a "full quality" variant.
const droppedAny = widths.some((w) => w > intrinsicWidth)
let effectiveWidths = widths.filter((w) => w <= intrinsicWidth)
if (droppedAny && intrinsicWidth > 0 && !effectiveWidths.includes(intrinsicWidth)) {
  effectiveWidths.push(intrinsicWidth)
}
effectiveWidths = [...new Set(effectiveWidths)].sort((a, b) => a - b)

const variants = []
for (const width of effectiveWidths) {
  for (const fmt of formats) {
    const filename = `${key}-${width}.${fmt}`
    const outPath = join(outDir, filename)
    const pipeline = sharp(buffer).resize({ width })
    if (fmt === 'avif') {
      await pipeline.avif().toFile(outPath)
    } else if (fmt === 'webp') {
      await pipeline.webp().toFile(outPath)
    } else if (fmt === 'jpeg' || fmt === 'jpg') {
      await pipeline.jpeg().toFile(outPath)
    } else if (fmt === 'png') {
      await pipeline.png().toFile(outPath)
    } else {
      await pipeline.toFormat(sourceFormat).toFile(outPath)
    }
    variants.push({ width, format: fmt, filename })
  }
}

emit({
  metadata: {
    width: intrinsicWidth,
    height: metadata.height ?? 0,
    format: sourceFormat,
    bypassed: false,
    reason: null
  },
  variants
})
