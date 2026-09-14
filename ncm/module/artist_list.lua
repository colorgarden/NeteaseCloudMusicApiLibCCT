-- 歌手分类

--
--     type 取值
--     1:男歌手
--     2:女歌手
--     3:乐队
--
--     area 取值
--     -1:全部
--     7华语
--     96欧美
--     8:日本
--     16韩国
--     0:其他
--
--     initial 取值 a-z/A-Z
--

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

-- JS isNaN(): Number(x) is NaN.
local function isNaN(v)
  if type(v) == "number" then
    return v ~= v
  end
  if type(v) == "string" then
    if js.trim(v) == "" then return false end
    return tonumber(v) == nil
  end
  if v == nil then return true end
  return false
end

return function(query, request)
  local initial
  if isNaN(query.initial) then
    local s = string.upper(js.or_(query.initial, ""))
    local ch
    if #s > 0 then
      ch = string.byte(s, 1)
    end
    initial = js.or_(ch, nil)
  else
    initial = query.initial
  end
  local data = {
    initial = initial,
    offset = js.or_(query.offset, 0),
    limit = js.or_(query.limit, 30),
    total = true,
    type = js.or_(query.type, "1"),
    area = query.area,
  }
  if js.falsy(query.crypto) then query.crypto = nil end
  return request("/api/v1/artist/list", data, createOption(query, "weapi"))
end
