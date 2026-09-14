-- 用户状态 - 编辑
local createOption = require("ncm.util.option")
local json = require("ncm.util.json")

return function(query, request)
  -- JSON.stringify 保留 JS 插入顺序，且会省略 undefined 字段；手工拼接。
  local parts = {}
  if query.type ~= nil then
    parts[#parts + 1] = '"type":' .. json.encode(query.type)
  end
  if query.iconUrl ~= nil then
    parts[#parts + 1] = '"iconUrl":' .. json.encode(query.iconUrl)
  end
  if query.content ~= nil then
    parts[#parts + 1] = '"content":' .. json.encode(query.content)
  end
  if query.actionUrl ~= nil then
    parts[#parts + 1] = '"actionUrl":' .. json.encode(query.actionUrl)
  end
  return request(
    "/api/social/user/status/edit",
    {
      content = "{" .. table.concat(parts, ",") .. "}",
    },
    createOption(query)
  )
end
