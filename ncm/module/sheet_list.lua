-- 乐谱列表
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
return function(query, request)
  local data = {
    id = query.id,
    abTest = js.or_(query.ab, "b"),
  }
  return request("/api/music/sheet/list/v1", data, createOption(query))
end
