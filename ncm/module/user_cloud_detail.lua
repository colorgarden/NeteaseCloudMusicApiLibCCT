-- 云盘数据详情

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local id = js.split((query.id:gsub("%s", "")), ",")
  local data = {
    songIds = id,
  }
  return request("/api/v1/cloud/get/byids", data, createOption(query, "weapi"))
end
