-- 编辑歌单

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  query.desc = js.or_(query.desc, "")
  query.tags = js.or_(query.tags, "")
  local data = {
    ["/api/playlist/desc/update"] = '{"id":'
      .. js.tostr(query.id)
      .. ',"desc":"'
      .. js.tostr(query.desc)
      .. '"}',
    ["/api/playlist/tags/update"] = '{"id":'
      .. js.tostr(query.id)
      .. ',"tags":"'
      .. js.tostr(query.tags)
      .. '"}',
    ["/api/playlist/update/name"] = '{"id":'
      .. js.tostr(query.id)
      .. ',"name":"'
      .. js.tostr(query.name)
      .. '"}',
  }
  return request("/api/batch", data, createOption(query))
end
