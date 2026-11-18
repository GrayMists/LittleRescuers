-- Пожежна 1: «Димок у Їжачка». Доїхати (зібрати зірочки) і загасити вогонь у трьох вікнах.
-- Зразок місії: new() -> об'єкт з update(dt) (true — місію пройдено), draw(), press(name), stars().
local Dr = require("core.draw")
local Ve = require("core.vehicles")
local In = require("core.input")
local Snd = require("core.sound")
local Fx = require("core.fx")
local Kit = require("missions.kit")
local lg = love.graphics
local C = Dr.C

local M = {
    id = "fire1", vehicle = "fire", rescued = "hedgehog",
    intro = "fire1_intro",                -- капітан по рації
    icon = function(x, y, s, t)
        Dr.house(x - 26 * s, y + 30 * s, 52 * s, 34 * s, C.purple)
        Dr.flame(x + 14 * s, y - 2 * s, 0.9 * s, t)
    end,
}

local HOUSE_X, GROUND = 330, 400
local WINDOWS = { { 360, 250 }, { 450, 250 }, { 405, 330 } }

local function drawHouse(x, y, t, fires, smokeOn)
    Dr.shadow(x + 120, y + 2, 150, 14)
    Dr.rrect(x, y - 190, 240, 190, 14, C.cream)
    Dr.poly({ x - 20, y - 186, x + 260, y - 186, x + 120, y - 290 }, C.purple)
    Dr.rrect(x + 186, y - 300, 30, 60, 6, C.brown)
    Dr.rrect(x + 96, y - 70, 48, 70, 16, C.brown)
    for k, w in ipairs(WINDOWS) do
        local wx, wy = w[1] - HOUSE_X + x, w[2] - GROUND + y
        if k < 3 then
            Dr.window(wx - 26, wy - 26, 52, 52, fires and fires[k] and fires[k] > 0.05)
            if fires and fires[k] then Dr.flame(wx, wy + 30, 1.6, t, fires[k]) end
        end
    end
    -- третій вогник — на ганку біля дверей
    if fires and fires[3] then Dr.flame(x + 75, y, 1.5, t, fires[3]) end
    if smokeOn and math.floor(t * 8) % 3 == 0 then Fx.add("smoke", x + 200, y - 300, 10, -40, 2.2, 10) end
end

function M.new()
    local o = { phase = "drive", t = 0, fires = { 1, 1, 1 }, aimX = 420, aimY = 300, spray = false, doneT = nil, idle = 0 }
    o.drive = Kit.newDrive({
        vehicle = "fire", length = 3600, theme = "town", stars = 8, bumps = 4, seed = 11,
        goal = function(x, y, t) drawHouse(x, y + 90, t, nil, true) end,
    })

    function o.update(dt)
        o.t = o.t + dt
        if o.phase == "drive" then
            Snd.loop("siren", true, 0.5)
            if Kit.updateDrive(o.drive, dt) then
                o.phase = "spray"
                Snd.loop("siren", false)
                Snd.voice("fire1_spray")
            end
            return false
        end
        -- гасимо: хрестовина веде приціл, A (тримати) — вода
        local dx, dy = In.axis()
        o.aimX = math.max(200, math.min(620, o.aimX + dx * 260 * dt))
        o.aimY = math.max(120, math.min(430, o.aimY + dy * 260 * dt))
        o.spray = In.down("a") and not o.doneT
        o.idle = (dx == 0 and dy == 0 and not o.spray) and o.idle + dt or 0
        Snd.loop("spray", o.spray, 0.6)
        if o.spray then
            local nx, ny = 168, 318
            for _ = 1, 3 do
                local tx, ty = o.aimX + love.math.random(-10, 10), o.aimY + love.math.random(-10, 10)
                local tt = 0.45
                Fx.add("drop", nx, ny, (tx - nx) / tt, (ty - ny) / tt - 0.5 * 600 * tt, tt, 4 + love.math.random() * 3)
            end
            for k, w in ipairs(WINDOWS) do
                local fx, fy = w[1], w[2]
                if k == 3 then fx, fy = HOUSE_X + 75, GROUND - 20 end
                if o.fires[k] > 0 and math.abs(o.aimX - fx) < 50 and math.abs(o.aimY - fy) < 55 then
                    o.fires[k] = math.max(0, o.fires[k] - dt * 0.55)
                    if math.floor(o.t * 10) % 2 == 0 then Fx.add("smoke", fx, fy - 30, love.math.random(-20, 20), -50, 1.2, 8) end
                    if o.fires[k] == 0 then Snd.play("pop"); Fx.burst("spark", fx, fy, 10, 160, 0.7, 9) end
                end
            end
        end
        if not o.doneT and o.fires[1] + o.fires[2] + o.fires[3] == 0 then
            o.doneT = o.t
            Snd.loop("spray", false)
            Snd.play("cheer")
            Snd.voice("fire1_done")
            Fx.burst("confetti", 420, 200, 50, 260, 2.5, 12)
        end
        return o.doneT ~= nil and o.t - o.doneT > 3
    end

    function o.draw()
        if o.phase == "drive" then Kit.drawDrive(o.drive); Fx.draw(); return end
        local t = o.t
        Kit.sky("town", t)
        Kit.clouds(t, 0)
        Kit.hills(0, 230)
        Dr.color(C.road); lg.rectangle("fill", 0, GROUND, Dr.W, 80)
        Dr.color(C.grass); lg.rectangle("fill", 0, GROUND + 30, Dr.W, 60)
        drawHouse(HOUSE_X, GROUND, t, o.fires, false)
        Ve.draw("fire", 110, GROUND + 18, 0.8, t, { siren = true, ladder = 0.15 })
        -- шланг до прицілу
        Dr.line(C.yellow, 6, 150, 360, 168, 318)
        Dr.circle(168, 318, 7, C.grey)
        Fx.draw()
        if o.doneT then
            Kit.thanks("hedgehog", 380, 360, t)
        else
            -- приціл
            local pulse = 1 + math.sin(t * 6) * 0.08
            lg.setLineWidth(4)
            Dr.color(C.white, 0.9)
            lg.circle("line", o.aimX, o.aimY, 22 * pulse, 32)
            Dr.color(C.blue, 0.9)
            lg.circle("fill", o.aimX, o.aimY, 5, 12)
            if o.idle > 2 then
                -- підказка: тримай A і наводь на вогник
                local k = 1
                for i = 1, 3 do if o.fires[i] > 0 then k = i; break end end
                local fx, fy = WINDOWS[k][1], WINDOWS[k][2]
                if k == 3 then fx, fy = HOUSE_X + 75, GROUND - 20 end
                Dr.arrow(fx, fy - 90, 0, 1.2, C.yellow, t)
                Dr.buttonA(70, 420, 1.1, t)
            end
        end
        -- скільки вогників лишилось
        Dr.rrect(14, 12, 150, 44, 16, C.panel)
        for i = 1, 3 do
            if o.fires[i] > 0 then Dr.flame(40 + (i - 1) * 44, 48, 0.8, t, 1)
            else Dr.circle(40 + (i - 1) * 44, 34, 12, C.green); Dr.star(40 + (i - 1) * 44, 34, 7, C.white) end
        end
    end

    function o.stars()
        local d = o.drive
        local s = 3
        if d.got < d.total / 2 then s = s - 1 end
        if d.bumped >= 3 then s = s - 1 end
        return math.max(1, s)
    end

    -- бот для автотесту: їде, ловить зірочки, гасить вогники по черзі
    function o.bot()
        if o.phase == "drive" then
            In.press("right")
            local carX = o.drive.x + 160
            for _, it in ipairs(o.drive.items) do
                if not it.taken and it.x > carX and it.x < carX + 260 then
                    local want = (it.kind == "star") and it.lane or (3 - it.lane)
                    if want ~= o.drive.lane then In.press(want == 1 and "up" or "down"); In.release(want == 1 and "up" or "down") end
                    break
                end
            end
            return
        end
        In.release("right")
        for k = 1, 3 do
            if o.fires[k] > 0 then
                local fx, fy = WINDOWS[k][1], WINDOWS[k][2]
                if k == 3 then fx, fy = HOUSE_X + 75, GROUND - 20 end
                o.aimX, o.aimY = fx, fy
                In.press("a")
                return
            end
        end
        In.release("a")
    end

    function o.leave() Snd.loop("siren", false); Snd.loop("spray", false) end

    return o
end

return M
