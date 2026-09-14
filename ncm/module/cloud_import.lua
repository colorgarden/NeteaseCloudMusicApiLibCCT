-- 云盘导入歌曲
local createOption = require("ncm.options")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  query.id = js.or_(query.id, -2)
  query.artist = js.or_(query.artist, "未知")
  query.album = js.or_(query.album, "未知")
  local checkData = {
    uploadType = 0,
    songs = json.encode({
      {
        md5 = query.md5,
        songId = query.id,
        bitrate = query.bitrate,
        fileSize = query.fileSize,
      },
    }),
  }
  local res = request(
    "/api/cloud/upload/check/v2",
    checkData,
    createOption(query)
  )
  --res.body.data[0].upload 0:文件可导入,1:文件已在云盘,2:不能导入
  --只能用song决定云盘文件名，且上传后的文件名后缀固定为mp3
  local importData = {
    uploadType = 0,
    songs = json.encode({
      {
        songId = res.body.data[0].songId,
        bitrate = query.bitrate,
        song = query.song,
        artist = query.artist,
        album = query.album,
        fileName = js.tostr(query.song) .. "." .. js.tostr(query.fileType),
      },
    }),
  }
  return request("/api/cloud/user/song/import", importData, createOption(query))
end
