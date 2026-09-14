local cfg = require("ncm.util.config")
local json = require("ncm.util.json")
-- 评论

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  query.type = cfg.resourceTypeMap[tostring(query.type)]
  -- JS: `undefined + number` is NaN, which JSON.stringify serialises as null.
  local threadId
  if type(query.type) == "string" then
    threadId = query.type .. js.tostr(query.id)
  else
    threadId = json.null
  end
  local pageSize = js.or_(query.pageSize, 20)
  local pageNo = js.or_(query.pageNo, 1)
  local sortType = js.or_(js.tonum(query.sortType), 99)
  if sortType == 1 then
    sortType = 99
  end
  local cursor = ""
  if sortType == 99 then
    cursor = (pageNo - 1) * pageSize
  elseif sortType == 2 then
    cursor = "normalHot#" .. js.tostr((pageNo - 1) * pageSize)
  elseif sortType == 3 then
    cursor = js.or_(query.cursor, "0")
  end
  local data = {
    threadId = threadId,
    pageNo = pageNo,
    showInner = js.or_(query.showInner, true),
    pageSize = pageSize,
    cursor = cursor,
    sortType = sortType, --99:按推荐排序,2:按热度排序,3:按时间排序
  }
  return request("/api/v2/resource/comments", data, createOption(query))
end
