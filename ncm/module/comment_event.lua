-- 获取动态评论

local createOption = require("ncm.options")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 20),
    offset = js.or_(query.offset, 0),
    beforeTime = js.or_(query.before, 0),
  }
  return request(
    "/api/v1/resource/comments/" .. js.tostr(query.threadId),
    data,
    createOption(query, "weapi")
  )
end
