-- 搜索
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  if query.type and tostring(query.type) == "2000" then
    local data = {
      keyword = query.keywords,
      scene = "normal",
      limit = js.or_(query.limit, 30),
      offset = js.or_(query.offset, 0),
    }
    return request("/api/search/voice/get", data, createOption(query))
  end
  local data = {
    s = query.keywords,
    type = js.or_(query.type, 1), -- 1: 单曲, 10: 专辑, 100: 歌手, 1000: 歌单, 1002: 用户, 1004: MV, 1006: 歌词, 1009: 电台, 1014: 视频
    limit = js.or_(query.limit, 30),
    offset = js.or_(query.offset, 0),
  }
  return request("/api/search/get", data, createOption(query))
end
