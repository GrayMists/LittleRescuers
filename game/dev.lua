-- Лише для розробки (у збірку не потрапляє): автотести LR_TEST=<назва>.
--   LR_TEST=1      заставка -> станція -> пожежна 1 до кінця, зі знімками
--   LR_TEST=<id>   одна місія з list.lua: «проходить» її ботом (якщо місія має bot) і робить знімки
-- Знімки: ~/.local/share/love/littlerescuers/<назва>.png
local In = require("core.input")
local Sc = require("core.screens")
local Save = require("core.save")
local L = require("missions.list")

local Dev = {}
local steps, i, tt = {}, 1, 0
local total = 0

local function wait(s) return { wait = s } end
local function shot(name) return { wait = 0.01, shot = name } end
local function press(n) return { fn = function() In.press(n); In.release(n) end } end
local function hold(n) return { fn = function() In.press(n) end } end
local function release(n) return { fn = function() In.release(n) end } end
local function fn(f) return { fn = f } end
-- чекати, доки умова (не довше max секунд)
local function untilDo(cond, max) return { cond = cond, max = max or 60 } end

Dev.helpers = { wait = wait, shot = shot, press = press, hold = hold, release = release, fn = fn, untilDo = untilDo }

local function missionRun()
    local m = package.loaded["screens.mission"]
    return m and m.debug and m.debug() or nil
end

-- прогін однієї місії: бот місії (o.bot(dt), якщо є) керує кнопками
local function missionSteps(id)
    local name = id
    return {
        fn(function() Sc.go("mission", { id = id }, true) end), wait(0.5), shot(name .. "_0intro"),
        press("a"), wait(1.0), shot(name .. "_1start"),
        untilDo(function()
            local d = missionRun()
            if d and d.run.bot then d.run.bot(1 / 30) end
            return d and d.phase == "win"
        end, 240),
        wait(1.6), shot(name .. "_9win"),
        fn(function() for _, k in ipairs({ "up", "down", "left", "right", "a" }) do In.release(k) end
            print(id .. " stars:", Save.stars(id)) end),
        press("a"), wait(0.6),
    }
end

function Dev.init()
    io.stdout:setvbuf("line")
    love.audio.setVolume(0)
    Save.data = { stars = {} }
    local test = os.getenv("LR_TEST") or "1"
    if test == "1" then
        steps = {
            fn(function() Sc.go("title", nil, true) end), wait(1.0), shot("t1_title"),
            press("a"), wait(0.8), shot("t2_station"),
            press("a"), wait(0.4), shot("t3_missions"),
        }
        for _, st in ipairs(missionSteps("fire1")) do table.insert(steps, st) end
        table.insert(steps, wait(0.5))
        table.insert(steps, shot("t4_station_after"))
        -- кожна наявна місія ботом (щоб автотест ловив помилки в усіх місіях)
        for _, v in ipairs(L.VEHICLES) do
            for _, id in ipairs(L.of(v)) do
                if id ~= "fire1" then for _, st in ipairs(missionSteps(id)) do table.insert(steps, st) end end
            end
        end
        if L.get(L.FINALE) then for _, st in ipairs(missionSteps(L.FINALE)) do table.insert(steps, st) end end
    else
        steps = missionSteps(test)
    end
    table.insert(steps, { quit = true })
end

-- сталий крок часу: тест однаковий на будь-якій швидкості машини
function Dev.dt() return 1 / 30 end

function Dev.update(dt)
    total = total + dt
    local s = steps[i]
    if not s then return end
    tt = tt + dt
    if s.quit then print("TEST OK"); love.event.quit(); return end
    if s.cond then
        if s.cond() then i, tt = i + 1, 0
        elseif tt > s.max then print("TEST TIMEOUT at step " .. i); love.event.quit(1) end
    elseif s.fn then s.fn(); i, tt = i + 1, 0
    elseif tt >= (s.wait or 0) then
        if s.shot then love.graphics.captureScreenshot(s.shot .. ".png"); print("shot " .. s.shot) end
        i, tt = i + 1, 0
    end
end

function Dev.afterDraw() end

return Dev
