local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    time = js.or_(query.time, "-1"),
    limit = js.or_(query.limit, "12"),
  }
  return request(
    "/api/mlog/playlist/mylike/bytime/get",
    data,
    createOption(query, "weapi")
  )
end
