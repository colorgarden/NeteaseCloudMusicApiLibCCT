-- 视频链接

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    ids = '["' .. js.tostr(query.id) .. '"]',
    resolution = js.or_(query.res, 1080),
  }
  return request("/api/cloudvideo/playurl", data, createOption(query, "weapi"))
end
