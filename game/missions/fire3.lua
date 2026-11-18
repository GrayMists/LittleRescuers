-- Пожежна 3: «Пекарня Свинки». Вогники спалахують на даху по черзі, води в бочці мало:
-- їдь уздовж пекарні (вліво/вправо), тримай A — вода; коли бочка порожня — до гідранта, A — набрати.
local Dr = require("core.draw")
local Ve = require("core.vehicles")
local In = require("core.input")
local Snd = require("core.sound")
local Fx = require("core.fx")
local Kit = require("missions.kit")
local lg = love.graphics
local C = Dr.C

local M = {
    id = "fire3", vehicle = "fire", rescued = "pig",
    intro = "fire3_intro",
    icon = function(x, y, s, t)
        Dr.house(x - 30 * s, y + 34 * s, 60 * s, 36 * s, C.orange)
        Dr.rrect(x + 8 * s, y - 24 * s, 10 * s, 22 * s, 3 * s, C.brown)
        Dr.flame(x - 6 * s, y - 4 * s, 0.8 * s, t)
        Dr.cloud(x + 22 * s, y - 36 * s, 0.35 * s, 0.9)
    end,
}

local TRUCK_Y, SC = 452, 0.8
local AIM = 190                       -- на скільки праворуч від машини б'є струмінь
local HX, HBASE = 370, 400            -- пекарня: ліва стіна, земля
local HYDRANT = { 50, 478 }
local TOTAL = 6
local FIRES = { { 552, 178 }, { 430, 232 }, { 500, 205 }, { 590, 235 }, { 405, 245 }, { 470, 190 } }

local function roofY(x)
    local d = math.abs(x - (HX + 130)) / 150
    return 250 - math.max(0, 1 - d) * 80
end

local function drawBakery(x, y, t, fires, pigMood, smoke)
    -- x, y — ліва стіна / земля
    Dr.shadow(x + 120, y + 2, 150, 14)
    Dr.rrect(x, y - 150, 240, 150, 12, C.cream)
    Dr.rrect(x + 160, y - 220, 32, 80, 6, C.brown)               -- димар
    Dr.poly({ x - 20, y - 146, x + 260, y - 146, x + 130, y - 230 }, C.orange)
    Dr.rrect(x + 156, y - 232, 40, 14, 4, Dr.shade(C.brown, -0.2))
    -- вивіска-бублик
    Dr.circle(x + 120, y - 118, 18, Dr.hex(0xE8B35A))
    Dr.circle(x + 120, y - 118, 7, C.cream, 1, true)
    -- вікно зі Свинкою
    Dr.window(x + 30, y - 110, 70, 60, false)
    Dr.animal("pig", x + 65, y - 78, 0.8, t, pigMood)
    Dr.rrect(x + 150, y - 70, 50, 70, 16, C.brown)
    -- смугастий навіс
    for k = 0, 5 do Dr.rrect(x + 30 + k * 12, y - 52, 12, 10, 3, k % 2 == 0 and C.red or C.white, 1, true) end
    if fires then
        for _, f in ipairs(fires) do
            if f.size > 0 then Dr.flame(f.x, f.y, 1.3, t, f.size * f.grow) end
        end
    end
    if smoke and math.floor(t * 8) % 3 == 0 then Fx.add("smoke", x + 176, y - 232, 8, -40, 2.2, 10) end
end

function M.new()
    local o = { phase = "drive", t = 0, tx = 250, tank = 0.8, fires = {}, spawned = 0, spawnT = 0, spray = false,
        filling = false, idle = 0, doneT = nil, hinted = false, refilled = 0 }
    o.drive = Kit.newDrive({
        vehicle = "fire", length = 3000, theme = "town", stars = 8, bumps = 4, seed = 33, obstacle = "puddle",
        goal = function(x, y, t) drawBakery(x, y + 100, t, nil, "sad", true) end,
    })

    function o.active()
        local n = 0
        for _, f in ipairs(o.fires) do if f.size > 0 then n = n + 1 end end
        return n
    end

    function o.update(dt)
        o.t = o.t + dt
        if o.phase == "drive" then
            Snd.loop("siren", true, 0.5)
            if Kit.updateDrive(o.drive, dt) then
                o.phase = "spray"
                Snd.loop("siren", false)
                Snd.voice("fire3_spray")
            end
            return false
        end
        local dx = In.axis()
        o.tx = math.max(95, math.min(440, o.tx + dx * 190 * dt))
        local a = In.down("a") and not o.doneT
        o.idle = (dx == 0 and not a) and o.idle + dt or 0
        local atHydrant = o.tx < 150
        o.filling = a and atHydrant and o.tank < 1
        o.spray = a and not atHydrant and o.tank > 0
        local empty = a and not atHydrant and o.tank <= 0
        if o.filling then
            o.tank = math.min(1, o.tank + dt * 0.4)
            if math.floor(o.t * 10) % 2 == 0 then Fx.add("bubble", HYDRANT[1] + 10, HYDRANT[2] - 40, love.math.random(-15, 15), -60, 0.8, 5) end
        end
        Snd.loop("spray", o.spray or o.filling, 0.6)
        -- вогники з'являються по черзі
        o.spawnT = o.spawnT + dt
        if o.spawned < TOTAL and o.spawnT > (o.spawned == 0 and 1 or 3.5) and o.active() < 2 then
            o.spawnT = 0
            o.spawned = o.spawned + 1
            local p = FIRES[o.spawned]
            table.insert(o.fires, { x = p[1], y = p[2], size = 1, grow = 0 })
            Snd.play("pop")
        end
        for _, f in ipairs(o.fires) do f.grow = math.min(1, f.grow + dt * 1.2) end
        -- струмінь
        local aimX = o.tx + AIM
        local nx, ny = o.tx - 8, TRUCK_Y - 66
        if o.spray then
            o.tank = math.max(0, o.tank - dt * 0.22)
            local ax, ay = aimX, roofY(aimX) - 20
            local tgt
            for _, f in ipairs(o.fires) do
                if f.size > 0 and math.abs(f.x - aimX) < 40 then tgt = f end
            end
            if tgt then ax, ay = tgt.x, tgt.y - 10 end
            for _ = 1, 3 do
                local tx, ty = ax + love.math.random(-8, 8), ay + love.math.random(-8, 8)
                local tt = 0.5
                Fx.add("drop", nx, ny, (tx - nx) / tt, (ty - ny) / tt - 0.5 * 600 * tt, tt, 4 + love.math.random() * 3)
            end
            if tgt then
                tgt.size = math.max(0, tgt.size - dt * 0.7)
                if math.floor(o.t * 10) % 2 == 0 then Fx.add("smoke", tgt.x, tgt.y - 30, love.math.random(-20, 20), -50, 1.2, 8) end
                if tgt.size == 0 then Snd.play("pop"); Fx.burst("spark", tgt.x, tgt.y, 10, 160, 0.7, 9) end
            end
        elseif empty and math.floor(o.t * 8) % 3 == 0 then
            Fx.add("smoke", nx, ny, 20, -30, 0.5, 4)
        end
        if o.tank <= 0.02 and not o.hinted and not o.doneT then o.hinted = true; Snd.voice("fire3_hint") end
        if o.tank > 0.3 then o.hinted = false end
        if not o.doneT and o.spawned == TOTAL and o.active() == 0 then
            o.doneT = o.t
            Snd.loop("spray", false)
            Snd.play("cheer"); Snd.voice("fire3_done")
            Fx.burst("confetti", 480, 200, 50, 260, 2.5, 12)
        end
        return o.doneT ~= nil and o.t - o.doneT > 3
    end

    local function drawHydrant(t, glow)
        local x, y = HYDRANT[1], HYDRANT[2]
        Dr.shadow(x, y + 4, 22, 6)
        if glow then Dr.circle(x, y - 24, 36 + math.sin(t * 8) * 3, C.yellow, 0.3, true) end
        Dr.rrect(x - 13, y - 44, 26, 46, 8, C.red)
        Dr.rrect(x - 17, y - 52, 34, 14, 7, C.redD)
        Dr.rrect(x - 21, y - 26, 42, 12, 5, C.red)
        Dr.circle(x, y - 20, 5, C.yellow)
    end

    function o.draw()
        if o.phase == "drive" then Kit.drawDrive(o.drive); Fx.draw(); return end
        local t = o.t
        Kit.sky("town", t)
        Kit.clouds(t, 0)
        Kit.hills(0, 230)
        Dr.tree(300, 360, 0.9, t)
        Dr.color(C.grass); lg.rectangle("fill", 0, 360, Dr.W, 60)
        Dr.color(C.roadD); lg.rectangle("fill", 0, 406, Dr.W, 80)
        Dr.color(C.road); lg.rectangle("fill", 0, 412, Dr.W, 68)
        Dr.color(C.line)
        for k = 0, 8 do lg.rectangle("fill", k * 80 + 10, 470, 44, 5, 2, 2) end
        drawBakery(HX, HBASE, t, o.fires, o.doneT and "happy" or "sad", o.doneT == nil)
        local needWater = o.tank <= 0.02 and not o.doneT
        Ve.draw("fire", o.tx, TRUCK_Y, SC, t, { siren = true })
        drawHydrant(t, needWater)
        -- шланг до гідранта
        if o.filling then
            lg.setLineWidth(7); Dr.color(C.yellow)
            lg.line(HYDRANT[1] + 14, HYDRANT[2] - 16, o.tx - 30, TRUCK_Y - 30)
        end
        -- приціл на даху: де вдарить вода
        if not o.doneT and o.tx >= 150 then
            local ax = o.tx + AIM
            local pulse = 1 + math.sin(t * 6) * 0.08
            lg.setLineWidth(3); Dr.color(C.white, 0.8)
            lg.circle("line", ax, roofY(ax) - 20, 18 * pulse, 28)
        end
        Fx.draw()
        -- підказки
        if o.idle > 2 and not o.doneT then
            if needWater then
                if o.tx >= 150 then Dr.arrow(o.tx - 30, 340, 1, 1.3, C.yellow, t) else Dr.buttonA(HYDRANT[1] + 110, 380, 1.1, t) end
            else
                local tgt
                for _, f in ipairs(o.fires) do if f.size > 0 then tgt = f; break end end
                if tgt then
                    if math.abs(o.tx + AIM - tgt.x) < 40 then Dr.buttonA(70, 300, 1.1, t); Dr.arrow(tgt.x, tgt.y - 50, 0, 1.2, C.yellow, t)
                    else Dr.arrow(o.tx - 30, 340, (tgt.x > o.tx + AIM) and 3 or 1, 1.3, C.yellow, t) end
                end
            end
        end
        -- бочка з водою
        Dr.rrect(14, 12, 120, 44, 16, C.panel)
        Dr.circle(38, 34, 15, C.water)
        Dr.poly({ 38, 16, 28, 34, 48, 34 }, C.water, 1, true)
        Dr.rrect(60, 22, 64, 20, 8, C.white)
        local low = o.tank < 0.25 and math.floor(t * 4) % 2 == 0
        if o.tank > 0.01 then Dr.rrect(62, 24, 60 * o.tank, 16, 6, low and C.red or C.water, 1, true) end
        -- вогники: скільки вже згасло
        Dr.rrect(144, 12, 6 + TOTAL * 30, 44, 16, C.panel)
        for i = 1, TOTAL do
            local f = o.fires[i]
            local cx = 162 + (i - 1) * 30
            if f and f.size <= 0 then Dr.circle(cx, 34, 11, C.green); Dr.star(cx, 34, 6, C.white)
            else Dr.circle(cx, 34, 11, Dr.hex(0xE0D8C8), f and 1 or 0.6, true) end
        end
    end

    function o.stars()
        local d = o.drive
        local s = 3
        if d.got < d.total / 2 then s = s - 1 end
        if d.bumped >= 3 then s = s - 1 end
        return math.max(1, s)
    end

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
        for _, kk in ipairs({ "right", "left", "a" }) do In.release(kk) end
        local tgt
        for _, f in ipairs(o.fires) do if f.size > 0 then tgt = f; break end end
        local needFill = o.tank <= 0.02 or (o.refill and o.tank < 0.95)
        o.refill = needFill and o.tank < 0.95
        if needFill or (not tgt and o.tank < 0.4 and o.spawned < TOTAL) then
            o.refill = true
            if o.tx > 120 then In.press("left") else In.press("a") end
            return
        end
        if not tgt then return end
        local d = (tgt.x - AIM) - o.tx
        if d > 8 then In.press("right") elseif d < -8 then In.press("left") end
        if math.abs(d) < 25 and tgt.grow > 0.3 then In.press("a") end
    end

    function o.leave() Snd.loop("siren", false); Snd.loop("spray", false) end

    return o
end

return M
