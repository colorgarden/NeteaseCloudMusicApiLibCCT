-- 用户歌单

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    uid = query.uid,
    limit = js.or_(query.limit, 30),
    offset = js.or_(query.offset, 0),
    includeVideo = true,
  }
  return request("/api/user/playlist", data, createOption(query, "weapi"))
end
