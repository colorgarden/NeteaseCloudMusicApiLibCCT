-- 视频标签列表

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request(
    "/api/cloudvideo/group/list",
    data,
    createOption(query, "weapi")
  )
end
