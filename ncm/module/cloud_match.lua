local createOption = require("ncm.options")

return function(query, request)
  local data = {
    userId = query.uid,
    songId = query.sid,
    adjustSongId = query.asid,
  }
  return request(
    "/api/cloud/user/song/match",
    data,
    createOption(query, "weapi")
  )
end
