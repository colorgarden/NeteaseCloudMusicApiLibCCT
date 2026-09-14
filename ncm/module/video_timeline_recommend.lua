-- 推荐视频

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    offset = js.or_(query.offset, 0),
    filterLives = "[]",
    withProgramInfo = "true",
    needUrl = "1",
    resolution = "480",
  }
  return request("/api/videotimeline/get", data, createOption(query, "weapi"))
end
