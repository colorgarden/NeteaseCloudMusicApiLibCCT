-- 曲风详情

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    tagId = query.tagId,
  }
  return request("/api/style-tag/home/head", data, createOption(query, "weapi"))
end
