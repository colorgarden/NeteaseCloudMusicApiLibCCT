-- 全部视频列表

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    groupId = 0,
    offset = js.or_(query.offset, 0),
    need_preview_url = "true",
    total = true,
  }
  --   /api/videotimeline/otherclient/get
  return request("/api/videotimeline/otherclient/get", data, createOption(query, "weapi"))
end
