-- Example: stream + decode a song's FLAC link and play it on a CC speaker.
-- Pure Lua, no external converter needed.
--
-- NetEase returns a FLAC link only for a lossless level and an eligible
-- (VIP) account, e.g. ncm.song_url_v1({ id = ..., level = "lossless" }).
--
-- Usage: play_song <songId>
local ncm = require("ncm")
local audio = require("ncm.util.audio")

local id = ...
if not id or id == "" then
  print("usage: play_song <songId>")
  return
end

local res = ncm.song_url_v1({ id = tonumber(id) or id, level = "lossless" })
local entry = res.body.data and res.body.data[1]
local url = entry and entry.url
if not url then
  print("no url (song unavailable, or account has no lossless access)")
  return
end

-- Pure-CC decode only understands FLAC. Other levels return mp3 (see README
-- for the DFPWM pre-conversion workflow).
if not tostring(url):lower():match("%.flac") then
  print("WARNING: this link is not FLAC; pure-CC decode only supports FLAC.")
  print("url: " .. tostring(url))
  return
end

if not peripheral.find("speaker") then
  print("no speaker attached")
  return
end

print("Streaming FLAC (decode-while-downloading): " .. url)
local samples, err = audio.playFlacUrl(url, { volume = 1.0 })
if not samples then
  print("error: " .. tostring(err))
else
  print(("done (%.1f seconds played)"):format(samples / 48000))
end
