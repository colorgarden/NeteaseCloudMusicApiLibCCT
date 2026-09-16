-- Example: play a DFPWM file through a CC:Tweaked speaker.
--
-- Compressed music (mp3/flac/aac) CANNOT be decoded on the computer. Convert a
-- NetEase direct link on a PC first, then host the produced .dfpwm:
--
--   tools/audio_to_dfpwm.sh "<direct url>" song.dfpwm
--
-- Usage on the computer:  play_music <url-or-path-to.dfpwm>
local audio = require("ncm.util.audio")

local target = ...
if not target or target == "" then
  print("usage: play_music <url-or-path-to.dfpwm>")
  return
end
if not peripheral.find("speaker") then
  print("no speaker attached")
  return
end

print("Playing: " .. target)
local isUrl = target:match("^https?://") ~= nil
local frames, err
if isUrl then
  frames, err = audio.playUrl(target, { volume = 1.0 })
else
  frames, err = audio.playFile(target, { volume = 1.0 })
end

if not frames then
  print("error: " .. tostring(err))
else
  print(("done (%.1f seconds)"):format(frames / 48000))
end
