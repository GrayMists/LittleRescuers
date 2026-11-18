-- Заставка: машинки виїжджають, натисни A.
local Dr = require("core.draw")
local Ve = require("core.vehicles")
local Snd = require("core.sound")
local Sc = require("core.screens")
local Kit = require("missions.kit")
local lg = love.graphics
local C = Dr.C

local Scr = {}
local t = 0

function Scr.enter() t = 0; Snd.voice("title") end

function Scr.update(dt) t = t + dt end

function Scr.press(name)
    if name == "a" then Snd.play("horn"); Sc.go("station") end
end

function Scr.draw()
    Kit.sky("town", t)
    Kit.clouds(t, t * 60)
    Kit.hills(t * 60, 250)
    Dr.color(C.road); lg.rectangle("fill", 0, 380, Dr.W, 100)
    Dr.color(C.line)
    for k = -1, 10 do lg.rectangle("fill", k * 80 - (t * 200) % 80, 425, 44, 6, 3, 3) end
    -- вертоліт летить згори
    Ve.draw("heli", 470 + math.sin(t * 0.7) * 40, 330, 0.7, t, { siren = true, alt = 60, shadowK = 0.5 })
    Ve.draw("fire", 140, 430, 0.75, t, { siren = true, speed = 14 })
    Ve.draw("police", 360, 452, 0.7, t, { siren = true, speed = 14 })
    -- назва: два рядки на табличці (для батьків; дитина орієнтується на картинки)
    Dr.panel(90, 40, 460, 110)
    local f = Dr.font(44)
    lg.setFont(f)
    local title = "Маленькі рятувальники"
    local s = math.min(1, 420 / f:getWidth(title))
    lg.push(); lg.translate(320, 95); lg.scale(s)
    Dr.color(C.redD); lg.print(title, -f:getWidth(title) / 2 + 2, -f:getHeight() / 2 + 3)
    Dr.color(C.red); lg.print(title, -f:getWidth(title) / 2, -f:getHeight() / 2)
    lg.pop()
    Dr.buttonA(320, 210, 1.4, t)
end

return Scr
