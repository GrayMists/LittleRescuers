-- Поліція 2: «Світлофор зламався». Зоя — регулювальниця на перехресті (вигляд зверху).
-- Натисни стрілочку в той бік, звідки стоять машинки, — вони поїдуть, а решта почекає.
-- Автобус із каченятами й швидка проїжджають першими. 12 машинок проїхали — готово.
local Dr = require("core.draw")
local In = require("core.input")
local Snd = require("core.sound")
local Fx = require("core.fx")
local PK = require("missions.police_kit")
local lg = love.graphics
local C = Dr.C

local M = {
    id = "police2", vehicle = "police", rescued = "duck",
    intro = "police2_intro",
    icon = function(x, y, s, t)
        Dr.rrect(x - 50 * s, y - 14 * s, 100 * s, 28 * s, 4, C.road, 1, true)
        Dr.rrect(x - 14 * s, y - 50 * s, 28 * s, 100 * s, 4, C.road, 1, true)
        PK.car(x - 34 * s, y + 6 * s, 0, 0.5 * s, t, { kind = "bus" })
        PK.car(x + 6 * s, y - 36 * s, math.pi / 2, 0.45 * s, t, { kind = "car", color = C.red })
        Dr.circle(x + 36 * s, y - 34 * s, 9 * s, math.floor(t * 2) % 2 == 0 and C.red or C.green)
    end,
}

local BX0, BX1, BY0, BY1 = 270, 370, 190, 290
local TOTAL = 12
-- смуги: звідки їдуть (L — зліва направо, R — справа наліво, T — зверху вниз, B — знизу вгору)
local LANES = {
    { key = "left",  x = -80, y = 265, dx = 1, dy = 0, line = 342, stop = { 262, 265 } },
    { key = "right", x = 720, y = 215, dx = -1, dy = 0, line = 342, stop = { 378, 215 } },
    { key = "up",    x = 295, y = -80, dx = 0, dy = 1, line = 262, stop = { 295, 182 } },
    { key = "down",  x = 345, y = 560, dx = 0, dy = -1, line = 262, stop = { 345, 298 } },
}
local BOXLEN = 100
local DRIVERS = { "cat", "dog", "bear", "fox", "pig", "hedgehog" }
local COLORS = { C.red, C.green, C.orange, C.purple, C.pink, C.blue }

local function pos(c)
    local l = LANES[c.lane]
    return l.x + l.dx * c.s, l.y + l.dy * c.s
end
local function ang(c)
    local l = LANES[c.lane]
    return math.atan2(l.dy, l.dx)
end

local function inBox(c)
    local l = LANES[c.lane]
    return c.s + c.len / 2 > l.line and c.s - c.len / 2 < l.line + BOXLEN
end

function M.new()
    local o = { t = 0, cars = {}, passed = 0, green = nil, idle = 0, spawnT = 0, nextSpawn = 7,
        busVoiced = false, ambVoiced = false, prioWait = { 0, 0 }, doneT = nil, hintVoiced = false }
    -- порядок появи: по три машинки з кожного боку, автобус і швидка серед них
    local rnd = love.math.newRandomGenerator(7)
    local lanes = { 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4 }
    for k = #lanes, 2, -1 do local j = rnd:random(k); lanes[k], lanes[j] = lanes[j], lanes[k] end
    o.plan = {}
    for k = 1, TOTAL do
        local kind = (k == 3) and "bus" or (k == 8) and "ambulance" or "car"
        table.insert(o.plan, { lane = lanes[k], kind = kind, color = COLORS[rnd:random(#COLORS)], driver = DRIVERS[rnd:random(#DRIVERS)] })
    end
    o.spawned = 0

    local function laneCars(l)
        local out = {}
        for _, c in ipairs(o.cars) do if c.lane == l then table.insert(out, c) end end
        table.sort(out, function(a, b) return a.s > b.s end)
        return out
    end

    local function spawn(preload)
        local p = o.plan[o.spawned + 1]
        if not p then return false end
        local len = (p.kind == "bus") and 112 or (p.kind == "ambulance") and 76 or 64
        local l = LANES[p.lane]
        local last = laneCars(p.lane)
        last = last[#last]
        local s
        if preload then
            s = last and (last.s - last.len / 2 - len / 2 - 14) or (l.line - len / 2 - 2)
        else
            s = 0
            if last and last.s - last.len / 2 < s + len / 2 + 16 then return false end
        end
        o.spawned = o.spawned + 1
        table.insert(o.cars, { lane = p.lane, s = s, v = 0, len = len, kind = p.kind, color = p.color, driver = p.driver,
            vmax = (p.kind == "bus") and 120 or (p.kind == "ambulance") and 190 or 150 + (o.spawned % 3) * 12,
            prio = (p.kind ~= "car") and (p.kind == "bus" and 1 or 2) or nil, wait = 0, passed = false })
        return true
    end
    for _ = 1, 6 do spawn(true) end

    local function pick(lane)
        if o.green ~= lane then
            o.green = lane
            Snd.play("pop")
        end
        o.idle = 0
    end

    function o.press(name)
        for k, l in ipairs(LANES) do if l.key == name then pick(k) end end
    end

    local function waitingCount(k)
        local n = 0
        for _, c in ipairs(o.cars) do
            local l = LANES[c.lane]
            if c.lane == k and c.s + c.len / 2 <= l.line + 0.5 then n = n + 1 end
        end
        return n
    end

    local function boxBlocked(lane)
        for _, c in ipairs(o.cars) do if c.lane ~= lane and inBox(c) then return true end end
        return false
    end

    function o.update(dt)
        o.t = o.t + dt
        local dx, dy = In.axis()
        o.idle = (dx ~= 0 or dy ~= 0) and 0 or o.idle + dt
        -- поява нових машинок
        if o.spawned < TOTAL then
            o.spawnT = o.spawnT + dt
            if o.spawnT > 2.2 then
                local before = o.spawned
                -- не більше 3 машин у черзі з одного боку
                local p = o.plan[o.spawned + 1]
                if waitingCount(p.lane) < 3 and spawn(false) then o.spawnT = 0 end
                if before == o.spawned then o.spawnT = 1.8 end
            end
        end
        -- рух по смугах
        for k, l in ipairs(LANES) do
            local list = laneCars(k)
            local ok = (o.green == k) and not boxBlocked(k)
            for i, c in ipairs(list) do
                local limit = math.huge
                if i > 1 then limit = list[i - 1].s - list[i - 1].len / 2 - c.len / 2 - 14 end
                local fs = c.s + c.len / 2
                if fs <= l.line + 0.5 and not ok then limit = math.min(limit, l.line - c.len / 2 - 2) end
                local vt = math.min(c.vmax, math.max(0, (limit - c.s) * 4))
                c.v = c.v + (vt - c.v) * math.min(1, dt * 6)
                c.s = c.s + c.v * dt
                if c.s > limit then c.s = limit; c.v = 0 end
                if c.prio and c.v < 8 and fs <= l.line + 1 and i == 1 then c.wait = c.wait + dt end
                if not c.passed and c.s > l.line + BOXLEN / 2 then
                    c.passed = true
                    o.passed = o.passed + 1
                    if c.prio then o.prioWait[c.prio] = c.wait end
                    Snd.play("horn")
                    local cx, cy = pos(c)
                    Fx.burst("spark", cx, cy, 6, 110, 0.6, 7)
                    Fx.add("spark", cx, cy - 20, 0, -50, 0.9, 9)
                end
            end
        end
        for n = #o.cars, 1, -1 do
            if o.cars[n].s > LANES[o.cars[n].lane].line + BOXLEN + 160 then table.remove(o.cars, n) end
        end
        -- голос про автобус і швидку
        if not o.busVoiced and o.t > 5 then
            for _, c in ipairs(o.cars) do if c.kind == "bus" and not c.passed then o.busVoiced = true; Snd.voice("police2_bus") end end
        end
        if not o.ambVoiced then
            for _, c in ipairs(o.cars) do
                if c.kind == "ambulance" and not c.passed and c.s > 0 then o.ambVoiced = true; Snd.voice("police2_amb") end
            end
        end
        if o.idle > 5 and not o.hintVoiced then o.hintVoiced = true; Snd.voice("police2_hint") end
        if o.idle < 1 then o.hintVoiced = false end
        if not o.doneT and o.passed >= TOTAL then
            o.doneT = o.t
            Snd.play("cheer")
            Snd.voice("police2_done")
            Fx.burst("confetti", 320, 240, 60, 280, 2.8, 12)
        end
        return o.doneT ~= nil and o.t - o.doneT > 3.2
    end

    -- ---------- малювання ----------
    local function drawScene(t)
        Dr.color(C.grass); lg.rectangle("fill", 0, 0, Dr.W, Dr.H)
        -- кути: будинки, дерева, ставок
        PK.house(40, 40, 110, 80, C.blue)
        PK.house(160, 70, 70, 60, C.orange)
        PK.tree(40, 150, 24)
        PK.tree(430, 50, 26)
        Dr.ellipse(520, 100, 70, 40, C.water)
        Dr.ellipse(505, 90, 26, 10, C.foam, 0.6, true)
        PK.tree(590, 150, 22)
        PK.house(40, 340, 100, 80, C.purple)
        PK.tree(190, 410, 24)
        PK.house(430, 350, 110, 80, C.red)
        PK.house(560, 330, 60, 70, C.green)
        PK.tree(410, 440, 20)
        PK.bush(240, 330, 14)
        -- дороги
        local sw = Dr.hex(0xE9E0C8)
        Dr.color(sw)
        lg.rectangle("fill", 0, BY0 - 8, Dr.W, 116)
        lg.rectangle("fill", BX0 - 8, 0, 116, Dr.H)
        Dr.color(C.road)
        lg.rectangle("fill", 0, BY0, Dr.W, 100)
        lg.rectangle("fill", BX0, 0, 100, Dr.H)
        Dr.color(C.line)
        for x = 8, 634, 48 do if x + 26 < BX0 - 4 or x > BX1 + 4 then lg.rectangle("fill", x, 237, 26, 6, 3, 3) end end
        for y = 8, 474, 48 do if y + 26 < BY0 - 4 or y > BY1 + 4 then lg.rectangle("fill", 317, y, 6, 26, 3, 3) end end
        -- зебри
        Dr.color(C.white, 0.85)
        for k = 0, 5 do
            lg.rectangle("fill", BX0 - 30, BY0 + 6 + k * 16, 20, 9, 2, 2)
            lg.rectangle("fill", BX1 + 10, BY0 + 6 + k * 16, 20, 9, 2, 2)
            lg.rectangle("fill", BX0 + 6 + k * 16, BY0 - 30, 9, 20, 2, 2)
            lg.rectangle("fill", BX0 + 6 + k * 16, BY1 + 10, 9, 20, 2, 2)
        end
        -- стоп-лінії: червоні чекають, зелена — їдь
        for k, l in ipairs(LANES) do
            local green = (o.green == k)
            local col = green and C.green or C.red
            local pulse = 0.5 + 0.5 * math.sin(t * 6)
            local sx, sy = l.stop[1], l.stop[2]
            local horiz = l.dx ~= 0
            local w, h = horiz and 8 or 48, horiz and 48 or 8
            if green then Dr.color(C.green, 0.25 + 0.2 * pulse); lg.rectangle("fill", sx - w / 2 - 6, sy - h / 2 - 6, w + 12, h + 12, 8, 8) end
            Dr.rrect(sx - w / 2, sy - h / 2, w, h, 4, col)
        end
    end

    local function drawBunny(t)
        local bx, by = 222, 128
        Dr.shadow(bx, by + 52, 28, 8)
        Dr.rrect(bx - 18, by + 18, 36, 34, 12, C.blue)
        Dr.star(bx, by + 34, 7, C.gold)
        -- рука-жезл у бік зеленої смуги
        local tx, ty = bx, by - 80
        if o.green then tx, ty = LANES[o.green].stop[1], LANES[o.green].stop[2] end
        local a = math.atan2(ty - (by + 28), tx - (bx + 14))
        local ex, ey = bx + 14 + math.cos(a) * 40, by + 28 + math.sin(a) * 40
        Dr.line(C.blueD, 9, bx + 14, by + 28, ex, ey)
        Dr.line(C.white, 6, bx + 14, by + 28, ex, ey)
        Dr.circle(ex, ey, 9, o.green and C.green or C.red)
        Dr.animal("bunny", bx, by, 1.0, t, "happy", "police")
        -- зламаний світлофор
        Dr.rrect(252, 112, 12, 66, 4, C.dark)
        Dr.rrect(244, 96, 28, 36, 8, C.dark)
        for k = 0, 2 do Dr.circle(258, 104 + k * 11, 4.5, C.grey, 1, true) end
        if math.floor(t * 5) % 3 == 0 then Dr.star(274, 96, 7, C.yellow, 1, t) end
    end

    function o.draw()
        local t = o.t
        drawScene(t)
        -- машинки: спершу ті, що в черзі, потім усі
        for _, c in ipairs(o.cars) do
            local x, y = pos(c)
            if x > -90 and x < 730 and y > -90 and y < 570 then
                PK.car(x, y, ang(c), 1, t, { kind = c.kind, color = c.color, driver = c.driver, siren = true })
            end
        end
        drawBunny(t)
        -- пріоритетні машини: стрілочка, що блимає
        for _, c in ipairs(o.cars) do
            if c.prio and not c.passed then
                local x, y = pos(c)
                if x > 10 and x < 630 and y > 10 and y < 470 and math.floor(t * 4) % 2 == 0 then
                    Dr.circle(x, y, 48, c.prio == 1 and C.yellow or C.red, 0.3, true)
                    Dr.arrow(x, y - 52, 0, 1.0, c.prio == 1 and C.yellow or C.red, t)
                end
            end
        end
        -- підказка: де чекають, куди тиснути
        if o.idle > 3 and not o.doneT then
            local best, bestN = nil, 0
            for k = 1, 4 do
                local n = waitingCount(k)
                if k ~= o.green and n > bestN then best, bestN = k, n end
            end
            if not best and o.green and waitingCount(o.green) == 0 then
                for k = 1, 4 do if waitingCount(k) > 0 then best = k end end
            end
            if best then
                PK.dpad(580, 420, 1.0, LANES[best].key, t)
                local sx, sy = LANES[best].stop[1], LANES[best].stop[2]
                Dr.circle(sx, sy, 20 + math.sin(t * 6) * 4, C.yellow, 0.4, true)
            end
        end
        Fx.draw()
        -- табло: 12 кружечків
        Dr.rrect(160, 10, 320, 34, 16, C.panel)
        for k = 1, TOTAL do
            local cx = 180 + (k - 1) * 26
            if k <= o.passed then Dr.circle(cx, 27, 10, C.green); Dr.star(cx, 27, 6, C.white)
            else Dr.circle(cx, 27, 9, Dr.hex(0xD6D0C4), 1, true) end
        end
    end

    function o.stars()
        local s = 3
        if o.prioWait[1] > 9 then s = s - 1 end
        if o.prioWait[2] > 9 then s = s - 1 end
        return math.max(2, s)
    end

    function o.bot()
        local prioLane, bestK, bestN = nil, nil, 0
        for _, c in ipairs(o.cars) do
            local l = LANES[c.lane]
            if c.prio and not c.passed and c.s + c.len / 2 <= l.line + 0.5 and (c.s > 0 or c.kind == "bus") then prioLane = prioLane or c.lane end
        end
        for k = 1, 4 do
            local n = waitingCount(k)
            if n > bestN then bestK, bestN = k, n end
        end
        local want = prioLane
        if not want then
            if o.green and waitingCount(o.green) > 0 then want = o.green else want = bestK end
        end
        if want and want ~= o.green then
            In.press(LANES[want].key); In.release(LANES[want].key)
        end
    end

    function o.leave() end

    return o
end

return M
