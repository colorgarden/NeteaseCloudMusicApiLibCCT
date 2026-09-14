-- 私信专辑

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
return function(query, request)
  local data = {
    id = query.id,
    msg = js.or_(query.msg, ""),
    type = "album",
    userIds = "[" .. js.tostr(query.user_ids) .. "]",
  }
  return request("/api/msg/private/send", data, createOption(query))
end
