-- Рятувальна станція: 4 гаражі (вліво/вправо — вибрати машину, A — відкрити),
-- потім ряд місій цієї машини (кружечки з картинкою й зірочками). Фінал — велика зірка на даху.
local Dr = require("core.draw")
local Ve = require("core.vehicles")
local Snd = require("core.sound")
local Save = require("core.save")
local Sc = require("core.screens")
local Kit = require("missions.kit")
local L = require("missions.list")
local lg = love.graphics
local C = Dr.C

local Scr = {}
local t = 0
local sel = 1          -- машина
local open = false     -- показано місії машини
local msel = 1         -- місія
local finaleSel = false

local function stars(id) return Save.stars(id) end

function Scr.enter()
    t = 0
    open = false
    finaleSel = false
    Snd.voice("station_" .. L.VEHICLES[sel].id)
end

function Scr.update(dt) t = t + dt end

local function missions() return L.of(L.VEHICLES[sel]) end

local function finaleOpen() return L.unlocked(L.FINALE, stars) end

function Scr.press(name)
    if not open then
        if name == "left" or name == "right" then
            if finaleSel then finaleSel = false
            else sel = (sel - 1 + (name == "right" and 1 or -1)) % #L.VEHICLES + 1 end
            Snd.play("pop")
            Snd.voice("station_" .. L.VEHICLES[sel].id)
        elseif name == "up" and finaleOpen() then
            finaleSel = true; Snd.play("pop"); Snd.voice("finale_pick")
        elseif name == "down" then finaleSel = false
        elseif name == "a" then
            if finaleSel then Sc.go("mission", { id = L.FINALE }); return end
            local list = missions()
            if #list == 0 then Snd.play("bump"); return end
            open = true
            msel = 1
            for k, id in ipairs(list) do if L.unlocked(id, stars) and stars(id) == 0 then msel = k; break end end
            Snd.play("horn")
        elseif name == "back" then Sc.go("title") end
        return
    end
    local list = missions()
    if name == "left" then msel = math.max(1, msel - 1); Snd.play("pop")
    elseif name == "right" then msel = math.min(#list, msel + 1); Snd.play("pop")
    elseif name == "back" or name == "down" then open = false
    elseif name == "a" then
        local id = list[msel]
        if L.unlocked(id, stars) then Sc.go("mission", { id = id })
        else Snd.play("bump"); Snd.voice("locked") end
    end
end

-- будівля станції з чотирма гаражами
local function drawStation()
    local bx, by, bw = 40, 400, 560
    Dr.shadow(320, by + 4, 300, 16)
    Dr.rrect(bx, by - 250, bw, 250, 20, Dr.hex(0xF2E6D8))
    Dr.rrect(bx - 10, by - 270, bw + 20, 40, 16, C.redD)
    -- башточка з дзвоном / зіркою фіналу
    Dr.rrect(270, by - 330, 100, 70, 14, Dr.hex(0xF2E6D8))
    Dr.poly({ 256, by - 326, 384, by - 326, 320, by - 380 }, C.redD)
    local fo = finaleOpen()
    Dr.star(320, by - 295, fo and 24 + math.sin(t * 4) * 3 or 18, fo and C.gold or C.grey, fo and 1 or 0.6, fo and t or 0)
    if finaleSel then Dr.arrow(320, by - 400, 0, 1.2, C.yellow, t) end
    for k, v in ipairs(L.VEHICLES) do
        local gx = bx + 20 + (k - 1) * 135
        local tm = Ve.TEAM[v.id]
        local isSel = (k == sel) and not finaleSel
        Dr.rrect(gx, by - 200, 120, 200, 14, isSel and C.yellow or Dr.hex(0xD9CBB8))
        Dr.rrect(gx + 8, by - 190, 104, 190, 10, Dr.hex(0x4A4E5C))
        -- машинка в гаражі (вибрана виїжджає трохи вперед)
        local s = v.id == "heli" and 0.42 or 0.5
        local yoff = v.id == "boat" and -10 or 0
        Ve.draw(v.id, gx + 60, by - 8 + yoff + (isSel and math.sin(t * 6) * 2 or 0), s, t, { siren = isSel, alt = 0 })
        -- значок над воротами: колір машини + зірочки
        Dr.circle(gx + 60, by - 220, 18, tm.color)
        local got, all = 0, 0
        for _, id in ipairs(L.of(v)) do all = all + 3; got = got + stars(id) end
        if all > 0 then Dr.number(got, gx + 60, by - 234, 20, C.white) end
        if isSel then Dr.arrow(gx + 60, by - 270, 0, 1, C.yellow, t) end
    end
end

local function drawMissions()
    local list = missions()
    lg.setColor(0.08, 0.1, 0.2, 0.45)
    lg.rectangle("fill", 0, 0, Dr.W, Dr.H)
    Dr.panel(40, 110, 560, 260)
    local v = L.VEHICLES[sel]
    local tm = Ve.TEAM[v.id]
    Dr.animal(tm.animal, 96, 160, 0.9, t, "happy", tm.hat)
    local n = #list
    local gap = math.min(160, 440 / math.max(1, n))
    local x0 = 330 - (n - 1) * gap / 2
    for k, id in ipairs(list) do
        local m = L.get(id)
        local x, y = x0 + (k - 1) * gap, 250
        local un = L.unlocked(id, stars)
        local isSel = (k == msel)
        if isSel then Dr.circle(x, y, 62 + math.sin(t * 5) * 3, C.gold) end
        Dr.circle(x, y, 54, un and C.white or C.grey)
        if un and m.icon then m.icon(x, y, 1, t)
        else
            Dr.rrect(x - 16, y - 8, 32, 26, 6, C.dark)
            lg.setLineWidth(5); Dr.color(C.dark); lg.arc("line", "open", x, y - 8, 11, math.pi, 2 * math.pi, 16)
        end
        for s = 1, 3 do
            Dr.star(x - 36 + (s - 1) * 36, y + 76, 14, s <= stars(id) and C.gold or Dr.hex(0xD6D0C4))
        end
        Dr.number(k, x, y - 90, 22, C.dark)
    end
    Dr.buttonA(560, 340, 0.9, t)
end

function Scr.draw()
    Kit.sky("town", t)
    Kit.clouds(t, 0)
    Kit.hills(0, 250)
    Dr.color(C.road); lg.rectangle("fill", 0, 400, Dr.W, 80)
    drawStation()
    Kit.drawChief(570, 60, 0.45, t, Snd.speaking())
    if open then drawMissions() end
end

return Scr
