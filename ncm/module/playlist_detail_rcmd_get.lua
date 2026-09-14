-- 相关歌单推荐

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    scene = "playlist_head",
    playlistId = query.id,
    newStyle = "true",
  }
  return request("/api/playlist/detail/rcmd/get", data, createOption(query))
end
