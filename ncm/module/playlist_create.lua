-- 创建歌单

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    name = query.name,
    privacy = js.or_(query.privacy, "0"), -- 0 普通歌单, 10 隐私歌单
    type = js.or_(query.type, "NORMAL"), -- 默认 NORMAL, VIDEO 视频歌单, SHARED 共享歌单
  }
  return request("/api/playlist/create", data, createOption(query, "weapi"))
end
