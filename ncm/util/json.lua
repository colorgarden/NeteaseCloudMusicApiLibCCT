-- ncm/util/json.lua - pure-Lua JSON encoder/decoder for CC:Tweaked (Lua 5.2 / Cobalt).
--
-- Usage:
--   local json = require("ncm.util.json")
--   json.encode({ a = 1, list = json.array({ 1, 2 }) })  --> {"a":1,"list":[1,2]}
--   json.decode('{"a":1}')                                --> { a = 1 }
--
-- Encoding rules:
--   * strings: escapes '"', '\\' and control bytes < 0x20 (as \u00XX); all
--     other bytes (including UTF-8 multibyte sequences) pass through untouched.
--   * numbers: integer form when integral, otherwise string.format("%.14g").
--   * arrays: a table is treated as a JSON array when it is marked with
--     M.array(...) (a metatable carrying __jsontype = "array"), when it has a
--     raw __jsontype = "array" key, or when it has positive integer keys
--     1..n and no other keys. An empty table defaults to a JSON object {}.
--   * null: encode M.null, or a nil-valued table field would be omitted.
--
-- Decoding rules:
--   * JSON objects -> tables keyed by string.
--   * JSON arrays  -> tables with sequential integer keys 1..n.
--   * JSON null    -> M.null sentinel.
--   * Malformed input raises a Lua error (never returns nil silently).

local M = {}

-- Unique sentinel representing JSON null.
M.null = setmetatable({}, {
  __tostring = function() return "null" end,
})

-- Metatable marking a table for array serialization.
local array_mt = { __jsontype = "array" }

-- Mark (or create) a table so that encode() always emits a JSON array, even
-- when the table is empty. Returns the same table.
function M.array(t)
  if t == nil then t = {} end
  if type(t) ~= "table" then
    error("json.array: expected table, got " .. type(t), 2)
  end
  setmetatable(t, array_mt)
  return t
end

-- True when t should be encoded as a JSON array.
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

-- Encode a lone Unicode code point as UTF-8 bytes.
local function utf8_char(cp)
  if cp < 0x80 then
    return string.char(cp)
  elseif cp < 0x800 then
    return string.char(
      0xC0 + math.floor(cp / 0x40),
      0x80 + cp % 0x40
    )
  elseif cp < 0x10000 then
    return string.char(
      0xE0 + math.floor(cp / 0x1000),
      0x80 + math.floor(cp / 0x40) % 0x40,
      0x80 + cp % 0x40
    )
  else
    return string.char(
      0xF0 + math.floor(cp / 0x40000),
      0x80 + math.floor(cp / 0x1000) % 0x40,
      0x80 + math.floor(cp / 0x40) % 0x40,
      0x80 + cp % 0x40
    )
  end
end

--------------------------------------------------------------------------------
-- Decoder
--------------------------------------------------------------------------------

local function decode(str)
  if type(str) ~= "string" then
    error("json.decode: expected string, got " .. type(str), 2)
  end

  local pos = 1
  local len = #str

  local function fail(msg)
    error(string.format("json.decode: %s at position %d", msg, pos), 2)
  end

  local function skip_ws()
    local _, e = str:find("^[ \t\r\n]*", pos)
    if e then pos = e + 1 end
  end

  local parse_value

  local function parse_string()
    -- str:sub(pos, pos) == '"'
    pos = pos + 1
    local buf = {}
    while true do
      local c = str:sub(pos, pos)
      if c == "" then fail("unterminated string") end
      if c == '"' then
        pos = pos + 1
        return table.concat(buf)
      elseif c == "\\" then
        pos = pos + 1
        local e = str:sub(pos, pos)
        if e == '"' then buf[#buf + 1] = '"'
        elseif e == "\\" then buf[#buf + 1] = "\\"
        elseif e == "/" then buf[#buf + 1] = "/"
        elseif e == "b" then buf[#buf + 1] = "\b"
        elseif e == "f" then buf[#buf + 1] = "\f"
        elseif e == "n" then buf[#buf + 1] = "\n"
        elseif e == "r" then buf[#buf + 1] = "\r"
        elseif e == "t" then buf[#buf + 1] = "\t"
        elseif e == "u" then
          local hex = str:sub(pos + 1, pos + 4)
          if #hex < 4 or hex:find("[^0-9a-fA-F]") then
            fail("invalid \\u escape")
          end
          local cp = tonumber(hex, 16)
          pos = pos + 4 -- now points at last hex digit
          -- Surrogate pair: high surrogate followed by \uXXXX low surrogate.
          if cp >= 0xD800 and cp <= 0xDBFF then
            if str:sub(pos + 1, pos + 2) == "\\u" then
              local hex2 = str:sub(pos + 3, pos + 6)
              if #hex2 == 4 and not hex2:find("[^0-9a-fA-F]") then
                local lo = tonumber(hex2, 16)
                if lo >= 0xDC00 and lo <= 0xDFFF then
                  cp = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00)
                  pos = pos + 6 -- now points at last hex digit of low surrogate
                end
              end
            end
          end
          buf[#buf + 1] = utf8_char(cp)
        else
          fail("invalid escape sequence \\" .. (e == "" and "<eof>" or e))
        end
        pos = pos + 1
      else
        if c:byte() < 0x20 then fail("unescaped control character") end
        buf[#buf + 1] = c
        pos = pos + 1
      end
    end
  end

  local function parse_number()
    local s, e = str:find("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
    if not s then fail("invalid number") end
    local token = str:sub(s, e)
    local n = tonumber(token)
    if not n then fail("invalid number '" .. token .. "'") end
    pos = e + 1
    return n
  end

  local function expect(word, value)
    if str:sub(pos, pos + #word - 1) ~= word then
      fail("expected '" .. word .. "'")
    end
    pos = pos + #word
    return value
  end

  local function parse_array()
    pos = pos + 1 -- consume '['
    local arr = {}
    skip_ws()
    if str:sub(pos, pos) == "]" then
      pos = pos + 1
      return setmetatable(arr, array_mt)
    end
    while true do
      arr[#arr + 1] = parse_value()
      skip_ws()
      local c = str:sub(pos, pos)
      if c == "," then
        pos = pos + 1
      elseif c == "]" then
        pos = pos + 1
        return setmetatable(arr, array_mt)
      else
        fail("expected ',' or ']' in array")
      end
    end
  end

  local function parse_object()
    pos = pos + 1 -- consume '{'
    local obj = {}
    skip_ws()
    if str:sub(pos, pos) == "}" then
      pos = pos + 1
      return obj
    end
    while true do
      skip_ws()
      if str:sub(pos, pos) ~= '"' then fail("expected string key") end
      local key = parse_string()
      skip_ws()
      if str:sub(pos, pos) ~= ":" then fail("expected ':'") end
      pos = pos + 1
      obj[key] = parse_value()
      skip_ws()
      local c = str:sub(pos, pos)
      if c == "," then
        pos = pos + 1
      elseif c == "}" then
        pos = pos + 1
        return obj
      else
        fail("expected ',' or '}' in object")
      end
    end
  end

  parse_value = function()
    skip_ws()
    local c = str:sub(pos, pos)
    if c == "" then fail("unexpected end of input") end
    if c == '"' then return parse_string() end
    if c == "{" then return parse_object() end
    if c == "[" then return parse_array() end
    if c == "t" then return expect("true", true) end
    if c == "f" then return expect("false", false) end
    if c == "n" then return expect("null", M.null) end
    if c == "-" or c:match("%d") then return parse_number() end
    fail("unexpected character '" .. c .. "'")
  end

  local value = parse_value()
  skip_ws()
  if pos <= len then fail("trailing garbage") end
  return value
end

--------------------------------------------------------------------------------
-- Encoder
--------------------------------------------------------------------------------

local escape_map = {
  ['"'] = '\\"',
  ["\\"] = "\\\\",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
}

local function encode_string(s)
  local out = s:gsub('[%c\\"]', function(c)
    local mapped = escape_map[c]
    if mapped then return mapped end
    return string.format("\\u%04x", c:byte())
  end)
  return '"' .. out .. '"'
end

local function encode_number(n)
  if n ~= n then error("json.encode: cannot encode NaN", 2) end
  if n == math.huge or n == -math.huge then
    error("json.encode: cannot encode infinity", 2)
  end
  -- Integral and safely representable as an integer.
  if n == math.floor(n) and math.abs(n) < 9007199254740992 then
    return string.format("%d", n)
  end
  return string.format("%.14g", n)
end

local function encode_value(v, seen)
  local tv = type(v)
  if v == nil then
    return "null"
  elseif v == M.null then
    return "null"
  elseif tv == "boolean" then
    return v and "true" or "false"
  elseif tv == "number" then
    return encode_number(v)
  elseif tv == "string" then
    return encode_string(v)
  elseif tv == "table" then
    if seen[v] then
      error("json.encode: circular reference detected", 2)
    end
    seen[v] = true
    local parts = {}
    local out
    if is_array(v) then
      for i = 1, #v do
        parts[i] = encode_value(v[i], seen)
      end
      out = "[" .. table.concat(parts, ",") .. "]"
    else
      for k, val in pairs(v) do
        if type(k) ~= "string" then
          error("json.encode: table keys must be strings, got " .. type(k), 2)
        end
        parts[#parts + 1] = encode_string(k) .. ":" .. encode_value(val, seen)
      end
      out = "{" .. table.concat(parts, ",") .. "}"
    end
    seen[v] = nil
    return out
  else
    error("json.encode: cannot encode value of type " .. tv, 2)
  end
end

function M.encode(value)
  return encode_value(value, {})
end

function M.decode(text)
  return decode(text)
end

return M
