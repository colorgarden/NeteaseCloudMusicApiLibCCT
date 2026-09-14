-- mv简要百科信息
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    mvId = query.id,
  }
  return request("/api/rep/ugc/mv/get", data, createOption(query))
end
