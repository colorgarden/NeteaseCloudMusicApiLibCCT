-- 分类歌单

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  local data = {
    cat = js.or_(query.cat, "全部"), -- 全部,华语,欧美,日语,韩语,粤语,小语种,流行,摇滚,民谣,电子,舞曲,说唱,轻音乐,爵士,乡村,R&B/Soul,古典,民族,英伦,金属,朋克,蓝调,雷鬼,世界音乐,拉丁,另类/独立,New Age,古风,后摇,Bossa Nova,清晨,夜晚,学习,工作,午休,下午茶,地铁,驾车,运动,旅行,散步,酒吧,怀旧,清新,浪漫,性感,伤感,治愈,放松,孤独,感动,兴奋,快乐,安静,思念,影视原声,ACG,儿童,校园,游戏,70后,80后,90后,网络歌曲,KTV,经典,翻唱,吉他,钢琴,器乐,榜单,00后
    order = js.or_(query.order, "hot"), -- hot,new
    limit = js.or_(query.limit, 50),
    offset = js.or_(query.offset, 0),
    total = true,
  }
  local res = request(
    "/api/playlist/list",
    data,
    createOption(query, "weapi")
  )
  local result = js.replaceAll(
    json.encode(res),
    "avatarImgId_str",
    "avatarImgIdStr"
  )
  return json.decode(result)
end
