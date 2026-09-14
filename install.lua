--[[
  install.lua - one-click installer for the CC:Tweaked port of
  NeteaseCloudMusicApi (library name: `ncm`).

  What it does
    1. removes any previous install (ncm/, aeslua.lua, aeslua/),
    2. streams dist/ncm.tar off the internet straight into the filesystem
       (uncompressed USTAR - no gzip library or temp file needed),
    3. downloads the aeslua-cc dependency from jsDelivr,
    4. prints a usage hint.

  Requirements
    * An Advanced Computer (or Command Computer) with the HTTP API enabled.
    * The server must allow the github.com / raw.githubusercontent.com host
      (and cdn.jsdelivr.net) in its http whitelist.

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

local function httpGet(url)
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

local function fetchToFile(url, dest)
  local h, err = httpGet(url)
  if not h then return nil, err end
  local body = h.readAll()
  h.close()
  mkdirp(dirname(dest))
  local f = assert(fs.open(dest, "wb"))
  f.write(body)
  f.close()
  return #body
end

-- --------------------------------------------------------------------- main
local root = CONFIG.root
log("NeteaseCloudMusicApi (ncm) installer for CC:Tweaked")
log("  bundle : %s/dist/ncm.tar", CONFIG.base)
log("  target : %s", root)

-- 1. remove any previous install
log("Removing previous install (if any) ...")
rmrf(root .. "ncm")
rmrf(root .. "aeslua.lua")
rmrf(root .. "aeslua")

-- 2. download + extract the library
log("Downloading library bundle ...")
local handle, err = httpGet(CONFIG.base .. "/dist/ncm.tar")
if not handle then die("cannot download ncm.tar: " .. tostring(err)) end
log("Extracting ...")
local files = untar(handle, root)
handle.close()
log("  installed %d files into %sncm/", files, root)

-- 3. download the aeslua-cc dependency
log("Downloading dependency (aeslua-cc) ...")
local deps = {
  "aeslua.lua",
  "aeslua/aes.lua",
  "aeslua/buffer.lua",
  "aeslua/ciphermode.lua",
  "aeslua/gf.lua",
  "aeslua/util.lua",
}
for _, rel in ipairs(deps) do
  local bytes, derr = fetchToFile(CONFIG.aeslua .. "/" .. rel, root .. rel)
  if not bytes then die("cannot download " .. rel .. ": " .. tostring(derr)) end
end
log("  installed %d dependency files", #deps)

-- 4. verify files landed and print usage.
-- We deliberately do NOT call require("ncm") here: `wget run` executes this
-- installer from /rom/programs/http, and CraftOS resolves relative modules
-- against the *program's* directory, so it cannot see ncm/ from there. That is
-- expected and not an install failure.
if fs.exists(root .. "ncm/init.lua") and fs.exists(root .. "aeslua.lua") then
  log("Verifying ... OK (%sncm/init.lua and %saeslua.lua present)", root, root)
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
