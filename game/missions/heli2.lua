-- Вертоліт 2: «Пожежа в лісі». Низько над озером набрати води у відро, летіти до палаючого
-- дерева й натиснути A — вода виливається. 5 вогників.
local Dr = require("core.draw")
local In = require("core.input")
local Snd = require("core.sound")
local Fx = require("core.fx")
local Kit = require("missions.kit")
local HK = require("missions.heli_kit")
local lg = love.graphics
local C = Dr.C

local M = {
    id = "heli2", vehicle = "heli", rescued = "squirrel",
    intro = "heli2_intro",
    icon = function(x, y, s, t)
        Dr.tree(x - 10 * s, y + 40 * s, 0.9 * s, t, "pine")
        Dr.flame(x - 10 * s, y - 14 * s, 1.1 * s, t)
        Dr.rrect(x + 22 * s, y + 4 * s, 26 * s, 24 * s, 6, C.red)
    end,
}

local WATER_Y, LAKE_X1 = 400, 250
-- x, y основи дерева, масштаб, вид
local TREES = { { 330, 420, 1.0, "pine" }, { 400, 430, 1.25, "tree" }, { 470, 415, 1.0, "pine" }, { 545, 432, 1.2, "tree" }, { 610, 418, 0.9, "pine" } }
local function fireSpot(k)
    local tr = TREES[k]
    local s = tr[3]
    return tr[1], tr[2] - (tr[4] == "pine" and 90 or 100) * s
end

function M.new()
    local o = { t = 0, h = HK.new(300, 150), fill = 0, fires = { 1, 1, 1, 1, 1 }, out = 0, doneT = nil, idle = 0, flash = 0 }
    o.back = {
        HK.ridge(21, 330, 90, Dr.hex(0x9CD2A8), Dr.hex(0xB9E2C0)),
        HK.ridge(33, 400, 70, Dr.hex(0x6DBF8A), Dr.hex(0x8ED7A4)),
    }
    local ROPE = 78

    local function nearestFire(h)
        local best, bd
        for k = 1, 5 do
            if o.fires[k] > 0 then
                local fx = fireSpot(k)
                local d = math.abs(fx - h.x)
                if not bd or d < bd then best, bd = k, d end
            end
        end
        return best, bd
    end

    function o.update(dt)
        o.t = o.t + dt
        local h = o.h
        local dx, dy = HK.update(h, dt, { x0 = 40, x1 = 610, y0 = 90, y1 = 375, speed = 190 })
        local bx, by = HK.basketPos(h, ROPE)
        o.idle = (dx == 0 and dy == 0) and o.idle + dt or 0
        o.flash = math.max(0, o.flash - dt)
        -- набираємо воду: дно відра у воді над озером
        if by >= WATER_Y - 4 and bx < LAKE_X1 and not o.doneT then
            if o.fill < 1 then
                o.fill = math.min(1, o.fill + dt * 0.55)
                if math.floor(o.t * 12) % 2 == 0 then Fx.add("bubble", bx + love.math.random(-12, 12), WATER_Y, 0, -30, 0.7, 4) end
                if o.fill >= 1 then Snd.play("ding") end
            end
            if math.floor(o.t * 10) % 3 == 0 then Fx.add("drop", bx, WATER_Y, love.math.random(-60, 60), -120, 0.5, 3) end
        end
        for k = 1, 5 do
            if o.fires[k] > 0 and math.floor(o.t * 6 + k) % 3 == 0 then
                local fx, fy = fireSpot(k)
                Fx.add("smoke", fx + love.math.random(-6, 6), fy - 20, love.math.random(-8, 18), -45, 1.6, 8)
            end
        end
        return o.doneT ~= nil and o.t - o.doneT > 3
    end

    -- A — вилити воду
    function o.press(name)
        if name ~= "a" or o.doneT or o.fill < 0.12 then return end
        local h = o.h
        local bx, by = HK.basketPos(h, ROPE)
        local amount = o.fill
        o.fill = 0
        Snd.play("splash")
        local target
        for k = 1, 5 do
            local fx, fy = fireSpot(k)
            if o.fires[k] > 0 and math.abs(fx - bx) < 62 and (not target or math.abs(fx - bx) < math.abs(fireSpot(target) - bx)) then target = k end
        end
        local gy = target and select(2, fireSpot(target)) + 20 or 420
        for _ = 1, 18 do
            local tt = 0.35 + love.math.random() * 0.2
            local tx = bx + love.math.random(-18, 18)
            Fx.add("drop", bx + love.math.random(-10, 10), by - 22, (tx - bx) / tt * 0.5, (gy - by) / tt - 0.5 * 600 * tt, tt, 4 + love.math.random() * 3)
        end
        if target then
            local fx, fy = fireSpot(target)
            -- повне відро гасить вогник, неповне — зменшує
            o.fires[target] = math.max(0, o.fires[target] - amount * 1.3)
            if o.fires[target] <= 0 then
                Snd.play("pop"); Fx.burst("spark", fx, fy, 12, 170, 0.8, 9)
                o.out = o.out + 1
                if o.out == 5 then
                    o.doneT = o.t
                    Snd.play("cheer"); Snd.voice("heli2_done")
                    Fx.burst("confetti", 320, 200, 50, 260, 2.5, 12)
                end
            end
        end
    end

    function o.draw()
        local t, h = o.t, o.h
        Kit.sky("town", t)
        Kit.clouds(t, 0)
        for _, r in ipairs(o.back) do HK.drawRidge(r) end
        Dr.color(C.grass); lg.rectangle("fill", 0, 410, Dr.W, 80)
        -- озеро
        Dr.color(C.waterD); lg.rectangle("fill", 0, WATER_Y - 2, LAKE_X1 + 20, 90, 0, 0)
        Dr.color(C.water); lg.rectangle("fill", 0, WATER_Y, LAKE_X1 + 10, 90)
        Dr.circle(LAKE_X1 + 10, WATER_Y + 40, 40, C.water, 1, true)
        lg.setColor(1, 1, 1, 0.5); lg.setLineWidth(3)
        for k = 0, 3 do lg.line(20 + k * 60 + math.sin(t * 2 + k) * 6, WATER_Y + 18 + (k % 2) * 22, 50 + k * 60 + math.sin(t * 2 + k) * 6, WATER_Y + 18 + (k % 2) * 22) end
        Dr.color(C.grass); lg.rectangle("fill", 0, 470, Dr.W, 20)
        -- ліс
        for k, tr in ipairs(TREES) do
            Dr.tree(tr[1], tr[2], tr[3], t, tr[4])
            if o.fires[k] > 0 then
                local fx, fy = fireSpot(k)
                lg.setColor(0.15, 0.05, 0, 0.35 * o.fires[k])
                lg.circle("fill", fx, fy + 20, 34 * tr[3], 20)
                Dr.flame(fx, fy + 28, 1.5 * tr[3], t, 0.4 + 0.6 * o.fires[k])
            end
        end
        Dr.bush(310, 440, 1); Dr.bush(500, 450, 1.1)
        Fx.draw()
        HK.drawRope(h, 78, "bucket", o.fill, t)
        HK.draw(h, t, 0.55)
        if o.doneT then
            Kit.thanks("squirrel", 330, 130 + 210, t)
        elseif o.idle > 2 then
            local k = nearestFire(h)
            if o.fill < 0.5 then
                Dr.arrow(120, 330, 0, 1.2, C.yellow, t)
            elseif k then
                local fx, fy = fireSpot(k)
                Dr.arrow(fx, fy - 70, 0, 1.2, C.yellow, t)
                Dr.buttonA(fx + 34, fy - 76, 1, t)
            end
        end
        -- табло: вогники й відро з водою
        Dr.rrect(14, 12, 230, 44, 16, C.panel)
        for i = 1, 5 do
            local x = 36 + (i - 1) * 32
            if o.fires[i] > 0 then Dr.flame(x, 46, 0.6, t, 1)
            else Dr.circle(x, 34, 10, C.green); Dr.star(x, 34, 6, C.white) end
        end
        -- шкала води
        Dr.rrect(520, 12, 100, 28, 12, C.panel)
        Dr.rrect(528, 20, 84 * o.fill, 12, 6, C.water, 1, true)
        Dr.circle(530, 26, 10, C.water)
    end

    function o.stars() return o.t < 150 and 3 or 2 end

    function o.bot()
        local h = o.h
        local ropeY = 4 + 78
        if o.fill < 0.99 then
            HK.botRelease()
            HK.botMove(h, 120, WATER_Y - ropeY + 20, 10)
            return
        end
        local k = nearestFire(h)
        if not k then HK.botRelease(); return end
        local fx, fy = fireSpot(k)
        local ok = HK.botMove(h, fx, math.min(fy - 30, 300), 10)
        if ok and math.abs(h.x - fx) < 30 then In.press("a"); In.release("a") end
    end

    function o.leave() HK.stop() end

    return o
end

return M
