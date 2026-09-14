-- 当前账号关注的用户/歌手

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  local size = js.or_(query.size, 30)
  local cursor = js.or_(query.cursor, 0)
  local scene = js.or_(query.scene, 0) -- 0: 所有关注 1: 关注的歌手 2: 关注的用户
  local data = {
    authority = "false",
    -- JSON.stringify 保留 JS 插入顺序；Lua 的 pairs() 不保证，故手工拼接。
    page = '{"size":' .. json.encode(size) .. ',"cursor":' .. json.encode(cursor) .. "}",
    scene = scene,
    size = size,
    sortType = "0",
  }
  return request(
    "/api/user/follow/users/mixed/get/v2",
    data,
    createOption(query)
  )
end
