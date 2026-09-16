-- ncm/util/json.lua - JSON encoder/decoder for CC:Tweaked (Lua 5.2 / Cobalt).
--
-- Based on rxi/json.lua v0.1.2 (https://github.com/rxi/json.lua), MIT licence,
-- Copyright (c) 2020 rxi. rxi's implementation never escapes non-ASCII bytes:
-- UTF-8 multibyte sequences (CJK song / artist / playlist names returned by the
-- NetEase API) pass through untouched, which is exactly what CC's terminal
-- needs. This project (GPL-2.0) bundles it and adapts it below to keep the
-- public API and JSON semantics that the existing callers rely on.
--
-- Public API (unchanged from the previous in-house implementation):
--   json.encode(value)  -> string   (object/array/scalar -> JSON text)
--   json.decode(text)   -> value    (JSON text -> Lua value; raises on error)
--   json.null           -> sentinel encoded as `null` and returned for JSON null
--   json.array(t)       -> t        (marks t so it always encodes as an array)
--
-- Array vs object rules (kept compatible with the previous encoder):
--   * A table marked by json.array() - a metatable carrying __jsontype = "array"
--     - or carrying a raw __jsontype = "array" key always encodes as a JSON
--     array, so an empty marked table encodes as [].
--   * Otherwise a table with dense positive integer keys 1..n encodes as an
--     array; anything else encodes as an object.
--   * An empty, unmarked table encodes as {} (an object). Upstream rxi emits
--     [] here; this difference is deliberate and matches the old encoder.
--   * json.decode() tags decoded arrays with the same marker, so a decoded []
--     re-encodes as [] instead of {}.
--
-- Other deliberate differences from upstream rxi/json.lua:
--   * `null` decodes to json.null (not to nil), so null object fields survive.
--   * Integral numbers print in integer form (e.g. 1600000000000), matching the
--     old encoder; non-integral numbers use string.format("%.14g").
--   * Decoder errors are prefixed with "json.decode:" and trailing commas in
--     arrays/objects are rejected (upstream accepts "[1,]").
--
-- ASCII-only, no io/os/require and no C modules: safe under Cobalt.

local json = { _version = "0.1.2" }

-- ---------------------------------------------------------------- public API
-- [ncm] Compatibility layer: json.null sentinel and json.array() helper.

-- Unique sentinel representing JSON null.
json.null = setmetatable({}, {
  __tostring = function() return "null" end,
})

-- Metatable marking a table for array serialization.
local array_mt = { __jsontype = "array" }

-- Mark (or create) a table so encode() always emits a JSON array, even when the
-- table is empty. Returns the same table.
function json.array(t)
  if t == nil then t = {} end
  if type(t) ~= "table" then
    error("json.array: expected table, got " .. type(t), 2)
  end
  setmetatable(t, array_mt)
  return t
end

-- True when t must be serialized as a JSON array (see the rules above).
local function is_array(t)
  local mt = getmetatable(t)
  if type(mt) == "table" and mt.__jsontype == "array" then return true end
  if rawget(t, "__jsontype") == "array" then return true end
  local count, max = 0, 0
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
      return false
    end
    count = count + 1
    if k > max then max = k end
  end
  return count > 0 and max == count
end

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
  [ "\\" ] = "\\",
  [ "\"" ] = "\"",
  [ "\b" ] = "b",
  [ "\f" ] = "f",
  [ "\n" ] = "n",
  [ "\r" ] = "r",
  [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do
  escape_char_map_inv[v] = k
end

local function escape_char(c)
  return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end

local function encode_nil(val)
  return "null"
end

local function encode_table(val, stack)
  local res = {}
  stack = stack or {}

  -- Circular reference?
  if stack[val] then error("json.encode: circular reference detected", 2) end
  stack[val] = true

  if is_array(val) then
    for i = 1, #val do
      res[i] = encode(val[i], stack)
    end
    stack[val] = nil
    return "[" .. table.concat(res, ",") .. "]"
  end

  -- Object: only string keys are allowed (matches JSON.stringify semantics).
  for k, v in pairs(val) do
    if type(k) ~= "string" then
      error("json.encode: table keys must be strings, got " .. type(k), 2)
    end
    res[#res + 1] = encode(k, stack) .. ":" .. encode(v, stack)
  end
  stack[val] = nil
  return "{" .. table.concat(res, ",") .. "}"
end

local function encode_string(val)
  -- Escape only control bytes (0-31), NUL, backslash and quote. Every byte
  -- >= 0x20, including UTF-8 multibyte sequences, is copied verbatim.
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end

local function encode_number(val)
  -- Check for NaN, -inf and inf.
  if val ~= val or val <= -math.huge or val >= math.huge then
    error("json.encode: cannot encode non-finite number '" .. tostring(val) .. "'", 2)
  end
  -- [ncm] Integral values keep integer form, as the previous encoder did.
  if val == math.floor(val) and math.abs(val) < 9007199254740992 then
    return string.format("%d", val)
  end
  return string.format("%.14g", val)
end

local type_func_map = {
  [ "nil"     ] = encode_nil,
  [ "table"   ] = encode_table,
  [ "string"  ] = encode_string,
  [ "number"  ] = encode_number,
  [ "boolean" ] = tostring,
}

encode = function(val, stack)
  -- [ncm] The null sentinel is a table, so handle it before type dispatch.
  if val == json.null then return "null" end
  local t = type(val)
  local f = type_func_map[t]
  if f then
    return f(val, stack)
  end
  error("json.encode: cannot encode value of type '" .. t .. "'", 2)
end

function json.encode(val)
  return ( encode(val) )
end

-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do
    res[ select(i, ...) ] = true
  end
  return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
  [ "true"  ] = true,
  [ "false" ] = false,
  -- [ncm] JSON null becomes the sentinel so callers can tell it apart from a
  -- missing key (upstream rxi decodes null to nil).
  [ "null"  ] = json.null,
}

local function next_char(str, idx, set, negate)
  for i = idx, #str do
    if set[str:sub(i, i)] ~= negate then
      return i
    end
  end
  return #str + 1
end

local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error( string.format("json.decode: %s at line %d col %d", msg, line_count, col_count) )
end

local function codepoint_to_utf8(n)
  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
  local f = math.floor
  if n <= 0x7f then
    return string.char(n)
  elseif n <= 0x7ff then
    return string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
  elseif n <= 0x10ffff then
    return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                       f(n % 4096 / 64) + 128, n % 64 + 128)
  end
  error( string.format("json.decode: invalid unicode codepoint '%x'", n) )
end

local function parse_unicode_escape(s)
  local n1 = tonumber( s:sub(1, 4),  16 )
  local n2 = tonumber( s:sub(7, 10), 16 )
  -- Surrogate pair?
  if n2 then
    return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
  end
  return codepoint_to_utf8(n1)
end

local function parse_string(str, i)
  local res = ""
  local j = i + 1
  local k = j

  while j <= #str do
    local x = str:byte(j)

    if x < 32 then
      decode_error(str, j, "control character in string")

    elseif x == 92 then -- `\`: Escape
      res = res .. str:sub(k, j - 1)
      j = j + 1
      local c = str:sub(j, j)
      if c == "u" then
        local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                 or str:match("^%x%x%x%x", j + 1)
                 or decode_error(str, j - 1, "invalid unicode escape in string")
        res = res .. parse_unicode_escape(hex)
        j = j + #hex
      else
        if not escape_chars[c] then
          decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
        end
        res = res .. escape_char_map_inv[c]
      end
      k = j + 1

    elseif x == 34 then -- `"`: End of string
      res = res .. str:sub(k, j - 1)
      return res, j + 1
    end

    j = j + 1
  end

  decode_error(str, i, "expected closing quote for string")
end

local function parse_number(str, i)
  local x = next_char(str, i, delim_chars)
  local s = str:sub(i, x - 1)
  local n = tonumber(s)
  if not n then
    decode_error(str, i, "invalid number '" .. s .. "'")
  end
  return n, x
end

local function parse_literal(str, i)
  local x = next_char(str, i, delim_chars)
  local word = str:sub(i, x - 1)
  if not literals[word] then
    decode_error(str, i, "invalid literal '" .. word .. "'")
  end
  return literal_map[word], x
end

local function parse_array(str, i)
  local res = {}
  local n = 1
  i = i + 1
  while 1 do
    local x
    i = next_char(str, i, space_chars, true)
    -- Empty array / end of array?
    if str:sub(i, i) == "]" then
      -- [ncm] Reject a trailing comma ("[1,]"): `]` is only valid before any
      -- element has been read.
      if n > 1 then
        decode_error(str, i, "unexpected ']' in array")
      end
      i = i + 1
      break
    end
    -- Read token
    x, i = parse(str, i)
    res[n] = x
    n = n + 1
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "]" then break end
    if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
  end
  -- [ncm] Tag decoded arrays so an empty one re-encodes as [] (not {}).
  return setmetatable(res, array_mt), i
end

local function parse_object(str, i)
  local res = {}
  local n = 1
  i = i + 1
  while 1 do
    local key, val
    i = next_char(str, i, space_chars, true)
    -- Empty object / end of object?
    if str:sub(i, i) == "}" then
      -- [ncm] Reject a trailing comma ("{... ,}").
      if n > 1 then
        decode_error(str, i, "unexpected '}' in object")
      end
      i = i + 1
      break
    end
    -- Read key
    if str:sub(i, i) ~= '"' then
      decode_error(str, i, "expected string for key")
    end
    key, i = parse(str, i)
    -- Read ':' delimiter
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) ~= ":" then
      decode_error(str, i, "expected ':' after key")
    end
    i = next_char(str, i + 1, space_chars, true)
    -- Read value
    val, i = parse(str, i)
    -- Set
    res[key] = val
    n = n + 1
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "}" then break end
    if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
  end
  return res, i
end

local char_func_map = {
  [ '"' ] = parse_string,
  [ "0" ] = parse_number,
  [ "1" ] = parse_number,
  [ "2" ] = parse_number,
  [ "3" ] = parse_number,
  [ "4" ] = parse_number,
  [ "5" ] = parse_number,
  [ "6" ] = parse_number,
  [ "7" ] = parse_number,
  [ "8" ] = parse_number,
  [ "9" ] = parse_number,
  [ "-" ] = parse_number,
  [ "t" ] = parse_literal,
  [ "f" ] = parse_literal,
  [ "n" ] = parse_literal,
  [ "[" ] = parse_array,
  [ "{" ] = parse_object,
}

parse = function(str, idx)
  local chr = str:sub(idx, idx)
  local f = char_func_map[chr]
  if f then
    return f(str, idx)
  end
  decode_error(str, idx, "unexpected character '" .. chr .. "'")
end

function json.decode(str)
  if type(str) ~= "string" then
    error("json.decode: expected argument of type string, got " .. type(str), 2)
  end
  local res, idx = parse(str, next_char(str, 1, space_chars, true))
  idx = next_char(str, idx, space_chars, true)
  if idx <= #str then
    decode_error(str, idx, "trailing garbage")
  end
  return res
end

return json
