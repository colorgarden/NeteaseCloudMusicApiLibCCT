-- examples/verify_decode.lua
-- Decode a FLAC link (or a local .flac file) into a .dfpwm file, then play the
-- converted file back.
--
-- Why: streaming playback decodes the FLAC *while* it plays, so on a slow
-- computer the speaker starves and the audio stutters. Converting first takes
-- the playback speed out of the equation entirely, which makes this a clean
-- decoder test:
--
--   * converted file plays smoothly -> the decoder is fine; the machine simply
--     could not decode fast enough in real time.
--   * converted file is ALSO choppy -> the decode itself is at fault.
--
-- Usage (from the shell, ncm installed at /ncm):
--   wget run <url>/examples/verify_decode.lua <flac-url-or-local-path> [out.dfpwm]

package.path = "/?.lua;/?/init.lua;" .. package.path

local args = { ... }
local src = args[1]
local out = args[2] or "/decode_test.dfpwm"

if not src then
  print("usage: verify_decode <flac-url-or-local-path> [out.dfpwm]")
  return
end

local okReq, audio = pcall(require, "ncm.util.audio")
if not okReq then
  print("cannot load ncm.util.audio: " .. tostring(audio))
  return
end

print("Decoding")
print("  src: " .. src)
print("  out: " .. out)

local started = os.epoch("utc")
local lastDraw = 0

local samples, err = audio.decodeToDfpwm(src, out, {
  onProgress = function(total, dec)
    local now = os.epoch("utc")
    if now - lastDraw < 250 then return end -- keep terminal writes out of the loop
    lastDraw = now
    term.clearLine()
    term.write(("  %d samples = %.1f s of audio (source %d Hz, %d ch)")
      :format(total, total / 48000, dec.sampleRate, dec.channels))
  end,
})

term.clearLine()
if not samples then
  print("Decode failed: " .. tostring(err))
  return
end

local elapsed = (os.epoch("utc") - started) / 1000
local bytes = fs.getSize(out)
local audioSecs = samples / 48000

print(("Decoded %d samples (%.1f s of audio) in %.1f s (%.2fx real time)")
  :format(samples, audioSecs, elapsed, audioSecs / math.max(elapsed, 0.001)))
print(("DFPWM file: %s (%d bytes)"):format(out, bytes))
print("")
print("Playing the CONVERTED file now - no decoding happens during playback.")
print("Press Ctrl+T to stop.")
print("")

local played, playErr = audio.playFile(out, { volume = 1.0 })
if not played then
  print("Playback failed: " .. tostring(playErr))
else
  print(("Done: %.1f seconds played."):format(played / 48000))
end
