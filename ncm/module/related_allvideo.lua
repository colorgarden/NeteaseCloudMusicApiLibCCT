-- 相关视频

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    id = query.id,
    type = js.ternary(js.tostr(query.id):match("^%d+$"), 0, 1),
  }
  return request(
    "/api/cloudvideo/v1/allvideo/rcmd",
    data,
    createOption(query, "weapi")
  )
end
