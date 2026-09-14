-- 助眠解压 - 查看同类推荐

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    id = query.id,
  }
  return request(
    "/api/voice/sati/resource/list/more/v1",
    data,
    createOption(query)
  )
end
