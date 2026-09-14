-- ncm/util/gzip.lua
-- gzip / zlib / raw-DEFLATE decompression for CC:Tweaked.
--
-- CC:Tweaked has no zlib, so this replaces Node's `zlib.gunzipSync` used by the
-- original `util/crypto.js` for "aeapi" responses. Backed by the vendored
-- LibDeflate (pure Lua, zlib License) in ncm/util/libdeflate.lua.

local LibDeflate = require("ncm.util.libdeflate")

local M = {}

-- Strip the gzip container: 10-byte header (+ optional FEXTRA/FNAME/FCOMMENT/
-- FHCRC) and the 8-byte trailer (CRC32 + ISIZE), leaving raw DEFLATE.
local function stripGzip(s)
  if #s < 18 then return nil end
  local id1, id2, cm, flg = s:byte(1, 4)
  if id1 ~= 0x1f or id2 ~= 0x8b or cm ~= 8 then return nil end
  local pos = 11
  if bit32.band(flg, 0x04) ~= 0 then
    local xlen = s:byte(pos) + s:byte(pos + 1) * 256
    pos = pos + 2 + xlen
  end
  if bit32.band(flg, 0x08) ~= 0 then
    pos = (s:find("\0", pos, true) or #s) + 1
  end
  if bit32.band(flg, 0x10) ~= 0 then
    pos = (s:find("\0", pos, true) or #s) + 1
  end
  if bit32.band(flg, 0x02) ~= 0 then pos = pos + 2 end
  return s:sub(pos, #s - 8)
end

function M.isGzip(s)
  return #s >= 2 and s:byte(1) == 0x1f and s:byte(2) == 0x8b
end

-- gzip (RFC1952) -> string, or nil on failure.
function M.gunzip(s)
  local raw = stripGzip(s)
  if not raw then return nil end
  return LibDeflate:DecompressDeflate(raw)
end

-- zlib (RFC1950) -> string, or nil on failure.
function M.inflate(s)
  return LibDeflate:DecompressZlib(s)
end

-- raw DEFLATE (RFC1951) -> string, or nil on failure.
function M.inflateRaw(s)
  return LibDeflate:DecompressDeflate(s)
end

return M
