-- 视频详情

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    id = query.id,
  }
  return request(
    "/api/cloudvideo/v1/video/detail",
    data,
    createOption(query, "weapi")
  )
end
