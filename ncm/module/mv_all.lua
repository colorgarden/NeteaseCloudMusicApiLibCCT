-- 全部MV

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  -- JSON.stringify preserves insertion order, so build the tags string
  -- manually to keep 地区/类型/排序 in the original order.
  local data = {
    tags = '{"地区":' .. json.encode(js.or_(query.area, "全部"))
      .. ',"类型":' .. json.encode(js.or_(query.type, "全部"))
      .. ',"排序":' .. json.encode(js.or_(query.order, "上升最快")) .. "}",
    offset = js.or_(query.offset, 0),
    total = "true",
    limit = js.or_(query.limit, 30),
  }
  return request("/api/mv/all", data, createOption(query))
end
