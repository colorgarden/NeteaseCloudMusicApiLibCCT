// tools/dfpwm_encode.js
// Encode a raw 8-bit signed PCM stream (stdin) into DFPWM (stdout).
//
// The predictor below is a direct port of CC:Tweaked's cc.audio.dfpwm encoder,
// so the output decodes correctly with the computer's built-in decoder.
//
// Input : signed 8-bit PCM, mono, 48000 Hz (e.g. from
//         `ffmpeg -i song.mp3 -f s8 -ac 1 -ar 48000 -`).
// Output: DFPWM bytes.
//
// Usage: ffmpeg -v error -i <in> -f s8 -ac 1 -ar 48000 - | node dfpwm_encode.js > out.dfpwm
'use strict'

const PREC = 10
const PREC_POW = 1 << PREC // 1024
const PREC_POW_HALF = 1 << (PREC - 1) // 512
const STRENGTH_MIN = 1 << (PREC - 8 + 1) // 8

function makePredictor() {
  let charge = 0
  let strength = 0
  let previousBit = false

  return function predict(currentBit) {
    const target = currentBit ? 127 : -128

    let nextCharge = charge + Math.floor((strength * (target - charge) + PREC_POW_HALF) / PREC_POW)
    if (nextCharge === charge && nextCharge !== target) nextCharge += currentBit ? 1 : -1

    const z = currentBit === previousBit ? PREC_POW - 1 : 0
    let nextStrength = strength
    if (nextStrength !== z) nextStrength += currentBit === previousBit ? 1 : -1
    if (nextStrength < STRENGTH_MIN) nextStrength = STRENGTH_MIN

    charge = nextCharge
    strength = nextStrength
    previousBit = currentBit
    return charge
  }
}

const predict = makePredictor()
let previousCharge = 0
let carry = Buffer.alloc(0)

function encode(buf) {
  const out = Buffer.alloc(Math.ceil(buf.length / 8))
  let n = 0
  for (let i = 0; i < buf.length; i += 8) {
    let byte = 0
    for (let j = 0; j < 8; j++) {
      const raw = buf[i + j] || 0
      const sample = raw > 127 ? raw - 256 : raw // unsigned byte -> signed 8-bit
      const bit = sample > previousCharge || (sample === previousCharge && sample === 127)
      byte = Math.floor(byte / 2) + (bit ? 128 : 0)
      previousCharge = predict(bit)
    }
    out[n++] = byte
  }
  return out.subarray(0, n)
}

process.stdin.on('data', (chunk) => {
  const buf = Buffer.concat([carry, chunk])
  const aligned = buf.length - (buf.length % 8)
  if (aligned > 0) process.stdout.write(encode(buf.subarray(0, aligned)))
  carry = buf.subarray(aligned)
})

process.stdin.on('end', () => {
  if (carry.length > 0) process.stdout.write(encode(carry))
})
