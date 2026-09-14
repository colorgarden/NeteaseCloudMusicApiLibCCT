-- 新晋电台榜/热门电台榜
local typeMap = {
  new = 0,
  hot = 1,
}
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 100),
    offset = js.or_(query.offset, 0),
    type = js.or_(typeMap[js.or_(query.type, "new")], "0"), --0为新晋,1为热门
  }
  -- ncm.util.option 用 Lua `or` 合并 crypto, 空串被当作真值; 先归一空值以走默认参数.
  if js.falsy(query.crypto) then query.crypto = nil end
  return request("/api/djradio/toplist", data, createOption(query, "weapi"))
end
