--[[
  install.lua - one-click installer for the CC:Tweaked port of
  NeteaseCloudMusicApi (library name: `ncm`).

  What it does
    1. removes any previous install (ncm/, plus the root-level dependency
       files written by older versions of this installer),
    2. downloads cc_big_http (the library's runtime dependency for large GETs),
    3. streams dist/ncm.tar off the internet straight into the filesystem
       (uncompressed USTAR - no gzip library or temp file needed),
    4. downloads the aeslua-cc dependency,
    5. downloads cc_speakerlib, the speaker program `ncm/cli` uses for local
       .dfpwm passthrough,
    6. verifies the bundle it extracted is current, and prints a usage hint.

  Everything the installer fetches is small (a few hundred KB at most, far
  below the ~16 MiB single-response cap), so it uses plain http GETs. The
  library itself routes its large audio GETs through cc_big_http at runtime.

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
  -- of our MIT-licensed bundle, so the library mirror selection below never
  -- affects it. It is downloaded with the plain http API first (bootstrap),
  -- then used for every other GET. The server's http_whitelist must include
  -- git.liulikeji.cn or this download fails.
  ccBigHttp = "https://git.liulikeji.cn/xingluo/cc_big_http/raw/branch/main/cc_big_http.lua",
  -- cc_speakerlib, installed as /speaker.lua. Its own SPDX header declares
  -- MPL-2.0 (the upstream repo ships no LICENSE file). Like cc_big_http it is
  -- NOT bundled with this MIT project and is fetched from its fixed upstream
  -- URL. It is the `speaker` program `ncm/cli` launches for local .dfpwm
  -- passthrough, and it auto-detects /cc_big_http.lua next to itself.
  speakerlib = "https://git.liulikeji.cn/xingluo/cc_speakerlib/raw/branch/main/speakerlib.lua",
}

local args = { ... }

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
    print("Using command-line source: " .. CONFIG.base)
    return
  end

  print("Choose a download source:")
  for i, m in ipairs(MIRRORS) do print(("  %d) %s"):format(i, m.name)) end
  print(("  %d) Custom URL"):format(#MIRRORS + 1))

  local n = tonumber(ask("Select [1]: ")) or 1
  if n >= 1 and n <= #MIRRORS then
    CONFIG.base = MIRRORS[n].lib
    CONFIG.aeslua = MIRRORS[n].aes
    print("Selected: " .. MIRRORS[n].name)
  elseif n == #MIRRORS + 1 then
    local u = ask("Library base URL (the dir containing dist/ncm.tar): ")
    if u ~= "" then CONFIG.base = u:gsub("/+$", "") end
    local a = ask("aeslua dependency URL [default jsDelivr]: ")
    if a ~= "" then CONFIG.aeslua = a:gsub("/+$", "") end
    print("Using custom source")
  else
    CONFIG.base = MIRRORS[1].lib
    CONFIG.aeslua = MIRRORS[1].aes
    print("Invalid input, using default: " .. MIRRORS[1].name)
  end
end

pickSource()

-- ----------------------------------------------------------------- utilities
local function log(fmt, ...)
  if select("#", ...) > 0 then print(fmt:format(...)) else print(fmt) end
end

local function die(msg)
  printError("install: " .. msg)
  error(msg, 0)
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
local function plainGet(url)
  if not http then
    die("the HTTP API is unavailable (use an Advanced Computer and enable http)")
  end
  local lastErr
  for _ = 1, 3 do
    local h, err = http.get(url, nil, true)
    if h then return h end
    lastErr = err
    sleep(1)
  end
  return nil, lastErr
end

-- Download one file with the plain http API.
--
-- The installer uses plain GETs for everything it fetches: the bundle is
-- ~700 KB, cc_big_http ~8 KB, the aeslua-cc files ~4 KB each and speakerlib
-- ~40 KB - all far below the 16 MiB single-response cap.
--
-- cc_big_http is only correct for *large* responses. Its Range chunking
-- requires the server not to compress the body; CDNs such as jsDelivr ignore
-- `Accept-Encoding: identity` for text files, CraftOS then transparently
-- decompresses the body, and cc_big_http's byte-range validation rejects the
-- result ("Invalid chunk size for bytes=..."). The library still uses it at
-- runtime, where the GETs are large already-compressed audio files, which is
-- exactly what it is built for.
local function fetchDep(url, dest, what)
  log("Downloading %s ...", what)
  local h, err = plainGet(url)
  if not h then return nil, tostring(err) end
  local body = h.readAll()
  h.close()
  mkdirp(dirname(dest))
  local f = assert(fs.open(dest, "wb"))
  f.write(body)
  f.close()
  return #body
end

local function readN(handle, n)
  local out, got = {}, 0
  while got < n do
    local chunk = handle.read(n - got)
    if not chunk or #chunk == 0 then break end
    out[#out + 1] = chunk
    got = got + #chunk
  end
  return table.concat(out), got
end

-- Stream a (uncompressed) USTAR archive from an HTTP handle into `root`.
local function untar(handle, root)
  local count = 0
  while true do
    local hdr, n = readN(handle, 512)
    if n < 512 then break end
    local name = hdr:sub(1, 100):match("^[^%z]*") or ""
    if name == "" then break end -- end-of-archive
    local sizeStr = (hdr:sub(125, 136):match("^[^%z]*") or "0"):gsub("%s", "")
    local size = tonumber(sizeStr, 8) or 0
    local typeflag = hdr:sub(157, 157)
    local prefix = hdr:sub(346, 500):match("^[^%z]*") or ""
    local full = prefix ~= "" and (prefix .. "/" .. name) or name
    local dest = root .. full

    if typeflag == "5" then
      mkdirp(dest:gsub("/+$", ""))
    else
      mkdirp(dirname(dest))
      local f = assert(fs.open(dest, "wb"))
      local remaining = size
      while remaining > 0 do
        local chunk = readN(handle, math.min(remaining, 8192))
        if #chunk == 0 then break end
        f.write(chunk)
        remaining = remaining - #chunk
      end
      f.close()
      local pad = (512 - (size % 512)) % 512
      if pad > 0 then readN(handle, pad) end
      count = count + 1
    end
  end
  return count
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
log("Removing previous install (if any) ...")
rmrf(root .. "ncm")
rmrf(root .. "aeslua.lua")
rmrf(root .. "aeslua")
rmrf(root .. "cc_big_http.lua")
rmrf(root .. "speaker.lua")

-- 2. download cc_big_http.lua: the library's hard runtime dependency, used at
-- runtime for large audio GETs. It has a single fixed upstream URL and is not
-- part of our bundle, so it ignores the source picked above. The installer
-- itself does not need to load it (see fetchDep above for why the installer
-- sticks to plain GETs).
mkdirp(libDir)
local ccBytes, ccErr = fetchDep(CONFIG.ccBigHttp, libDir .. "cc_big_http.lua",
  "cc_big_http (chunked-GET helper, GPL-2.0)")
if not ccBytes then
  die("cannot download cc_big_http.lua from " .. CONFIG.ccBigHttp
    .. " (allow git.liulikeji.cn in http_whitelist, or fetch it manually): "
    .. tostring(ccErr))
end

-- 3. download + extract the library. Mirrors can serve a *stale*
-- dist/ncm.tar: jsDelivr caches each file of an @main URL separately, so it is
-- possible to get a fresh install.lua together with an old bundle. A stale
-- bundle extracts "successfully" but lacks ncm/lib.lua and the newest fixes,
-- so verify what actually landed and fall through to the next mirror when it
-- is stale.
local function bundleIsCurrent()
  return fs.exists(root .. "ncm/lib.lua")
end

local bundleSources = { CONFIG.base }
for _, m in ipairs(MIRRORS) do
  if m.lib ~= CONFIG.base then bundleSources[#bundleSources + 1] = m.lib end
end

local extracted = false
for i = 1, #bundleSources do
  local base = bundleSources[i]
  log("Downloading library bundle (%d/%d) ...", i, #bundleSources)
  log("  %s/dist/ncm.tar", base)

  local handle, err = plainGet(base .. "/dist/ncm.tar")

  if not handle then
    log("  download failed: %s", tostring(err))
  else
    -- CC:Tweaked caps a computer's internal disk at `computer_space_limit`
    -- (config/computercraft-server.toml, default 1,000,000 bytes). The library
    -- is ~440 KB of Lua across 400 files plus ~80 KB of dependencies, and CC
    -- also charges for each file's path, so the default is too tight. Check
    -- first: "Out of space" from deep inside the extractor is impossible to
    -- act on, this message is not.
    if fs.getFreeSpace then
      local free = fs.getFreeSpace(root)
      log("  free space: %d bytes", free)
      if free < 800000 then
        die(string.format(
          "not enough disk space: %d bytes free, about 800000 needed.\n"
            .. "  Raise computer_space_limit in config/computercraft-server.toml\n"
            .. "  (for example 5000000), restart the world, then run this again.",
          free))
      end
    end

    log("Extracting ...")
    local files = untar(handle, root)
    handle.close()
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
        log("  note: the first source served a stale bundle; a later mirror was used")
      end
      break
    end
    log("  that bundle is stale (no ncm/lib.lua); trying another mirror ...")
  end
end
if not extracted then
  die("could not obtain a current library bundle from any mirror")
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
  local bytes, derr = fetchDep(aesBase .. "/" .. rel, libDir .. rel, "aeslua-cc " .. rel)
  if not bytes and aesBase ~= AESLUA_FALLBACK then
    log("  source failed (%s); switching to jsDelivr for the rest", tostring(derr))
    aesBase = AESLUA_FALLBACK
    bytes, derr = fetchDep(aesBase .. "/" .. rel, libDir .. rel, "aeslua-cc " .. rel)
  end
  if not bytes then die("cannot download " .. rel .. ": " .. tostring(derr)) end
end

-- 5. download cc_speakerlib as the `speaker` program, next to cc_big_http.lua
-- so its automatic detection finds it. `ncm/cli` launches it by absolute path
-- to play local .dfpwm files only, so its remote-transcode default (-server)
-- is never used.
local spBytes, spErr = fetchDep(CONFIG.speakerlib, libDir .. "speaker.lua",
  "cc_speakerlib (the `speaker` program)")
if not spBytes then die("cannot download speakerlib.lua: " .. tostring(spErr)) end

-- 6. verify files landed and print usage.
-- We deliberately do NOT call require("ncm") here: `wget run` executes this
-- installer from /rom/programs/http, and CraftOS resolves relative modules
-- against the *program's* directory, so it cannot see ncm/ from there. That is
-- expected and not an install failure.
local installed = fs.exists(root .. "ncm/init.lua")
  and fs.exists(libDir .. "aeslua.lua")
  and fs.exists(libDir .. "cc_big_http.lua")
  and fs.exists(libDir .. "speaker.lua")
if installed then
  log("Verifying ... OK (%sncm/init.lua, %saeslua.lua, %scc_big_http.lua, %sspeaker.lua present)",
    root, libDir, libDir, libDir)
else
  log("Warning: expected files are missing under %s", root)
end

log("")
log("Done. To use it:")
log("  * if your program lives in %s, just require it:", root)
log("      local ncm = require(\"ncm\")")
log("  * otherwise put this line at the top of your program:")
log("      package.path = \"/?.lua;/?/init.lua;\" .. package.path")
log("      local ncm = require(\"ncm\")")
log("  Example:")
log("      print(textutils.serialize(ncm.search({ keywords = \"Jay Chou\" }).body.result))")
