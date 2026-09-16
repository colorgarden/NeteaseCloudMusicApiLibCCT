-- ncm/cli.lua
-- A command-line NetEase Cloud Music client for CC:Tweaked.
--
-- This file lives inside the published `ncm/` bundle, so after installing the
-- library it is available at /ncm/cli.lua. Run it from the shell as:
--
--   ncm/cli
--
-- Features:
--   * QR-code login, rendered straight in the terminal, with the resulting
--     cookie persisted to /ncm_cookie and reloaded on the next start.
--   * Keyword search and pick-a-number playback.
--   * Play by song ID.
--   * Play a .dfpwm (built-in decoder, or the optional `speaker` program).
--
-- Playback is strictly local. FLAC direct links are stream-decoded on the
-- computer by ncm.util.audio; DFPWM is handled by the built-in decoder (or by
-- the `speaker` program, which plays DFPWM without transcoding). This program
-- never asks a remote service to transcode audio.
--
-- UI strings are ASCII only (CC's default font has no CJK glyphs). Song and
-- artist names coming back from the API may contain Chinese; they are data and
-- are printed as-is.

package.path = "/?.lua;/?/init.lua;" .. package.path

local ncm = require("ncm")
local qr = require("ncm.util.qrcode")
local lib = require("ncm.lib")

-- The `speaker` program (cc_speakerlib) is installed into the library's own
-- dependency directory. It looks for cc_big_http.lua next to itself, so it must
-- always be launched by its absolute path rather than via shell.resolveProgram
-- (which searches the current directory and could pick up the ROM's unrelated
-- `speaker` program instead).
local SPEAKER_PROGRAM = lib.dir .. "/speaker.lua"

local COOKIE_FILE = "/ncm_cookie"

-- ============================================================================
-- Terminal helpers
-- ============================================================================

local function restoreTerminal()
  term.setBackgroundColour(colours.black)
  term.setTextColour(colours.white)
  term.clear()
  term.setCursorPos(1, 1)
end

local function clearScreen()
  term.setBackgroundColour(colours.black)
  term.setTextColour(colours.white)
  term.clear()
  term.setCursorPos(1, 1)
end

-- Prompt for one (trimmed) line of input. `read` is only called with no
-- arguments: in CC its first argument is a replace-character, not a prompt.
local function prompt(label)
  write(label)
  local line = read()
  if type(line) ~= "string" then return "" end
  return (line:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function waitForEnter()
  write("Press Enter to continue...")
  read()
end

-- Turn a raised request answer (a table, see ncm.util.request) into a string.
local function errText(e)
  if type(e) == "table" then
    local body = e.body
    if type(body) == "table" and body.msg then return tostring(body.msg) end
    if e.message then return tostring(e.message) end
    return "request failed (status " .. tostring(e.status) .. ")"
  end
  return tostring(e)
end

-- ============================================================================
-- Cookie persistence
-- ============================================================================

local function loadCookieString()
  if not fs.exists(COOKIE_FILE) then return nil end
  local f = fs.open(COOKIE_FILE, "r")
  if not f then return nil end
  local data = f.readAll()
  f.close()
  if type(data) == "string" and data ~= "" then return data end
  return nil
end

local function saveCookieString(str)
  local f = fs.open(COOKIE_FILE, "w")
  if not f then return false end
  f.write(str)
  f.close()
  return true
end

local cookie = loadCookieString()

-- ============================================================================
-- Playback
-- ============================================================================

local function findSpeaker()
  if peripheral and peripheral.find then return peripheral.find("speaker") end
  return nil
end

-- Hand a link to the `speaker` program. For anything that is not DFPWM it asks
-- its configured transcode service (-server) for a DFPWM stream and plays that,
-- which costs the computer almost no CPU - the way to get smooth audio when
-- local decoding cannot keep up, and the only option for mp3/aac, which the
-- pure-Lua decoder cannot touch at all.
local function launchSpeakerProgram(url, note)
  if not fs.exists(SPEAKER_PROGRAM) then
    print("The speaker program is not installed (" .. SPEAKER_PROGRAM .. ").")
    return false
  end
  if note then print(note) end
  print("Handing the link to the speaker program (transcode service -> DFPWM)...")
  shell.run(SPEAKER_PROGRAM, url, "-id", "ncm_cli")
  return true
end

-- Fetch a lossless URL for `id` and play it: FLAC is decoded locally by the
-- pure-Lua decoder, anything else is handed to the speaker program, which can
-- have it transcoded to DFPWM remotely.
local function playSong(id, displayName)
  clearScreen()
  if displayName then print("Song: " .. tostring(displayName)) end
  print("Requesting a lossless (FLAC) URL...")

  local ok, res = pcall(ncm.song_url_v1, { id = id, level = "lossless", cookie = cookie })
  if not ok then
    print("Request failed: " .. errText(res))
    waitForEnter()
    return
  end

  local entry = res.body and res.body.data and res.body.data[1]
  local url = entry and entry.url
  if not url or url == "" then
    print("No playable URL. The song may be unavailable, or this account")
    print("has no lossless/VIP access.")
    waitForEnter()
    return
  end

  -- Prefer the API's own type field; fall back to the URL suffix.
  local kind = tostring(entry.type or ""):lower()
  local isFlac = kind == "flac" or tostring(url):lower():match("%.flac") ~= nil

  if not isFlac then
    launchSpeakerProgram(url,
      "This link is not FLAC (type=" .. (kind ~= "" and kind or "?") .. ").")
    waitForEnter()
    return
  end

  local speaker = findSpeaker()
  if not speaker then
    print("No speaker attached.")
    waitForEnter()
    return
  end

  local audio = require("ncm.util.audio")

  print("1/3 Downloading the whole stream ...")
  local flac, derr = audio.download(url, {
    onProgress = function(n)
      term.clearLine()
      term.write(("  %.2f MB"):format(n / 1048576))
    end,
  })
  print("")
  if not flac then
    print("Download failed: " .. tostring(derr))
    waitForEnter()
    return
  end

  print("2/3 Decoding (no deadline; this can take a while) ...")
  local dfpwm, samplesOrErr = audio.flacToDfpwm({ data = flac }, {
    onProgress = function(total, dec)
      term.clearLine()
      term.write(("  decoded %.0f s @ %d Hz"):format(total / 48000, dec.sampleRate))
    end,
  })
  print("")
  flac = nil -- release the FLAC copy before playback
  if not dfpwm then
    print("Decode failed: " .. tostring(samplesOrErr))
    waitForEnter()
    return
  end

  print("3/3 Playing (Ctrl+T to stop) ...")
  local samples, err = audio.playDfpwmData(dfpwm, { volume = 1.0, speaker = speaker })
  if not samples then
    print("Playback failed: " .. tostring(err))
  else
    print(("Done: %.1f seconds played."):format(samples / 48000))
  end
  waitForEnter()
end

local function doPlayById()
  clearScreen()
  local id = prompt("Song ID: ")
  if id == "" then return end
  playSong(tonumber(id) or id, nil)
end

-- Play a .dfpwm. The `speaker` program only accepts http(s) URLs, so it is used
-- for remote .dfpwm only; local files go through the built-in decoder.
local function doPlayDfpwm()
  clearScreen()
  print("DFPWM only. No remote transcoding is used.")
  local target = prompt("Path or URL to .dfpwm: ")
  if target == "" then return end

  local bare = target:lower():match("^([^?]*)") or target:lower()
  if not bare:match("%.dfpwm$") then
    print("Refused: the target must end in .dfpwm.")
    print("Pre-convert on a PC first: tools/audio_to_dfpwm.sh <url> song.dfpwm")
    waitForEnter()
    return
  end

  local speaker = findSpeaker()
  if not speaker then
    print("No speaker attached.")
    waitForEnter()
    return
  end

  local isUrl = target:match("^https?://") ~= nil
  if isUrl and fs.exists(SPEAKER_PROGRAM) then
    print("Launching the speaker program (DFPWM passthrough)...")
    shell.run(SPEAKER_PROGRAM, target, "-id", "ncm_cli")
    return
  end

  local audio = require("ncm.util.audio")
  print("Playing locally...")
  local count, err
  if isUrl then
    count, err = audio.playUrl(target, { volume = 1.0, speaker = speaker })
  else
    count, err = audio.playFile(target, { volume = 1.0, speaker = speaker })
  end
  if not count then
    print("Playback failed: " .. tostring(err))
  else
    print(("Done: %.1f seconds played."):format(count / 48000))
  end
  waitForEnter()
end

-- ============================================================================
-- Search
-- ============================================================================

local function doSearch()
  clearScreen()
  local keyword = prompt("Search keyword: ")
  if keyword == "" then return end

  print("Searching...")
  local ok, res = pcall(ncm.search, { keywords = keyword, type = 1, limit = 10, cookie = cookie })
  if not ok then
    print("Search failed: " .. errText(res))
    waitForEnter()
    return
  end

  local songs = (res.body and res.body.result and res.body.result.songs) or {}
  if #songs == 0 then
    print("No results for: " .. keyword)
    waitForEnter()
    return
  end

  clearScreen()
  print(("Results for '%s':"):format(keyword))
  for i, song in ipairs(songs) do
    local artist = "?"
    if song.artists and song.artists[1] and song.artists[1].name then
      artist = song.artists[1].name
    end
    print(("%2d. %s - %s"):format(i, tostring(song.name), tostring(artist)))
  end
  print("")

  local choice = prompt("Play number (Enter to cancel): ")
  local idx = tonumber(choice)
  if not idx or idx < 1 or idx > #songs then return end

  local song = songs[idx]
  local artist = (song.artists and song.artists[1] and song.artists[1].name) or "?"
  playSong(song.id, tostring(song.name) .. " - " .. tostring(artist))
end

-- ============================================================================
-- Login / account
-- ============================================================================

-- Render the login URL as a CC-font subpixel QR: one character cell carries a
-- 3x2 block of modules using CC:Tweaked's built-in 0x80-0x9F glyphs, so a
-- 33-module code (ECL L, 1-module quiet zone) becomes 17 columns x 12 rows.
-- That fits the default 51x19 terminal with a spare row, and unlike the
-- braille/half-block styles it does not depend on glyphs the CC font lacks.
-- Returns the row the caller should print status text at.
local function drawQr(qrurl)
  local w, h = term.getSize()
  local okEnc, code = pcall(qr.encode, qrurl, { ecl = "L" })
  if okEnc and type(code) == "table" and code.size then
    local cols = code.size + 2 -- one quiet-zone module on each side
    local rows = math.ceil(cols / 2)
    if cols <= w and rows <= h - 1 then
      local drawn = qr.printCC(qrurl, { border = 1, ecl = "L" })
      if drawn then return drawn end
      qr.draw(qrurl, { border = 1, ecl = "L" })
      return h
    end
  end
  print("QR too large for this terminal; open this URL with the app:")
  print(qrurl)
  print("")
  return h
end

local function doLogin()
  clearScreen()
  print("Requesting QR key...")
  local ok, res = pcall(ncm.login_qr_key, {})
  if not ok then
    print("Login failed: " .. errText(res))
    waitForEnter()
    return
  end
  local unikey = res.body and res.body.data and res.body.data.unikey
  if not unikey then
    print("No QR key returned by the server.")
    waitForEnter()
    return
  end

  local okCreate, created = pcall(ncm.login_qr_create, { key = unikey })
  if not okCreate then
    print("Could not create the QR: " .. errText(created))
    waitForEnter()
    return
  end
  local qrurl = created.body and created.body.data and created.body.data.qrurl
  if not qrurl then
    print("No QR URL returned by the server.")
    waitForEnter()
    return
  end

  clearScreen()
  local statusRow = drawQr(qrurl)

  local function say(msg)
    term.setCursorPos(1, statusRow)
    term.clearLine()
    term.write(msg)
  end
  say("Scan with the NetEase Cloud Music app. Waiting...")

  local last
  while true do
    sleep(1)
    local okCheck, s = pcall(ncm.login_qr_check, { key = unikey })
    if not okCheck then
      say("Network error, retrying...")
    else
      local code = s.body and s.body.code
      if code == 800 then
        clearScreen()
        print("QR expired. Please start over.")
        waitForEnter()
        return
      elseif code == 803 then
        local ck = s.body and s.body.cookie
        if (type(ck) ~= "string" or ck == "") and type(s.cookie) == "table" then
          ck = table.concat(s.cookie, "; ")
        end
        clearScreen()
        if type(ck) == "string" and ck ~= "" then
          cookie = ck
          if saveCookieString(ck) then
            print("Login successful. Cookie saved to " .. COOKIE_FILE)
          else
            print("Login successful, but the cookie could not be saved.")
          end
        else
          print("Login reported success but no cookie was returned.")
        end
        waitForEnter()
        return
      elseif code == 802 then
        if last ~= 802 then say("Scanned. Confirm on your phone...") end
      elseif code == 801 then
        if last ~= 801 then say("Waiting for scan...") end
      elseif code then
        say("Status code: " .. tostring(code))
      end
      last = code
    end
  end
end

local function doShowAccount()
  clearScreen()
  if not cookie then
    print("Not logged in (no saved cookie).")
  else
    local ok, res = pcall(ncm.user_account, { cookie = cookie })
    if not ok then
      print("Account check failed: " .. errText(res))
    else
      local profile = res.body and res.body.profile
      if profile and profile.nickname then
        print("Logged in as: " .. tostring(profile.nickname))
        if profile.userId then print("User ID: " .. tostring(profile.userId)) end
      else
        print("Cookie loaded, but the account could not be read (expired?).")
      end
    end
  end
  waitForEnter()
end

local function doLogout()
  clearScreen()
  if not cookie then
    print("Not logged in.")
  else
    local ok, res = pcall(ncm.logout, { cookie = cookie })
    if not ok then
      print("Server logout failed: " .. errText(res))
    else
      print("Logged out on the server.")
    end
    cookie = nil
    if fs.exists(COOKIE_FILE) then pcall(fs.delete, COOKIE_FILE) end
    print("Saved cookie cleared.")
  end
  waitForEnter()
end

-- ============================================================================
-- Menu
-- ============================================================================

local function main()
  while true do
    clearScreen()
    print("==========================================")
    print("  NetEase Cloud Music - CC:Tweaked client")
    print("==========================================")
    if cookie then
      print("Cookie: loaded (" .. COOKIE_FILE .. ")")
    else
      print("Cookie: not logged in")
    end
    print("")
    print("  1) Login (QR code)")
    print("  2) Search & Play")
    print("  3) Play by ID")
    print("  4) Play a .dfpwm")
    print("  5) Show account")
    print("  6) Logout")
    print("  7) Quit")
    print("")

    local choice = prompt("Choose: ")
    if choice == "1" then
      doLogin()
    elseif choice == "2" then
      doSearch()
    elseif choice == "3" then
      doPlayById()
    elseif choice == "4" then
      doPlayDfpwm()
    elseif choice == "5" then
      doShowAccount()
    elseif choice == "6" then
      doLogout()
    elseif choice == "7" or choice == "q" or choice == "Q" then
      return
    else
      print("Unknown choice: " .. choice)
      waitForEnter()
    end
  end
end

-- Ctrl+T (and any other error) unwinds through this pcall; the terminal is
-- always restored afterwards.
local ok, err = pcall(main)
restoreTerminal()
if not ok then
  local msg = tostring(err)
  if not msg:find("Terminated", 1, true) then
    print("Program error: " .. msg)
  end
end
