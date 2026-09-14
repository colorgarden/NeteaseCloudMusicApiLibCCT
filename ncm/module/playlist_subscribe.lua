-- 收藏与取消收藏歌单
local cfg = require("ncm.util.config")
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local path = js.ternary(tostring(query.t) == "1", "subscribe", "unsubscribe")
  local data = {
    id = query.id,
  }
  -- ...(query.t === 1 ? { checkToken: query.checkToken || APP_CONF.checkToken } : {})
  if query.t == 1 then
    data.checkToken = js.or_(query.checkToken, cfg.APP_CONF.checkToken)
  end
  query.checkToken = true -- 强制开启checkToken
  return request("/api/playlist/" .. path, data, createOption(query, "eapi"))
end
