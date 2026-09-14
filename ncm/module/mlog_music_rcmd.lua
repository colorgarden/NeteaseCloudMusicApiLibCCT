-- 歌曲相关视频

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  local data = {
    id = js.or_(query.mvid, 0),
    type = 2,
    rcmdType = 20,
    limit = js.or_(query.limit, 10),
    extInfo = json.encode({ songId = query.songid }),
  }
  return request("/api/mlog/rcmd/feed/list", data, createOption(query))
end
