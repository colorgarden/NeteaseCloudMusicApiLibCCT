// tools/build_dist.js
// Builds dist/ncm.tar — an uncompressed USTAR archive of ncm/ — plus its
// sha256. The CC installer streams this straight off HTTP into the filesystem,
// so it never needs a gzip library nor a temporary file.
//
// Usage: node tools/build_dist.js
'use strict'
const fs = require('fs')
const path = require('path')
const crypto = require('crypto')

const ROOT = '/data/data/com.termux/files/home/netease-ncm-lua'
const SRC = path.join(ROOT, 'ncm')
const OUT = path.join(ROOT, 'dist')

function walk(dir, base, out) {
  for (const name of fs.readdirSync(dir).sort()) {
    const full = path.join(dir, name)
    const rel = base + '/' + name
    const st = fs.statSync(full)
    if (st.isDirectory()) walk(full, rel, out)
    else out.push({ rel, data: fs.readFileSync(full), mode: st.mode & 0o777, mtime: Math.floor(st.mtimeMs / 1000) })
  }
}

function oct(value, len) {
  return value.toString(8).padStart(len - 1, '0') + '\0'
}

function header(name, size, mtime, mode) {
  let nm = name
  let prefix = ''
  if (Buffer.byteLength(nm, 'utf8') > 100) {
    const idx = nm.lastIndexOf('/', 155)
    if (idx > 0) {
      prefix = nm.slice(0, idx)
      nm = nm.slice(idx + 1)
    }
  }
  const h = Buffer.alloc(512)
  h.write(nm, 0, 100, 'utf8')
  h.write(oct(mode, 8), 100, 8, 'ascii')
  h.write(oct(0, 8), 108, 8, 'ascii')
  h.write(oct(0, 8), 116, 8, 'ascii')
  h.write(oct(size, 12), 124, 12, 'ascii')
  h.write(oct(mtime, 12), 136, 12, 'ascii')
  h.write('        ', 148, 8, 'ascii') // checksum placeholder
  h.write('0', 156, 1, 'ascii') // regular file
  h.write('ustar', 257, 5, 'ascii')
  h.write('\0', 262, 1, 'ascii')
  h.write('00', 263, 2, 'ascii')
  h.write(prefix, 345, 155, 'utf8')
  let sum = 0
  for (const b of h) sum += b
  h.write(sum.toString(8).padStart(6, '0') + '\0 ', 148, 8, 'ascii')
  return h
}

function pad512(buf) {
  const r = buf.length % 512
  return r ? Buffer.concat([buf, Buffer.alloc(512 - r)]) : buf
}

fs.mkdirSync(OUT, { recursive: true })
const files = []
walk(SRC, 'ncm', files)

const chunks = []
for (const f of files) {
  chunks.push(header(f.rel, f.data.length, f.mtime, f.mode))
  chunks.push(pad512(f.data))
}
chunks.push(Buffer.alloc(1024)) // two zero blocks

const tar = Buffer.concat(chunks)
fs.writeFileSync(path.join(OUT, 'ncm.tar'), tar)
const sha = crypto.createHash('sha256').update(tar).digest('hex')
fs.writeFileSync(path.join(OUT, 'ncm.tar.sha256'), sha + '  ncm.tar\n')
console.log(`wrote dist/ncm.tar: ${tar.length} bytes, ${files.length} files, sha256 ${sha}`)
