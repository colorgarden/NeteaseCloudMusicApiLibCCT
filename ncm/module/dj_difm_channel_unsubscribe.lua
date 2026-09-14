-- DIFM电台 - 取消收藏频道

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    id = query.id,
  }
  return request("/api/dj/difm/channel/unsubscribe", data, createOption(query))
end
