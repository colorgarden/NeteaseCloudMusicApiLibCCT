-- MV详情

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    id = query.mvid,
  }
  return request("/api/v1/mv/detail", data, createOption(query, "weapi"))
end
