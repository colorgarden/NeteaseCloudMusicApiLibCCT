-- 云村星评馆 - 简要评论列表
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    cursor = '{"offset":0,"blockCodeOrderList":["HOMEPAGE_BLOCK_NEW_HOT_COMMENT"],"refresh":true}',
  }
  return request("/api/homepage/block/page", data, createOption(query))
end
