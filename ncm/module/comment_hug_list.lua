local cfg = require("ncm.util.config")
local createOption = require("ncm.options")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  query.type = cfg.resourceTypeMap[js.tostr(js.or_(query.type, 0))]
  local threadId
  if query.type == nil then
    -- JS: undefined + undefined === NaN, and JSON.stringify(NaN) === null
    threadId = json.null
  else
    threadId = query.type .. js.tostr(query.sid)
  end
  local data = {
    targetUserId = query.uid,
    commentId = query.cid,
    cursor = js.or_(query.cursor, "-1"),
    threadId = threadId,
    pageNo = js.or_(query.page, 1),
    idCursor = js.or_(query.idCursor, -1),
    pageSize = js.or_(query.pageSize, 100),
  }
  return request(
    "/api/v2/resource/comments/hug/list",
    data,
    createOption(query)
  )
end
