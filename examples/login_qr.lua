-- 示例：二维码登录，并把二维码直接画到 CC 终端
-- 用法：把它放到 ncm/ 所在目录(默认 /)，然后 `login_qr`
local ncm = require("ncm")
local qr = require("ncm.util.qrcode")

-- 1) 申请二维码 key
local keyRes = ncm.login_qr_key({})
local key = keyRes.body.data.unikey
print("二维码 key: " .. tostring(key))

-- 2) 生成登录二维码并绘制到终端(half 模式适合默认 51x19 终端)
local q = ncm.login_qr_create({ key = key })
qr.printCC(q.body.data.qrurl, { border = 1 })
print("请用网易云音乐 App 扫码登录…")

-- 3) 轮询扫码状态
while true do
  sleep(1)
  local s = ncm.login_qr_check({ key = key })
  local code = s.body.code
  if code == 800 then
    print("二维码已过期，请重新运行")
    break
  elseif code == 802 then
    print("已扫码，请在手机上点击确认")
  elseif code == 803 then
    print("登录成功！")
    print("cookie: " .. tostring(s.body.cookie))
    break
  end
end
