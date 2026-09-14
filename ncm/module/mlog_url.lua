-- mlog链接

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    id = query.id,
    resolution = js.or_(query.res, 1080),
    type = 1,
  }
  return request("/api/mlog/detail/v1", data, createOption(query, "weapi"))
end
