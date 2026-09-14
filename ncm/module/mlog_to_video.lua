-- 将mlog id转为video id

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    mlogId = query.id,
  }
  return request(
    "/api/mlog/video/convert/id",
    data,
    createOption(query, "weapi")
  )
end
