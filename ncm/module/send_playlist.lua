-- 私信歌单

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
return function(query, request)
  local data = {
    id = query.playlist,
    type = "playlist",
    msg = query.msg,
    userIds = "[" .. js.tostr(query.user_ids) .. "]",
  }
  return request("/api/msg/private/send", data, createOption(query))
end
