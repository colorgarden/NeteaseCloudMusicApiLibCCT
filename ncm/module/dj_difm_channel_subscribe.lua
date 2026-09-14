-- DIFM电台 - 收藏频道

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    id = query.id,
  }
  return request("/api/dj/difm/channel/subscribe", data, createOption(query))
end
