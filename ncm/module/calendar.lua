local createOption = require("ncm.options")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    startTime = js.or_(query.startTime, js.now()),
    endTime = js.or_(query.endTime, js.now()),
  }
  return request("/api/mcalendar/detail", data, createOption(query, "weapi"))
end
