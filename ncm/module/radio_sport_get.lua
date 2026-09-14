-- 跑步漫游

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    bpm = js.or_(query.bpm, 50),
  }
  return request("/api/radio/sport/get", data, createOption(query))
end
