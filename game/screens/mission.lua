-- Місія: рація з капітаном -> сама місія -> зірочки й «дякую» -> назад на станцію.
-- Start/Select під час місії — пауза-питання: A — продовжити, ще раз Start — на станцію.
local Dr = require("core.draw")
local Snd = require("core.sound")
local Fx = require("core.fx")
local Save = require("core.save")
local Sc = require("core.screens")
local Kit = require("missions.kit")
local L = require("missions.list")
local lg = love.graphics
local C = Dr.C

local Scr = {}
local m, run, phase, t, got, paused

function Scr.enter(args)
    m = L.get(args.id)
    run = m.new()
    phase, t, paused = "intro", 0, false
    Fx.clear()
    Snd.voice(m.intro)
end

function Scr.leave()
    if run and run.leave then run.leave() end
    Snd.stopLoops()
    Fx.clear()
end

function Scr.update(dt)
    t = t + dt
    if paused then return end
    if phase == "run" then
        if run.update(dt) then
            phase, t = "win", 0
            got = run.stars()
            Save.setStars(m.id, got)
            if run.leave then run.leave() end
            Snd.stopLoops()
            Fx.clear()
            Fx.burst("confetti", 320, 200, 80, 320, 3, 12)
            Snd.play("cheer")
            Snd.voiceList({ "win_" .. got, "thanks_" .. (m.rescued or "cat") })
        end
    end
end

function Scr.press(name)
    if paused then
        if name == "a" then paused = false
        elseif name == "back" then Sc.go("station") end
        return
    end
    if phase == "intro" then
        if name == "a" and t > 0.4 then phase, t = "run", 0; Snd.voice(m.id .. "_go") end
        if name == "back" then Sc.go("station") end
    elseif phase == "run" then
        if name == "back" then paused = true; Snd.loop("siren", false); Snd.loop("spray", false); return end
        if run.press then run.press(name) end
    elseif phase == "win" then
        if (name == "a" or name == "back") and t > 1.2 then Sc.go("station") end
    end
end

-- для автотесту (dev.lua)
function Scr.debug() return { phase = phase, run = run } end

local function drawIntro()
    Kit.sky("town", t)
    Kit.clouds(t, t * 20)
    Kit.hills(t * 20, 260)
    Dr.panel(70, 90, 500, 290)
    Kit.drawChief(200, 230, 1.1, t, Snd.speaking() or t < 2)
    -- що трапилось: картинка місії й рятувальник
    Dr.circle(420, 200, 70, C.white)
    if m.icon then m.icon(420, 200, 1.3, t) end
    local tm = L.TEAM[m.vehicle]
    if tm then Dr.animal(tm.animal, 420, 320, 0.8, t, "happy", tm.hat) end
    -- хвилі з рації
    for k = 0, 2 do
        local p = (t * 1.2 + k / 3) % 1
        lg.setLineWidth(3)
        Dr.color(C.blue, 1 - p)
        lg.arc("line", "open", 280, 170, 20 + p * 40, -0.6, 0.6, 16)
    end
    if t > 0.4 then Dr.buttonA(320, 410, 1.2, t) end
end

local function drawWin()
    run.draw()
    lg.setColor(0.08, 0.1, 0.2, 0.35)
    lg.rectangle("fill", 0, 0, Dr.W, Dr.H)
    Dr.panel(120, 110, 400, 250)
    Kit.thanks(m.rescued or "cat", 320, 220, t)
    for s = 1, 3 do
        local appear = math.max(0, math.min(1, (t - 0.3 * s) * 4))
        local sc = appear * (1 + (s == 2 and 0.25 or 0))
        if appear > 0 then
            Dr.star(320 + (s - 2) * 90, 310 - (s == 2 and 10 or 0), 30 * sc, s <= got and C.gold or Dr.hex(0xD6D0C4), 1, math.sin(t * 2 + s) * 0.15)
        end
    end
    Fx.draw()
    if t > 1.2 then Dr.buttonA(320, 410, 1.1, t) end
end

function Scr.draw()
    if phase == "intro" then drawIntro()
    elseif phase == "run" then run.draw()
    else drawWin() end
    if paused then
        lg.setColor(0.08, 0.1, 0.2, 0.6)
        lg.rectangle("fill", 0, 0, Dr.W, Dr.H)
        Dr.panel(170, 160, 300, 160)
        -- ▶ продовжити (A)  |  🏠 на станцію (Start)
        Dr.poly({ 230, 205, 230, 275, 285, 240 }, C.green)
        Dr.house(355, 270, 70, 50, C.red)
        Dr.buttonA(258, 300, 0.7, t)
    end
end

return Scr
