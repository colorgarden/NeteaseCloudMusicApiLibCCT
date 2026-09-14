-- 分享歌曲到动态

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
return function(query, request)
  local data = {
    type = js.or_(query.type, "song"), -- song,playlist,mv,djprogram,djradio,noresource
    msg = js.or_(query.msg, ""),
    id = js.or_(query.id, ""),
  }
  return request("/api/share/friends/resource", data, createOption(query))
end
