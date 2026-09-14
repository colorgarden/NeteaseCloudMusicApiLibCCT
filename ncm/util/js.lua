-- ncm/util/js.lua
-- Small helpers that reproduce JavaScript semantics the original modules rely on.
-- The ported modules call these instead of hand-rolling equivalents, so behaviour
-- (falsy `||`, string `+`, array methods, ...) stays faithful to the Node original.

local M = {}

-- ---------------------------------------------------------------- truthiness
-- JS falsy: false, 0, "", null, undefined, NaN.
function M.falsy(v)
  return v == nil or v == false or v == 0 or v == "" or v ~= v
end

-- `a || b`
function M.or_(a, b)
  if M.falsy(a) then return b end
  return a
end

-- `a && b`
function M.and_(a, b)
  if M.falsy(a) then return a end
  return b
end

-- `a ?? b`
function M.nullish(a, b)
  if a == nil then return b end
  return a
end

-- `cond ? a : b`
function M.ternary(cond, a, b)
  if M.falsy(cond) then return b end
  return a
end

-- ---------------------------------------------------------------- conversions
function M.tostr(v)
  if v == nil then return "undefined" end
  local t = type(v)
  if t == "string" then return v end
  if t == "boolean" then return v and "true" or "false" end
  if t == "number" then
    if v == math.floor(v) and math.abs(v) < 1e15 then
      return string.format("%d", v)
    end
    return tostring(v)
  end
  return "[object Object]"
end

-- CryptoJS.MD5 coerces falsy inputs (undefined/null/false/0/"") to the empty
-- string (it hashes ""), so MD5-of-password must not stringify nil as
-- "undefined". Strings pass through unchanged.
function M.md5in(v)
  if M.falsy(v) then return "" end
  return M.tostr(v)
end

function M.tonum(v)
  if type(v) == "number" then return v end
  return tonumber(v)
end

-- JS `+`: numeric add unless either side is a string (then concat).
function M.add(a, b)
  if type(a) == "number" and type(b) == "number" then return a + b end
  return M.tostr(a) .. M.tostr(b)
end

-- ---------------------------------------------------------------- objects/arrays
local ARRAY_MARK = {}

-- Mark a table as a JSON array (also recognised by ncm.util.json).
function M.array(t)
  return setmetatable(t or {}, { __jsontype = "array", __jsarray = ARRAY_MARK })
end

function M.isarray(t)
  if type(t) ~= "table" then return false end
  local mt = getmetatable(t)
  return mt ~= nil and mt.__jsarray == ARRAY_MARK
end

function M.len(v)
  if v == nil then return 0 end
  return #v
end

function M.keys(t)
  local out = {}
  for k in pairs(t) do out[#out + 1] = k end
  return out
end

function M.values(t)
  local out = {}
  for _, v in pairs(t) do out[#out + 1] = v end
  return out
end

-- Object.assign(dst, ...) (shallow)
function M.assign(dst, ...)
  dst = dst or {}
  local sources = { ... }
  for i = 1, #sources do
    local src = sources[i]
    if type(src) == "table" then
      for k, v in pairs(src) do dst[k] = v end
    end
  end
  return dst
end

-- Spread of a table into a fresh table: `{...obj}`.
function M.copy(t)
  return M.assign({}, t)
end

-- ---------------------------------------------------------------- strings
-- String.prototype.split. Note JS semantics:
--   * split(undefined) returns the whole string (no splitting);
--   * split(sep, limit) yields AT MOST `limit` pieces, discarding the rest
--     (the limit-th piece ends at its separator, the remainder is dropped).
function M.split(s, sep, limit)
  s = M.tostr(s)
  local out = {}
  if sep == nil then
    out[1] = s
    return M.array(out)
  end
  if limit ~= nil and limit <= 0 then return M.array(out) end
  if sep == "" then
    for i = 1, #s do
      if limit and #out >= limit then break end
      out[#out + 1] = s:sub(i, i)
    end
    return M.array(out)
  end
  local from = 1
  while true do
    if limit and #out >= limit then break end
    local a, b = s:find(sep, from, true)
    if not a then
      out[#out + 1] = s:sub(from)
      break
    end
    out[#out + 1] = s:sub(from, a - 1)
    from = b + 1
  end
  return M.array(out)
end

function M.trim(s)
  return (M.tostr(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.join(arr, sep)
  sep = sep == nil and "," or sep
  local parts = {}
  for i = 1, #arr do parts[i] = M.tostr(arr[i]) end
  return table.concat(parts, sep)
end

-- Literal (non-pattern) replace of the first occurrence, like String.replace(str, str).
function M.replace(s, find, repl)
  s = M.tostr(s)
  local a, b = s:find(find, 1, true)
  if not a then return s end
  return s:sub(1, a - 1) .. repl .. s:sub(b + 1)
end

-- Replace every literal occurrence.
function M.replaceAll(s, find, repl)
  s = M.tostr(s)
  if find == "" then return s end
  local out, from = {}, 1
  while true do
    local a, b = s:find(find, from, true)
    if not a then
      out[#out + 1] = s:sub(from)
      break
    end
    out[#out + 1] = s:sub(from, a - 1) .. repl
    from = b + 1
  end
  return table.concat(out)
end

-- ---------------------------------------------------------------- array methods
function M.map(arr, fn)
  local out = {}
  for i = 1, #arr do out[i] = fn(arr[i], i - 1, arr) end
  return M.array(out)
end

function M.filter(arr, fn)
  local out = {}
  for i = 1, #arr do
    if fn(arr[i], i - 1, arr) then out[#out + 1] = arr[i] end
  end
  return M.array(out)
end

function M.forEach(arr, fn)
  for i = 1, #arr do fn(arr[i], i - 1, arr) end
end

function M.indexOf(arr, v)
  for i = 1, #arr do
    if arr[i] == v then return i - 1 end
  end
  return -1
end

function M.includes(arr, v)
  return M.indexOf(arr, v) ~= -1
end

function M.slice(arr, a, b)
  local n = #arr
  a = a or 0
  if a < 0 then a = math.max(n + a, 0) end
  b = b == nil and n or b
  if b < 0 then b = n + b end
  local out = {}
  for i = a, math.min(b, n) - 1 do out[#out + 1] = arr[i + 1] end
  return M.array(out)
end

function M.some(arr, fn)
  for i = 1, #arr do
    if fn(arr[i], i - 1, arr) then return true end
  end
  return false
end

function M.every(arr, fn)
  for i = 1, #arr do
    if not fn(arr[i], i - 1, arr) then return false end
  end
  return true
end

function M.find(arr, fn)
  for i = 1, #arr do
    if fn(arr[i], i - 1, arr) then return arr[i] end
  end
  return nil
end

function M.push(arr, v)
  arr[#arr + 1] = v
  return #arr
end

function M.concat(a, b)
  local out = {}
  for i = 1, #a do out[#out + 1] = a[i] end
  if M.isarray(b) or type(b) == "table" then
    for i = 1, #b do out[#out + 1] = b[i] end
  else
    out[#out + 1] = b
  end
  return M.array(out)
end

function M.reverse(arr)
  local out = {}
  for i = #arr, 1, -1 do out[#out + 1] = arr[i] end
  return M.array(out)
end

function M.sort(arr, cmp)
  local out = {}
  for i = 1, #arr do out[i] = arr[i] end
  if cmp then
    table.sort(out, cmp)
  else
    table.sort(out)
  end
  return out
end

-- ---------------------------------------------------------------- misc
-- JavaScript Date.now() (milliseconds). CC:Tweaked supports os.epoch("utc").
function M.now()
  if os.epoch then
    local ok, v = pcall(os.epoch, "utc")
    if ok then return v end
  end
  return os.time() * 1000
end

M.Math = {
  floor = math.floor,
  ceil = math.ceil,
  round = function(x) return math.floor(x + 0.5) end,
  random = math.random,
  abs = math.abs,
  max = math.max,
  min = math.min,
  pow = function(a, b) return a ^ b end,
}

return M
