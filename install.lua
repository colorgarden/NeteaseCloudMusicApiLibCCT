--[[
  install.lua - one-click installer for the CC:Tweaked port of
  NeteaseCloudMusicApi (library name: `ncm`).

  What it does
    1. removes any previous install (ncm/, plus the root-level dependency
       files written by older versions of this installer),
    2. downloads cc_big_http (the library's runtime dependency for large GETs),
    3. downloads dist/ncm.tar fully into memory, measures what it needs, then
       extracts it (uncompressed USTAR - no gzip library or temp file needed),
    4. downloads the aeslua-cc dependency,
    5. downloads cc_speakerlib, the speaker program `ncm/cli` uses for .dfpwm passthrough and
       mp3/aac remote transcoding,
    6. verifies the bundle it extracted is current, and prints a usage hint.

  Everything the installer fetches is small (a few hundred KB at most, far
  below the ~16 MiB single-response cap), so it uses plain http GETs. The
  library itself routes its large audio GETs through cc_big_http at runtime.

  Failure reporting
    Every step prints a start line before it runs. Every fatal path goes
    through failStep(), which prints WHAT step failed, WHICH url/path it
    involved, the EXACT error text (including any HTTP status the response
    carried) and WHAT to try, then aborts. Mirrors are tried in turn and a
    failure prints that mirror's url, its reason and "trying the next
    mirror"; when every mirror fails one block lists each url and its error.

  Layout
    Everything lives inside one deletable tree; no files are scattered in the
    root directory:

      /ncm/                 the library itself (require("ncm"))
      /ncm/lib/aeslua.lua   aeslua-cc        (LGPL)
      /ncm/lib/aeslua/      aeslua-cc modules
      /ncm/lib/cc_big_http.lua  chunked GET helper   (GPL-2.0)
      /ncm/lib/speaker.lua      cc_speakerlib        (MPL-2.0)

    ncm/lib.lua tells `require` about /ncm/lib, and cc_speakerlib finds
    cc_big_http.lua in that same directory.

  Requirements
    * An Advanced Computer (or Command Computer) with the HTTP API enabled.
    * The server must allow the github.com / raw.githubusercontent.com host
      (and cdn.jsdelivr.net) in its http whitelist, plus git.liulikeji.cn for
      the cc_big_http and cc_speakerlib downloads.
    * cc_big_http concatenates all chunks into one Lua string, so peak memory
      equals the whole response size; raise computerSpaceLimit above the
      largest file you intend to fetch (e.g. 64 MB on CraftOS-PC).

  Usage
    wget run https://cdn.jsdelivr.net/gh/colorgarden/NeteaseCloudMusicApiLibCCT@main/install.lua
    -- or, with a custom base URL for the library bundle:
    wget run <url> https://my.mirror/ncm

  Everything is installed under `/` by default so that a program in the default
  shell directory can `require("ncm")`.
]]

local CONFIG = {
  -- Where the library bundle (dist/ncm.tar) is served from.
  base = "https://cdn.jsdelivr.net/gh/colorgarden/NeteaseCloudMusicApiLibCCT@main",
  -- Where ncm/ and aeslua/ are installed (must end with "/").
  root = "/",
  -- aeslua-cc dependency (pure-Lua AES primitives).
  aeslua = "https://cdn.jsdelivr.net/gh/AngusAU293/aeslua-cc@0.2.1-CC/src",
  -- cc_big_http HARD dependency (GPL-2.0). Fixed upstream URL: it is not part
  -- of our this project's bundle, so the library mirror selection below never
  -- affects it. It is downloaded with the plain http API first (bootstrap),
  -- then used for every other GET. The server's http_whitelist must include
  -- git.liulikeji.cn or this download fails.
  ccBigHttp = "https://git.liulikeji.cn/xingluo/cc_big_http/raw/branch/main/cc_big_http.lua",
  -- cc_speakerlib, installed as /speaker.lua. Its own SPDX header declares
  -- MPL-2.0 (the upstream repo ships no LICENSE file). Like cc_big_http it is
  -- NOT bundled with this project and is fetched from its fixed upstream
  -- URL. It is the `speaker` program `ncm/cli` launches for local .dfpwm
  -- passthrough, and it auto-detects /cc_big_http.lua next to itself.
  speakerlib = "https://git.liulikeji.cn/xingluo/cc_speakerlib/raw/branch/main/speakerlib.lua",
}

local args = { ... }

-- ------------------------------------------------------------------- log file
-- Every line this installer prints is also appended, one line at a time, to a
-- log file on the computer's internal disk. Writing it immediately (rather than
-- buffering and dumping at the end) means that if the machine runs out of
-- memory mid-install, everything up to the last completed line is already on
-- disk and can be read back after the screen has scrolled away.
--
-- Opening is best-effort: a read-only or absent disk must not stop the install,
-- so a failure only prints one warning and turns logging off.
local LOG_PATH = "/ncm-install.log"
local logFile
do
  local ok, f = pcall(fs.open, LOG_PATH, "a")
  if ok and f ~= nil then
    logFile = f
  else
    print("warning: cannot write " .. LOG_PATH .. "; continuing without a log file")
  end
end

-- The single place every screen line goes through: print it, then append the
-- exact same text to the log. A failed append disables logging instead of
-- aborting. `print` is used (not write) so the installer's own output is
-- unchanged.
local function emit(text)
  local s = tostring(text)
  print(s)
  if logFile then
    local ok = pcall(function() logFile.write(s .. "\n") end)
    if not ok then logFile = nil end
  end
end

-- One header line per run so several runs in the same appended file are easy to
-- tell apart. UTC and ASCII only.
local function runHeader()
  local stamp = "?"
  local okd, d = pcall(os.date, "!%Y-%m-%dT%H:%M:%SZ")
  if okd and type(d) == "string" then stamp = d end
  local id = "?"
  local okc, c = pcall(os.getComputerID)
  if okc then id = tostring(c) end
  local argv = {}
  for i = 1, #args do argv[i] = tostring(args[i]) end
  emit(("=== run %s args=%s computer=%s ==="):format(
    stamp, #argv > 0 and table.concat(argv, " ") or "(none)", id))
end

runHeader()

-- --------------------------------------------------------------- failure report
-- One structured reporter for every fatal path. The block is ASCII-only and
-- delimited so it is easy to spot and easy to copy out of the terminal.
local REPORT_WIDTH = 66

-- Print `prefix` followed by `text`, word-wrapped so continuation lines line
-- up under the text column. ASCII only: the separator and every label here
-- are plain characters.
local function reportFill(prefix, text)
  local line = prefix
  local started = false
  for word in tostring(text):gmatch("%S+") do
    if not started then
      line = line .. word
      started = true
    elseif #line + 1 + #word <= REPORT_WIDTH then
      line = line .. " " .. word
    else
      emit(line)
      line = string.rep(" ", #prefix) .. word
    end
  end
  if started then emit(line) end
end

-- Turn an http.get failure into a reason string. http.get returns
-- `nil, err, failingResponse`; when the third value is present its
-- getResponseCode()/getResponseMessage() carry the HTTP status and message.
local function httpReason(err, response)
  local reason = tostring(err)
  if type(response) == "table" then
    local code, message
    if type(response.getResponseCode) == "function" then
      local ok, c = pcall(response.getResponseCode)
      if ok then code = c end
    end
    if type(response.getResponseMessage) == "function" then
      local ok, m = pcall(response.getResponseMessage)
      if ok then message = m end
    end
    if code ~= nil or message ~= nil then
      reason = reason .. " (HTTP " .. tostring(code or "?")
        .. (message ~= nil and (" " .. tostring(message)) or "") .. ")"
    end
  end
  return reason
end

-- Read the status off a live response handle. A mirror may answer with a
-- non-nil handle and an error status; that must be reported too.
local function responseStatus(handle)
  if type(handle) ~= "table" or type(handle.getResponseCode) ~= "function" then
    return nil, nil
  end
  local ok, code = pcall(handle.getResponseCode)
  if not ok or type(code) ~= "number" then return nil, nil end
  local message
  if type(handle.getResponseMessage) == "function" then
    local okm, m = pcall(handle.getResponseMessage)
    if okm then message = m end
  end
  return code, message
end

-- The single fatal reporter. `details` is an optional array of extra lines
-- (used to list every failed mirror). Aborts with the reason text, level 0 so
-- no Lua traceback is printed.
local function failStep(step, source, reason, hint, details)
  emit(string.rep("-", REPORT_WIDTH))
  emit("INSTALL FAILED")
  emit("  step   : " .. tostring(step))
  if source and source ~= "" then emit("  source : " .. tostring(source)) end
  reportFill("  reason : ", reason)
  if details then
    for _, d in ipairs(details) do reportFill("           ", d) end
  end
  if hint and hint ~= "" then reportFill("  try    : ", hint) end
  emit(string.rep("-", REPORT_WIDTH))
  -- The exact text error() is about to raise, so the log ends with it too.
  emit(tostring(reason))
  if logFile then emit("log written to " .. LOG_PATH) end
  error(tostring(reason), 0)
end

-- Each discrete step prints one start line before it runs.
local function stepStart(name)
  emit("Step: " .. name)
end

-- Report that every mirror failed, listing each url and its own error.
local function mirrorFailure(step, what, errors)
  local details = {}
  for i, e in ipairs(errors) do
    details[#details + 1] = ("mirror %d: %s"):format(i, e.url)
    details[#details + 1] = ("error: %s"):format(e.reason)
  end
  failStep(step, "all mirrors for " .. what,
    ("could not obtain %s from any of the %d mirrors"):format(what, #errors),
    "check the computer's network and http whitelist, then retry; the source menu lists each host",
    details)
end

-- --------------------------------------------------------------- source pick
-- The library (this repo) and the aeslua-cc dependency are mirrored together.
local MIRRORS = {
  {
    name = "jsDelivr (recommended)",
    lib = "https://cdn.jsdelivr.net/gh/colorgarden/NeteaseCloudMusicApiLibCCT@main",
    aes = "https://cdn.jsdelivr.net/gh/AngusAU293/aeslua-cc@0.2.1-CC/src",
  },
  {
    name = "GitHub raw",
    lib = "https://raw.githubusercontent.com/colorgarden/NeteaseCloudMusicApiLibCCT/main",
    aes = "https://raw.githubusercontent.com/AngusAU293/aeslua-cc/0.2.1-CC/src",
  },
  {
    name = "ghproxy.net (GitHub proxy)",
    lib = "https://ghproxy.net/https://raw.githubusercontent.com/colorgarden/NeteaseCloudMusicApiLibCCT/main",
    aes = "https://ghproxy.net/https://raw.githubusercontent.com/AngusAU293/aeslua-cc/0.2.1-CC/src",
  },
}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Reads one line; returns "" when the input stream is closed (non-interactive).
local function ask(prompt)
  if prompt then write(prompt) end
  local ans = read and read() or nil
  if ans == nil then return "" end
  return trim(ans)
end

-- Interactive menu unless base URLs were given on the command line:
--   install.lua [libBaseUrl] [aesluaBaseUrl]
local function pickSource()
  if args[1] and args[1] ~= "" then
    CONFIG.base = args[1]:gsub("/+$", "")
    if args[2] and args[2] ~= "" then CONFIG.aeslua = args[2]:gsub("/+$", "") end
    emit("Using command-line source: " .. CONFIG.base)
    return
  end

  stepStart("select download source")
  emit("Choose a download source:")
  for i, m in ipairs(MIRRORS) do emit(("  %d) %s"):format(i, m.name)) end
  emit(("  %d) Custom URL"):format(#MIRRORS + 1))

  local n = tonumber(ask("Select [1]: ")) or 1
  if n >= 1 and n <= #MIRRORS then
    CONFIG.base = MIRRORS[n].lib
    CONFIG.aeslua = MIRRORS[n].aes
    emit("Selected: " .. MIRRORS[n].name)
  elseif n == #MIRRORS + 1 then
    local u = ask("Library base URL (the dir containing dist/ncm.tar): ")
    if u ~= "" then CONFIG.base = u:gsub("/+$", "") end
    local a = ask("aeslua dependency URL [default jsDelivr]: ")
    if a ~= "" then CONFIG.aeslua = a:gsub("/+$", "") end
    emit("Using custom source")
  else
    CONFIG.base = MIRRORS[1].lib
    CONFIG.aeslua = MIRRORS[1].aes
    emit("Invalid input, using default: " .. MIRRORS[1].name)
  end
  emit("Selected base URL: " .. CONFIG.base)
  emit("Selected aeslua URL: " .. CONFIG.aeslua)
end

stepStart("read config and arguments")
local pickOk, pickErr = pcall(pickSource)
if not pickOk then
  failStep("read config and arguments", "argv",
    tostring(pickErr),
    "pass a valid base URL as the first argument, or run without arguments for the menu")
end

-- ----------------------------------------------------------------- utilities
local function log(fmt, ...)
  if select("#", ...) > 0 then emit(fmt:format(...)) else emit(fmt) end
end

-- Byte-count sanity: when the response carried Content-Length, the received
-- byte count must match it. When it did not, say so rather than staying
-- silent so the operator knows the download was unverifiable.
local function noteByteCount(got, total)
  if total and total > 0 then
    log("  received %d bytes (Content-Length: %d)", got, total)
  else
    log("  received %d bytes (no Content-Length header)", got)
  end
end

local function byteMismatch(got, total)
  if total and total > 0 and got ~= total then
    return ("expected %d bytes, received %d"):format(total, got)
  end
  return nil
end

-- CC's fs API prepends "file:line: " to errors it raises; keep only the
-- filesystem's own message so the reported error is about the actual problem.
local function fsErrorText(err)
  return (tostring(err):gsub("^.-:%d+:%s*", "", 1))
end

local function mkdirp(dir)
  local parts = {}
  for seg in dir:gmatch("[^/]+") do parts[#parts + 1] = seg end
  local cur = dir:sub(1, 1) == "/" and "" or "."
  for i = 1, #parts do
    cur = cur .. "/" .. parts[i]
    if not fs.exists(cur) then fs.makeDir(cur) end
  end
end

local function dirname(p)
  return p:match("^(.*)/[^/]*$") or "."
end

local function rmrf(p)
  if not fs.exists(p) then return end
  if fs.isDir(p) then
    for _, f in ipairs(fs.list(p)) do rmrf(fs.combine(p, f)) end
    fs.delete(p)
  else
    fs.delete(p)
  end
end

-- ------------------------------------------------------------------ progress
-- One-line ASCII progress bar, redrawn in place on its own row.
--
-- Every write is clamped to width-1 columns: writing the bottom-right cell of
-- a terminal scrolls it, which would scroll the bar off the screen. On CC each
-- terminal write is expensive, so a redraw is throttled to PROGRESS_INTERVAL ms
-- (the first frame of a new label and the final 100% frame are always drawn).
local PROGRESS_INTERVAL = 250
local PROGRESS_BAR = 18

local lastDraw, lastLabel, progressRow = 0, nil, nil

local function humanBytes(n)
  if n >= 1024 * 1024 then return ("%.2f MB"):format(n / (1024 * 1024)) end
  if n >= 1024 then return ("%.2f KB"):format(n / 1024) end
  return tostring(n) .. " B"
end

-- label : "Download" / "Extract". total nil or 0 drops the bar and percentage
-- and prints just the label and detail (e.g. "Download 53.21 KB").
local function drawProgress(label, done, total, detail)
  local now = os.epoch("utc")
  local pct
  if total and total > 0 then
    pct = math.floor(done * 100 / total)
    if pct > 100 then pct = 100 end
  end
  local final = pct ~= nil and pct >= 100
  if label == lastLabel and not final and now - lastDraw < PROGRESS_INTERVAL then
    return false
  end
  if label ~= lastLabel then
    -- A new phase takes over the row the cursor is on now and keeps drawing
    -- there, so a bar never marches down the screen.
    progressRow = select(2, term.getCursorPos())
    lastLabel = label
    lastDraw = 0
  end
  lastDraw = now

  local text
  if pct then
    local filled = math.floor(pct * PROGRESS_BAR / 100)
    if filled > PROGRESS_BAR then filled = PROGRESS_BAR end
    local bar = string.rep("#", filled) .. string.rep("-", PROGRESS_BAR - filled)
    text = ("%-8s [%s] %3d%%  %s"):format(label, bar, pct, detail or "")
  else
    text = ("%s %s"):format(label, detail or "")
  end

  local w = select(1, term.getSize())
  if #text > w - 1 then text = text:sub(1, w - 1) end
  term.setCursorPos(1, progressRow)
  term.clearLine()
  write(text)
  return final == true
end

-- Erase the bar before normal output so no log line is glued to it, leaving
-- the cursor on the bar's own row for the next print.
local function finishProgress()
  if progressRow then
    -- Keep the completed bar on screen (a fast connection throttles the
    -- intermediate frames away) and move past it so the next log line does
    -- not overwrite it from column 1.
    local _, h = term.getSize()
    term.setCursorPos(1, math.min(progressRow + 1, h))
  end
  lastDraw, lastLabel, progressRow = 0, nil, nil
end

-- content-length from the response headers, matched case-insensitively. nil
-- when the server did not send one (the bar then shows the byte count only and
-- the completion line says the download was not verifiable).
local function contentLength(handle)
  if type(handle.getResponseHeaders) ~= "function" then return nil end
  local ok, headers = pcall(handle.getResponseHeaders)
  if not ok or type(headers) ~= "table" then return nil end
  for key, value in pairs(headers) do
    if type(key) == "string" and key:lower() == "content-length" then
      local n = tonumber(value)
      if n and n > 0 then return n end
    end
  end
  return nil
end

-- Read a single-response body in chunks, drawing the download bar as it
-- arrives, and return the whole body, the received byte count and the
-- advertised Content-Length (nil when the server sent none). CC:Tweaked's
-- read(n) blocks until n bytes or EOF and returns nil at EOF, so the bar
-- follows the network. CraftOS-PC's read(n) is a non-blocking readsome() that
-- can return "" once it has drained its buffer; the first empty read falls
-- back to readAll() (which blocks until the rest is buffered) so the installer
-- still terminates with the whole archive.
local DOWNLOAD_CHUNK = 32768

local function readBodyProgress(handle, label)
  local total = contentLength(handle)
  local out, got, drewFinal = {}, 0, false
  local function detail(n)
    if total and total > 0 then return humanBytes(n) end
    return humanBytes(n) .. " (no Content-Length)"
  end
  if type(handle.read) == "function" then
    while true do
      local chunk = handle.read(DOWNLOAD_CHUNK)
      if chunk == nil then break end
      if #chunk == 0 then
        if type(handle.readAll) == "function" then
          local rest = handle.readAll() or ""
          if #rest > 0 then
            out[#out + 1] = rest
            got = got + #rest
            drewFinal = drawProgress(label, got, total, detail(got))
          end
        end
        break
      end
      out[#out + 1] = chunk
      got = got + #chunk
      drewFinal = drawProgress(label, got, total, detail(got))
    end
  end
  if got == 0 and type(handle.readAll) == "function" then
    local body = handle.readAll() or ""
    if #body > 0 then
      drawProgress(label, #body, total, detail(#body))
      return body, #body, total
    end
  end
  if total and total > 0 and got >= total and not drewFinal then
    -- Guarantee a clean 100% frame even if the last draws were throttled.
    drawProgress(label, total, total, detail(total))
  elseif not drewFinal then
    -- A truncated body: draw the real byte count so the bar never claims 100%
    -- for a short read. The byte-count check reports the mismatch right after.
    lastDraw = 0
    drawProgress(label, got, total, detail(got))
  end
  return table.concat(out), got, total
end

-- Plain single-response GET via the built-in http API, with a few retries.
--
-- Two uses:
--   1. bootstrapping cc_big_http.lua, which cannot download itself through
--      itself;
--   2. falling back when a chunked GET is impossible. Some CDNs (jsDelivr)
--      force gzip even though cc_big_http sends `Accept-Encoding: identity`,
--      and CraftOS then transparently decompresses the body, which makes the
--      HTTP byte ranges meaningless. cc_big_http correctly rejects such a
--      response ("Invalid chunk size for bytes=...") and there is no way to
--      detect it from the outside. Every fallback target here (the bundle,
--      the aeslua-cc files, speakerlib) is far below the 16 MiB single-
--      response cap, so a plain GET is safe for them.
--
-- Returns `handle` on success, or `nil, err, failingResponse` so the caller
-- can report the HTTP status the response carried.
local function plainGet(url)
  if not http then
    return nil, "the HTTP API is unavailable (use an Advanced Computer and enable http)"
  end
  local lastErr, lastResp
  for _ = 1, 3 do
    local h, err, resp = http.get(url, nil, true)
    if h then return h end
    lastErr, lastResp = err, resp
    sleep(1)
  end
  return nil, lastErr, lastResp
end

-- CC:Tweaked charges every file its contents plus the length of its path (and a
-- little metadata), which the USTAR size fields do not include. This is a
-- per-entry allowance for that bookkeeping, NOT a size threshold: the byte
-- total itself is measured from the archive by measureTar(), never guessed.
local PER_ENTRY_OVERHEAD = 64

-- Decode the USTAR header fields the walks below need. A header is 512 bytes:
--   name     bytes   0.. 99
--   size     bytes 124..135  (11 octal digits followed by a NUL)
--   typeflag byte  156
--   prefix   bytes 345..499
--   magic    bytes 257..262
-- All offsets above are 0-based; the sub() indices here are 1-based.
local function tarHeader(hdr)
  local name = hdr:sub(1, 100):match("^[^%z]*") or ""
  local size = tonumber((hdr:sub(125, 136):match("^[^%z]*") or "0"):gsub("%s", ""), 8) or 0
  local typeflag = hdr:sub(157, 157)
  local prefix = hdr:sub(346, 500):match("^[^%z]*") or ""
  local full = prefix ~= "" and (prefix .. "/" .. name) or name
  return name, full, size, typeflag
end

-- A valid USTAR archive starts with a header carrying the "ustar" magic.
local function tarMagicOk(body)
  return #body >= 512 and body:sub(258, 262) == "ustar"
end

-- Pass 1: measure an in-memory USTAR archive without writing anything.
--
-- USTAR stores each entry as a fixed 512-byte header block followed by its data
-- rounded up to a 512-byte boundary. This walks those blocks and sums the
-- declared sizes; the 512-byte headers and padding are skipped (they are the
-- container, not the payload). Every entry is counted too - including
-- directories - so the caller can add PER_ENTRY_OVERHEAD per entry.
local function measureTar(body)
  local total, entries, pos = 0, 0, 1
  while pos + 511 <= #body do
    local hdr = body:sub(pos, pos + 511)
    local name, _, size = tarHeader(hdr)
    if name == "" then break end -- end-of-archive marker
    total = total + size
    entries = entries + 1
    pos = pos + 512 + math.ceil(size / 512) * 512
  end
  return total, entries
end

-- Describe an archive for diagnostics: how many entries were found and the
-- first few entry names. Used when the body is not USTAR or an entry is
-- missing, so the operator can see what the server actually returned.
local function tarDiagnostics(body)
  local names, entries, pos = {}, 0, 1
  while pos + 511 <= #body do
    local hdr = body:sub(pos, pos + 511)
    local name, full, size = tarHeader(hdr)
    if name == "" then break end -- end-of-archive marker
    entries = entries + 1
    if #names < 4 then names[#names + 1] = full ~= "" and full or name end
    pos = pos + 512 + math.ceil(size / 512) * 512
  end
  return entries, names
end

-- True when the archive carries a regular-file entry whose full path is `want`.
-- Used to confirm a bundle really contains the framework/library entry before
-- anything is written to disk.
local function tarHasEntry(body, want)
  local pos = 1
  while pos + 511 <= #body do
    local hdr = body:sub(pos, pos + 511)
    local name, full, size, typeflag = tarHeader(hdr)
    if name == "" then break end -- end-of-archive marker
    if full == want and typeflag ~= "5" then return true end
    pos = pos + 512 + math.ceil(size / 512) * 512
  end
  return false
end

-- Sanity-check a downloaded archive before using it. Returns the entry count,
-- or nil plus a reason. On failure it prints what was found: the entry count,
-- the first few entry names and the body size.
local function checkTar(step, source, body, required)
  stepStart(step)
  local entries, names = tarDiagnostics(body)
  local found = ("found %d entries, body %d bytes"):format(entries, #body)
  if #names > 0 then found = found .. ", first entries: " .. table.concat(names, ", ") end

  if not tarMagicOk(body) or entries == 0 then
    log("  archive sanity: %s", found)
    return nil, "not a USTAR archive (" .. found .. ")"
  end
  if required and not tarHasEntry(body, required) then
    log("  archive sanity: %s", found)
    return nil, ("required entry %s is missing (%s)"):format(required, found)
  end
  log("  archive sanity: OK (%d entries, body %d bytes)", entries, #body)
  return entries
end

-- Pass 2: extract an in-memory USTAR archive under `root`. This is the same
-- walk measureTar() uses, and it runs only after the free-space check passes,
-- so nothing is written before the check. Each entry's work is wrapped in
-- pcall: an "out of space" or "read-only mount" error names the entry that
-- failed and the filesystem's own error text instead of a raw traceback.
local function extractTar(body, root, entries, step, source)
  local count, pos, done = 0, 1, 0
  while pos + 511 <= #body do
    local hdr = body:sub(pos, pos + 511)
    local name, full, size, typeflag = tarHeader(hdr)
    if name == "" then break end -- end-of-archive marker
    pos = pos + 512
    done = done + 1
    local ok, err = pcall(function()
      if typeflag == "5" then
        mkdirp((root .. full):gsub("/+$", ""))
      else
        mkdirp(dirname(root .. full))
        local f = fs.open(root .. full, "wb")
        if not f then error("cannot open " .. root .. full .. " for writing", 0) end
        f.write(body:sub(pos, pos + size - 1))
        f.close()
        count = count + 1
      end
    end)
    if not ok then
      finishProgress()
      local detail = ("entry %d/%d %q: %s"):format(done, entries or 0, full, fsErrorText(err))
      log("  %s", detail)
      failStep(step, source, detail,
        "the target filesystem is full or read-only; free space or choose another install root")
    end
    drawProgress("Extract", done, entries, ("%d/%d files"):format(done, entries or 0))
    pos = pos + math.ceil(size / 512) * 512
  end
  finishProgress()
  return count
end

-- Download one archive and sanity-check it. Returns body, entries on success,
-- or nil, reason on any per-mirror failure: connection error (with HTTP
-- status when the response carried one), non-2xx status, Content-Length
-- mismatch, a body that is not USTAR, or a missing required entry.
local function downloadArchive(url, label, required)
  local started = os.epoch("utc")
  local handle, gerr, gresp = plainGet(url)
  if not handle then
    local reason = httpReason(gerr, gresp)
    log("  GET %s -> no response after %d ms: %s", url, os.epoch("utc") - started, reason)
    return nil, reason
  end
  local code, message = responseStatus(handle)
  if code and code >= 400 then
    handle.close()
    log("  GET %s -> HTTP %s after %d ms", url, tostring(code), os.epoch("utc") - started)
    if message then return nil, ("HTTP %d %s"):format(code, tostring(message)) end
    return nil, ("HTTP %d"):format(code)
  end
  local body, got, total = readBodyProgress(handle, "Download")
  handle.close()
  finishProgress()
  log("  GET %s -> status %s, Content-Length %s, %d bytes received, %d ms",
    url, code and tostring(code) or "none",
    (total and total > 0) and tostring(total) or "none",
    got, os.epoch("utc") - started)
  stepStart("check byte count of " .. label)
  noteByteCount(got, total)
  local mismatch = byteMismatch(got, total)
  if mismatch then return nil, mismatch end
  local entries, tarErr = checkTar("check tar archive " .. label, url, body, required)
  if not entries then return nil, tarErr end
  return body, entries
end

-- Download one dependency file with the plain http API and write it to `dest`.
-- Returns the byte count, or nil plus a reason. A write failure (full or
-- read-only target) is fatal and goes through failStep with the fs error text.
local function fetchDep(url, dest, what, step)
  stepStart(step)
  log("  url: %s", url)
  local started = os.epoch("utc")
  local h, gerr, gresp = plainGet(url)
  if not h then
    local reason = httpReason(gerr, gresp)
    log("  GET %s -> no response after %d ms: %s", url, os.epoch("utc") - started, reason)
    return nil, reason
  end
  local code, message = responseStatus(h)
  if code and code >= 400 then
    h.close()
    log("  GET %s -> HTTP %s after %d ms", url, tostring(code), os.epoch("utc") - started)
    if message then return nil, ("HTTP %d %s"):format(code, tostring(message)) end
    return nil, ("HTTP %d"):format(code)
  end
  local body, got, total = readBodyProgress(h, "Download")
  h.close()
  finishProgress()
  log("  GET %s -> status %s, Content-Length %s, %d bytes received, %d ms",
    url, code and tostring(code) or "none",
    (total and total > 0) and tostring(total) or "none",
    got, os.epoch("utc") - started)
  noteByteCount(got, total)
  local mismatch = byteMismatch(got, total)
  if mismatch then return nil, mismatch end
  local ok, werr = pcall(function()
    mkdirp(dirname(dest))
    local f = fs.open(dest, "wb")
    if not f then error("cannot open " .. dest .. " for writing", 0) end
    f.write(body)
    f.close()
  end)
  if not ok then
    failStep(step, dest, fsErrorText(werr),
      "the target filesystem is full or read-only; free space or choose another install root")
  end
  return #body
end

-- --------------------------------------------------------------------- main
local root = CONFIG.root
log("NeteaseCloudMusicApi (ncm) installer for CC:Tweaked")
log("  bundle : %s/dist/ncm.tar", CONFIG.base)
log("  target : %s", root)

-- Every third-party dependency goes into the library's own dependency
-- directory, so a complete install is a single deletable %sncm/ tree.
local libDir = root .. "ncm/lib/"
log("  deps   : %s", libDir)

-- 1. remove any previous install. The root-level files are the layout used by
-- older versions of this installer; they are cleaned up so a stale copy cannot
-- shadow the dependency directory.
stepStart("remove previous install")
local rmOk, rmErr = pcall(function()
  rmrf(root .. "ncm")
  rmrf(root .. "aeslua.lua")
  rmrf(root .. "aeslua")
  rmrf(root .. "cc_big_http.lua")
  rmrf(root .. "speaker.lua")
end)
if not rmOk then
  failStep("remove previous install", root, tostring(rmErr),
    "close any program using the files and check that " .. root .. " is writable")
end

-- 2. download cc_big_http.lua: the library's hard runtime dependency, used at
-- runtime for large audio GETs. It has a single fixed upstream URL and is not
-- part of our bundle, so it ignores the source picked above. The installer
-- itself does not need to load it (see fetchDep above for why the installer
-- sticks to plain GETs).
stepStart("prepare install directory")
local mkOk, mkErr = pcall(mkdirp, libDir)
if not mkOk then
  failStep("prepare install directory", libDir, fsErrorText(mkErr),
    "check that " .. root .. " is writable and has free space")
end
local ccBytes, ccErr = fetchDep(CONFIG.ccBigHttp, libDir .. "cc_big_http.lua",
  "cc_big_http (chunked-GET helper, GPL-2.0)", "download cc_big_http.lua")
if not ccBytes then
  failStep("download cc_big_http.lua", CONFIG.ccBigHttp, ccErr,
    "allow git.liulikeji.cn in the server's http whitelist, or fetch cc_big_http.lua manually")
end

-- 3. download + extract the library. Mirrors can serve a *stale*
-- dist/ncm.tar: jsDelivr caches each file of an @main URL separately, so it is
-- possible to get a fresh install.lua together with an old bundle. A stale
-- bundle lacks ncm/lib.lua, so the archive is sanity-checked for that entry
-- before extraction and the next mirror is tried when it is not current.
local function bundleIsCurrent()
  return fs.exists(root .. "ncm/lib.lua")
end

local bundleSources = { CONFIG.base }
for _, m in ipairs(MIRRORS) do
  if m.lib ~= CONFIG.base then bundleSources[#bundleSources + 1] = m.lib end
end

local extracted = false
local mirrorErrors = {}
for i = 1, #bundleSources do
  local base = bundleSources[i]
  local url = base .. "/dist/ncm.tar"
  stepStart(("download library bundle (mirror %d/%d)"):format(i, #bundleSources))
  log("  url: %s", url)

  local body, info = downloadArchive(url, "dist/ncm.tar", "ncm/lib.lua")
  if body then
    local entries = info
    -- Buffer the whole archive in memory and measure exactly what it needs.
    -- Nothing is written to disk until the free-space check passes.
    local totalBytes = measureTar(body)
    local needed = totalBytes + entries * PER_ENTRY_OVERHEAD
    log("  archive: %d entries, %d bytes (needs about %d with per-file overhead)",
      entries, totalBytes, needed)

    stepStart("check free space")
    if fs.getFreeSpace then
      local okf, free = pcall(fs.getFreeSpace, root)
      if not okf then
        failStep("check free space", root, tostring(free),
          "the filesystem cannot report free space; check the computer's disk")
      end
      log("  free %d bytes, needed %d bytes (%d entries)", free, needed, entries)
      if free < needed then
        failStep("check free space", root,
          ("not enough disk space: %d bytes free, this archive needs about %d bytes (%d entries)")
            :format(free, needed, entries),
          "delete files, or raise computer_space_limit in config/computercraft-server.toml and restart the world, then retry")
      end
    end

    stepStart("extract dist/ncm.tar")
    local files = extractTar(body, root, entries, "extract dist/ncm.tar", url)
    log("  extracted %d files", files)

    if bundleIsCurrent() then
      extracted = true
      if fs.exists(root .. "ncm/BUILD") then
        local bf = fs.open(root .. "ncm/BUILD", "r")
        if bf then
          log("  bundle build: %s", (bf.readAll():gsub("%s+$", "")))
          bf.close()
        end
      end
      if i > 1 then
        log("  note: the first source failed; a later mirror was used")
      end
      break
    end
    info = "archive extracted but " .. root .. "ncm/lib.lua is missing"
  end

  log("  mirror failed: %s", url)
  log("  reason: %s", info)
  log("  trying the next mirror ...")
  mirrorErrors[#mirrorErrors + 1] = { url = url, reason = info }
end
if not extracted then
  mirrorFailure("download library bundle", "dist/ncm.tar", mirrorErrors)
end

-- 4. download the aeslua-cc dependency
local deps = {
  "aeslua.lua",
  "aeslua/aes.lua",
  "aeslua/buffer.lua",
  "aeslua/ciphermode.lua",
  "aeslua/gf.lua",
  "aeslua/util.lua",
}
-- Fallback source for aeslua-cc. Some GitHub proxies 404 this repository
-- (verified: ghproxy.net returns 404 for it while proxying other repos fine),
-- and raw.githubusercontent.com is unreachable on some networks. jsDelivr
-- serves the tag reliably, so once the chosen source fails we switch to
-- jsDelivr for the remaining files instead of retrying every file twice.
local AESLUA_FALLBACK = "https://cdn.jsdelivr.net/gh/AngusAU293/aeslua-cc@0.2.1-CC/src"
local aesBase = CONFIG.aeslua
for _, rel in ipairs(deps) do
  local dest = libDir .. rel
  local bytes, derr = fetchDep(aesBase .. "/" .. rel, dest, "aeslua-cc " .. rel,
    "download aeslua-cc " .. rel)
  if not bytes and aesBase ~= AESLUA_FALLBACK then
    log("  source failed (%s); switching to jsDelivr for the rest", tostring(derr))
    aesBase = AESLUA_FALLBACK
    bytes, derr = fetchDep(aesBase .. "/" .. rel, dest, "aeslua-cc " .. rel,
      "download aeslua-cc " .. rel)
  end
  if not bytes then
    failStep("download aeslua-cc " .. rel, aesBase .. "/" .. rel, derr,
      "check the server's http whitelist and network, then retry")
  end
end

-- 5. download cc_speakerlib as the `speaker` program, next to cc_big_http.lua
-- so its automatic detection finds it. `ncm/cli` launches it by absolute path
-- to play .dfpwm passthrough links and mp3/aac links, which it transcodes
-- remotely through its -server default.
local spBytes, spErr = fetchDep(CONFIG.speakerlib, libDir .. "speaker.lua",
  "cc_speakerlib (the `speaker` program)", "download speakerlib.lua")
if not spBytes then
  failStep("download speakerlib.lua", CONFIG.speakerlib, spErr,
    "allow git.liulikeji.cn in the server's http whitelist, or fetch speakerlib.lua manually")
end

-- 6. verify files landed and print usage.
-- We deliberately do NOT call require("ncm") here: `wget run` executes this
-- installer from /rom/programs/http, and CraftOS resolves relative modules
-- against the *program's* directory, so it cannot see ncm/ from there. That is
-- expected and not an install failure.
stepStart("verify installed files")
local checks = {
  root .. "ncm/init.lua",
  libDir .. "aeslua.lua",
  libDir .. "cc_big_http.lua",
  libDir .. "speaker.lua",
}
local missing = {}
for _, p in ipairs(checks) do
  local ok = fs.exists(p)
  log("  %s %s", ok and "OK  " or "MISS", p)
  if not ok then missing[#missing + 1] = p end
end
if #missing > 0 then
  failStep("verify installed files", root, "missing after install: " .. table.concat(missing, ", "),
    "re-run the installer; if it repeats, delete " .. root .. "ncm and retry")
end
log("Verifying ... OK (%sncm/init.lua, %saeslua.lua, %scc_big_http.lua, %sspeaker.lua present)",
  root, libDir, libDir, libDir)

log("")
log("Done. To use it:")
log("  * if your program lives in %s, just require it:", root)
log("      local ncm = require(\"ncm\")")
log("  * otherwise put this line at the top of your program:")
log("      package.path = \"/?.lua;/?/init.lua;\" .. package.path")
log("      local ncm = require(\"ncm\")")
log("  Example:")
log("      print(textutils.serialize(ncm.search({ keywords = \"Jay Chou\" }).body.result))")

if logFile then logFile.close() end
