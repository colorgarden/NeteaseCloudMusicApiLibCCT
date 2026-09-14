local cfg = require("ncm.util.config")
-- 发送与删除评论

local createOption = require("ncm.options")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  query.t = ({ ["1"] = "add", ["0"] = "delete", ["2"] = "reply" })[js.tostr(query.t)]
  query.type = cfg.resourceTypeMap[js.tostr(query.type)]
  local data = {}
  if query.type == nil then
    -- JS: undefined + query.id === NaN, and JSON.stringify(NaN) === null
    data.threadId = json.null
  else
    data.threadId = query.type .. js.tostr(query.id)
  end

  if query.type == "A_EV_2_" then
    data.threadId = query.threadId
  end
  if query.t == "add" then
    data.content = query.content
  elseif query.t == "delete" then
    data.commentId = query.commentId
  elseif query.t == "reply" then
    data.commentId = query.commentId
    data.content = query.content
  end
  return request(
    "/api/resource/comments/" .. js.tostr(query.t),
    data,
    createOption(query, "weapi")
  )
end
