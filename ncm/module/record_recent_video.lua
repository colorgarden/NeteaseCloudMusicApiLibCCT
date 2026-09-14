local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 100),
  }
  return request(
    "/api/play-record/newvideo/list",
    data,
    createOption(query, "weapi")
  )
end
