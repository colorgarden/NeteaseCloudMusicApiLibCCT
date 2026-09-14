-- 编辑歌单顺序

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    ids = query.ids,
  }
  return request(
    "/api/playlist/order/update",
    data,
    createOption(query, "weapi")
  )
end
