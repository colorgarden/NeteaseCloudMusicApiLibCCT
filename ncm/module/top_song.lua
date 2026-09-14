-- 新歌速递

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    areaId = js.or_(query.type, 0), -- 全部:0 华语:7 欧美:96 日本:8 韩国:16
    -- limit: query.limit || 100,
    -- offset: query.offset || 0,
    total = true,
  }
  return request(
    "/api/v1/discovery/new/songs",
    data,
    createOption(query, "weapi")
  )
end
