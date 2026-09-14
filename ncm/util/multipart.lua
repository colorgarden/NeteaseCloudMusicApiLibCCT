-- ncm/util/multipart.lua
-- Build `multipart/form-data` request bodies for CC:Tweaked's `http` API.
--
-- CC:Tweaked's http functions take a plain string `body`, so a multipart body is
-- assembled by hand here (no external dependency). The wire format matches what
-- Node's `form-data` / the WHATWG FormData encoder produces: CRLF line endings,
-- `--<boundary>` delimiters, a trailing `--<boundary>--` terminator, and a
-- `Content-Type: multipart/form-data; boundary=<boundary>` header.
--
-- NOTE: the file-upload modules in `ncm/module/` (voice_upload, cloud,
-- avatar_upload, playlist_cover_update) do NOT use this helper. Their Node
-- originals talk to Netease's NOS object store with raw request bodies via
-- `axios`, not with `form-data`, so the ports replicate those raw uploads
-- directly with `http.post`/`http.put` (`binary = true`). See each module's
-- header comment. This helper is provided as reusable infrastructure for any
-- request that genuinely needs multipart encoding.
--
-- Usage:
--   local multipart = require("ncm.util.multipart")
--   local boundary = multipart.generateBoundary()
--   local body, contentType = multipart.build(boundary, {
--     { name = "song", value = "hello" },
--     { name = "file", filename = "a.mp3", contentType = "audio/mpeg", data = bytes },
--   })
--   http.post({ url = url, headers = { ["Content-Type"] = contentType }, body = body, binary = true })
--
-- Wire format produced by build():
--   --<boundary>\r\n
--   Content-Disposition: form-data; name="song"\r\n
--   \r\n
--   hello\r\n
--   --<boundary>\r\n
--   Content-Disposition: form-data; name="file"; filename="a.mp3"\r\n
--   Content-Type: audio/mpeg\r\n
--   \r\n
--   <raw bytes>\r\n
--   --<boundary>--\r\n

local M = {}

local CRLF = "\r\n"
local DEFAULT_PART_TYPE = "application/octet-stream"
local DEFAULT_BOUNDARY_PREFIX = "--------------------------"

-- Escape a value used inside a quoted Content-Disposition parameter so a
-- filename containing a quote, backslash or CR/LF cannot break the header.
local function quote(v)
  if v == nil then v = "" end
  v = tostring(v)
  v = v:gsub("\\", "\\\\"):gsub("\"", "\\\"")
  -- Collapse a run of CR/LF to a single space (header folding), not one space
  -- per control byte: "evil\r\nX" must become "evil X", not "evil  X".
  v = v:gsub("[\r\n]+", " ")
  return "\"" .. v .. "\""
end

-- `multipart/form-data; boundary=<boundary>` for the Content-Type header.
function M.contentType(boundary)
  return "multipart/form-data; boundary=" .. tostring(boundary)
end

-- Convenience: a fresh headers table carrying only Content-Type.
function M.headers(boundary)
  return { ["Content-Type"] = M.contentType(boundary) }
end

-- Random boundary; `prefix` defaults to the long dash run used by form-data.
function M.generateBoundary(prefix)
  local out = { prefix or DEFAULT_BOUNDARY_PREFIX }
  for _ = 1, 24 do
    out[#out + 1] = string.format("%x", math.random(0, 15))
  end
  return table.concat(out)
end

-- Build a multipart/form-data body from `parts`.
--
-- Each part is either:
--   { name = "field", value = "text" }                       -- simple field
--   { name = "file", filename = "a.bin",
--     contentType = "application/octet-stream", data = raw } -- file part
-- A part is treated as a file part when it carries `data` or `filename`.
--
-- Returns `body, contentType, boundary`. When `boundary` is nil/empty a random
-- one is generated (and returned as the third value).
function M.build(boundary, parts)
  if boundary == nil or boundary == "" then
    boundary = M.generateBoundary()
  end
  parts = parts or {}
  local out = {}
  for i = 1, #parts do
    local part = parts[i]
    if type(part) ~= "table" then
      error("multipart.build: part[" .. i .. "] must be a table", 2)
    end
    local name = part.name
    if name == nil then
      error("multipart.build: part[" .. i .. "] is missing `name`", 2)
    end

    out[#out + 1] = "--" .. boundary .. CRLF

    if part.data ~= nil or part.filename ~= nil then
      local filename = part.filename
      if filename == nil then filename = "blob" end
      out[#out + 1] = "Content-Disposition: form-data; name=" .. quote(name)
        .. "; filename=" .. quote(filename) .. CRLF
      out[#out + 1] = "Content-Type: "
        .. tostring(part.contentType or DEFAULT_PART_TYPE) .. CRLF
      out[#out + 1] = CRLF
      out[#out + 1] = part.data or ""
      out[#out + 1] = CRLF
    else
      out[#out + 1] = "Content-Disposition: form-data; name=" .. quote(name) .. CRLF
      out[#out + 1] = CRLF
      out[#out + 1] = part.value == nil and "" or tostring(part.value)
      out[#out + 1] = CRLF
    end
  end
  out[#out + 1] = "--" .. boundary .. "--" .. CRLF

  return table.concat(out), M.contentType(boundary), boundary
end

return M
