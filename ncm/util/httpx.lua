-- ncm/util/httpx.lua
-- Single HTTP GET gateway for the whole `ncm` library, backed by cc_big_http.
--
-- WHY THIS MODULE EXISTS
--   CC:Tweaked / CraftOS caps a single HTTP response body at `http_max_download`
--   bytes. In the extracted ROM config that value is 16777216 (16 MiB), so a
--   plain `http.get` fails on anything larger. NetEase audio files are commonly
--   10-50 MB, so the built-in GET is not usable for them.
--
--   `cc_big_http` works around the cap by issuing `Range: bytes=start-end`
--   requests in 15 MiB chunks and concatenating them, then returning a response
--   object that mimics the built-in `http.get` response: `read(n)`, `readAll()`,
--   `readLine()`, `getResponseCode()`, `getResponseHeaders()` and `close()`.
--   It normalizes a successful partial download to code 200. Every GET issued
--   by `ncm` must go through here.
--
-- MEMORY TRADE-OFF (documented on purpose, NOT avoided)
--   cc_big_http concatenates every chunk into ONE Lua string, so peak memory
--   equals the full file size. Users must raise `computerSpaceLimit` above their
--   largest audio file, otherwise the download fails with "Not enough space".
--
-- DEPENDENCY IS MANDATORY
--   There is intentionally NO fallback to the built-in `http.get`: using it
--   would silently fail above 16 MiB. Resolution order below is `require` first
--   (normal install), then `/cc_big_http.lua` (manual placement); if neither
--   yields a module with `.get`, we raise an actionable error. We never return
--   nil just because the dependency is missing.
--
-- API
--   M.get(url, headers, binary) -> response | nil, err, fail
--   M.get({ url = "...", headers = {...}, binary = true })  -- cc_big_http form

local M = {}

-- Resolve cc_big_http exactly once and cache it in this local.
local bigHttp
do
  local ok, mod = pcall(require, "cc_big_http")
  if ok and type(mod) == "table" and type(mod.get) == "function" then
    bigHttp = mod
  else
    local chunk = loadfile("/cc_big_http.lua")
    if chunk then
      local okChunk, modChunk = pcall(chunk)
      if okChunk and type(modChunk) == "table" and type(modChunk.get) == "function" then
        bigHttp = modChunk
      end
    end
  end

  if not bigHttp then
    error(
      "cc_big_http is required but was not found. "
      .. "Run install.lua, or place cc_big_http.lua at /cc_big_http.lua."
    )
  end
end

-- Delegate to cc_big_http.get, forwarding all arguments and the third return
-- value (`fail`) unchanged.
function M.get(...)
  return bigHttp.get(...)
end

return M
