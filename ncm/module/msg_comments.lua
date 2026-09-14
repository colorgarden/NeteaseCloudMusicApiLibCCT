-- 评论

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    beforeTime = js.or_(query.before, "-1"),
    limit = js.or_(query.limit, 30),
    total = "true",
    uid = query.uid,
  }

  return request(
    "/api/v1/user/comments/" .. js.tostr(query.uid),
    data,
    createOption(query, "weapi")
  )
end
