-- 删除歌单

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    ids = "[" .. js.tostr(query.id) .. "]",
  }
  return request("/api/playlist/remove", data, createOption(query, "weapi"))
end
