-- 关注TA的人(粉丝)

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    userId = query.uid,
    time = "0",
    limit = js.or_(query.limit, 30),
    offset = js.or_(query.offset, 0),
    getcounts = "true",
  }
  return request(
    "/api/user/getfolloweds/" .. js.tostr(query.uid),
    data,
    createOption(query)
  )
end
