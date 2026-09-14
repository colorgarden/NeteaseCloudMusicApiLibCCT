-- 收藏单曲到歌单 从歌单删除歌曲

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  --
  -- JS indexes query.tracks directly; a missing value is a TypeError there, so
  -- mirror that instead of letting js.split stringify nil into "undefined".
  if query.tracks == nil then
    error("Cannot read properties of undefined (reading 'split')", 2)
  end
  local tracks = js.split(query.tracks, ",")
  local data = {
    op = query.op, -- del,add
    pid = query.pid, -- 歌单id
    trackIds = json.encode(tracks), -- 歌曲id
    imme = "true",
  }

  local ok, res = pcall(
    request,
    "/api/playlist/manipulate/tracks",
    data,
    createOption(query)
  )
  if ok then
    return {
      status = 200,
      body = js.assign({}, res),
    }
  end

  local error_ = res
  if error_.body.code == 512 then
    return request(
      "/api/playlist/manipulate/tracks",
      {
        op = query.op, -- del,add
        pid = query.pid, -- 歌单id
        trackIds = json.encode(js.concat(tracks, tracks)),
        imme = "true",
      },
      createOption(query)
    )
  else
    return {
      status = 200,
      body = error_.body,
    }
  end
end
