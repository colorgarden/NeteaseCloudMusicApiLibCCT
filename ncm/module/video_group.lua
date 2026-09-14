-- 视频标签/分类下的视频

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    groupId = query.id,
    offset = js.or_(query.offset, 0),
    need_preview_url = "true",
    total = true,
  }
  return request(
    "/api/videotimeline/videogroup/otherclient/get",
    data,
    createOption(query, "weapi")
  )
end
