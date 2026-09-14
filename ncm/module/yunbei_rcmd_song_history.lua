-- 云贝推歌历史记录

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  local data = {
    page = '{"size":' .. json.encode(js.or_(query.size, 20)) .. ',"cursor":' .. json.encode(js.or_(query.cursor, "")) .. "}",
  }
  return request("/api/yunbei/rcmd/song/history/list", data, createOption(query, "weapi"))
end
