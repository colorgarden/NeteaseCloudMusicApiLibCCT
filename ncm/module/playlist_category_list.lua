-- 歌单分类列表

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    cat = js.or_(query.cat, "全部"),
    limit = js.or_(query.limit, 24),
    newStyle = true,
  }
  return request("/api/playlist/category/list", data, createOption(query))
end
