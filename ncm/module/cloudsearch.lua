-- 搜索

local createOption = require("ncm.options")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    s = query.keywords,
    type = js.or_(query.type, 1), -- 1: 单曲, 10: 专辑, 100: 歌手, 1000: 歌单, 1002: 用户, 1004: MV, 1006: 歌词, 1009: 电台, 1014: 视频
    limit = js.or_(query.limit, 30),
    offset = js.or_(query.offset, 0),
    total = true,
  }
  return request("/api/cloudsearch/pc", data, createOption(query))
end
