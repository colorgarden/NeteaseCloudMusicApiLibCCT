local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    compose_reminder = "true",
    compose_hot_comment = "true",
    limit = js.or_(query.limit, 10),
    user_id = query.uid,
    time = js.or_(query.time, 0),
  }
  return request(
    "/api/comment/user/comment/history",
    data,
    createOption(query, "weapi")
  )
end
