-- 会员本月下载歌曲记录

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, "20"),
    offset = js.or_(query.offset, "0"),
    total = "true",
  }
  return request("/api/member/song/monthdownlist", data, createOption(query))
end
