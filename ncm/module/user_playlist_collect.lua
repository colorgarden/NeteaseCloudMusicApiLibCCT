-- 获取用户的收藏歌单列表

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, "100"),
    offset = js.or_(query.offset, "0"),
    userId = query.uid,
    isWebview = "true",
    includeRedHeart = "true",
    includeTop = "true",
  }
  return request("/api/user/playlist/collect", data, createOption(query))
end
