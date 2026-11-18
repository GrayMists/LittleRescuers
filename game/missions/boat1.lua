-- Човен 1: «Каченята на річці». Річка пливе повз, човен пливе сам; вгору/вниз — між трьома смугами води.
-- Підпливи до каченяти на листку — воно застрибне в човен. Камені й гілки лише сповільнюють.
-- Наприкінці мама-качка чекає на березі: каченята вистрибують по одному.
local Dr = require("core.draw")
local In = require("core.input")
local Snd = require("core.sound")
local Fx = require("core.fx")
local Kit = require("missions.kit")
local Bk = require("missions.boat_kit")
local lg = love.graphics
local C = Dr.C
local hex = Dr.hex

local M = {
    id = "boat1", vehicle = "boat", rescued = "duck",
    intro = "boat1_intro",
    icon = function(x, y, s, t)
        local bob = math.sin(t * 3) * 2 * s
        Dr.ellipse(x, y + 24 * s, 40 * s, 12 * s, C.water)
        Dr.ellipse(x - 2 * s, y + 20 * s + bob, 26 * s, 7 * s, C.green)
        Dr.ellipse(x - 2 * s, y + 8 * s + bob, 13 * s, 8 * s, C.yellow)
        Dr.animal("duck", x - 2 * s, y - 6 * s + bob, 0.55 * s, t, "sad")
        Dr.line(C.foam, 3 * s, x - 36 * s, y + 24 * s, x - 22 * s, y + 30 * s)
    end,
}

local LEN, BOAT_SX = 4400, 200
local LANE_Y = { 304, 354, 406 }
local STOP_CAM = LEN - 400
local DUCKS = { { 700, 2 }, { 1450, 3 }, { 2200, 1 }, { 2950, 2 }, { 3700, 3 } }
local OBST = { { 1050, 1, "rock" }, { 1800, 2, "branch" }, { 2550, 3, "rock" }, { 3300, 1, "branch" }, { 4000, 3, "rock" } }
-- місця каченят на борту (у координатах човна)
local SEATS = { { 46, -40 }, { 62, -40 }, { 78, -40 }, { -84, -40 }, { -70, -40 } }

local LAYERS = {
    { y0 = LANE_Y[1] - 3, amp = 1.0, par = 0.8, ph = 0.0, c1 = hex(0x7BCBF2), c2 = hex(0x4BA8DE), bottom = LANE_Y[1] + 120 },
    { y0 = LANE_Y[2] - 3, amp = 1.3, par = 0.9, ph = 1.3, c1 = hex(0x63BDEC), c2 = hex(0x358FCB), bottom = LANE_Y[2] + 120 },
    { y0 = LANE_Y[3] - 3, amp = 1.7, par = 1.0, ph = 2.6, c1 = hex(0x4AAAE4), c2 = hex(0x2272B0) },
}
local BASE = { y0 = 252, amp = 0.6, par = 0.5, ph = 0.5, c1 = hex(0x9ADCF7), c2 = hex(0x6EC1EA), bottom = 400 }

local function duckling(x, y, s, t, mood)
    Dr.ellipse(x, y + 10 * s, 24 * s, 15 * s, C.yellow)
    Dr.poly({ x + 20 * s, y + 6 * s, x + 30 * s, y + 2 * s, x + 24 * s, y + 14 * s }, C.yellow)
    Dr.animal("duck", x, y, s, t, mood or "happy")
end

local function drawRock(x, y, t, hit)
    Dr.shadow(x, y + 2, 34, 6, 0.2)
    local sh = hit and math.sin(t * 40) * 2 or 0
    Dr.poly({ x - 34 + sh, y + 4, x - 24 + sh, y - 26, x - 4 + sh, y - 38, x + 22 + sh, y - 28, x + 36 + sh, y + 4 }, hex(0x8C94A3))
    Dr.poly({ x - 10 + sh, y - 38, x + 22 + sh, y - 28, x + 8 + sh, y - 14, x - 14 + sh, y - 18 }, hex(0xAEB6C4), 1, true)
    lg.setColor(1, 1, 1, 0.8)
    lg.ellipse("fill", x, y + 3, 40, 5, 16)
end

local function drawBranch(x, y, t, hit)
    local sh = hit and math.sin(t * 40) * 2 or 0
    lg.push(); lg.translate(x + sh, y - 4); lg.rotate(-0.08)
    Dr.rrect(-48, -9, 96, 18, 9, C.brown)
    Dr.line(Dr.outlineOf(C.brown), 2, -30, -3, 20, -3)
    Dr.line(C.brown, 6, 10, -8, 22, -28)
    Dr.line(C.brown, 5, -22, -8, -30, -24)
    Dr.circle(22, -30, 8, C.green); Dr.circle(-30, -26, 7, C.grassD)
    lg.pop()
    lg.setColor(1, 1, 1, 0.8)
    lg.ellipse("fill", x, y + 4, 52, 4, 16)
end

local function drawLeaf(x, y)
    Dr.ellipse(x, y, 30, 8, C.green)
    Dr.line(C.grassD, 2, x - 20, y, x + 20, y)
    Dr.ellipse(x + 20, y - 1, 8, 3, C.grassD, 1, true)
end

function M.new()
    local o = {
        t = 0, phase = "sail", cam = 0, speed = 0, lane = 2, ly = LANE_Y[2], wob = 0, idle = 0,
        got = 0, bumped = 0, ducks = {}, obst = {}, lilies = {}, deco = {}, unloadT = 0, doneT = nil,
    }
    local rnd = love.math.newRandomGenerator(5)
    for k, d in ipairs(DUCKS) do o.ducks[k] = { x = d[1], lane = d[2], state = "float", seat = nil, phase = rnd:random() * 6 } end
    for k, ob in ipairs(OBST) do o.obst[k] = { x = ob[1], lane = ob[2], kind = ob[3], hit = 0 } end
    for k = 1, 60 do o.lilies[k] = { x = rnd:random(0, LEN), lane = rnd:random(1, 3), dy = rnd:random(8, 26), big = rnd:random() < 0.4 } end
    for k = 0, 40 do o.deco[k] = { x = k * 150 + rnd:random(-30, 30), kind = rnd:random() < 0.7 and "tree" or "bush" } end

    local function boatY(t)
        local l = (o.ly < (LANE_Y[1] + LANE_Y[2]) / 2) and 1 or (o.ly < (LANE_Y[2] + LANE_Y[3]) / 2) and 2 or 3
        LAYERS[l].cam = o.cam
        return o.ly + Bk.height(LAYERS[l], BOAT_SX, t), l, LAYERS[l]
    end
    local function boatScale() return 0.7 + (o.ly - LANE_Y[1]) / (LANE_Y[3] - LANE_Y[1]) * 0.22 end

    -- де зараз сидить каченя seat на борту (екран)
    local function seatPos(k)
        local by = boatY(o.t)
        local s = boatScale()
        local sp = SEATS[k]
        return BOAT_SX + sp[1] * s, by + sp[2] * s - 8
    end

    function o.press(name)
        if o.phase ~= "sail" then return end
        if name == "up" then o.lane = math.max(1, o.lane - 1); o.idle = 0
        elseif name == "down" then o.lane = math.min(3, o.lane + 1); o.idle = 0 end
    end

    local function hopTo(d, tx, ty)
        d.state = "hop"; d.hopT = 0
        d.fx, d.fy = d.cx, d.cy
        d.tx, d.ty = tx, ty
    end

    function o.update(dt)
        o.t = o.t + dt
        Snd.loop("engine", true, 0.25)
        for _, d in ipairs(o.ducks) do
            if d.state == "hop" then
                d.hopT = d.hopT + dt / 0.6
                if d.hopT >= 1 then
                    d.state = d.toBank and "bank" or "seat"
                    d.hopT = 1
                    Snd.play("pop")
                    if d.toBank then o.landed = (o.landed or 0) + 1 end
                end
            end
        end
        if o.phase == "sail" then
            local target = 140
            if In.down("right") then target = 210 elseif In.down("left") then target = 80 end
            local toStop = STOP_CAM - o.cam
            if toStop < 360 then target = math.min(target, math.max(30, toStop * 0.75)) end
            o.speed = o.speed + (target - o.speed) * math.min(1, dt * 2.5)
            if o.wob > 0 then o.wob = math.max(0, o.wob - dt); o.speed = o.speed * (1 - dt * 2) end
            o.cam = math.min(STOP_CAM, o.cam + o.speed * dt)
            o.ly = o.ly + (LANE_Y[o.lane] - o.ly) * math.min(1, dt * 8)
            local dx, dy = In.axis()
            o.idle = (dx == 0 and dy == 0) and o.idle + dt or 0
            local wx = o.cam + BOAT_SX
            for k, d in ipairs(o.ducks) do
                if d.state == "float" and math.abs(d.x - wx) < 85 and math.abs(o.ly - LANE_Y[d.lane]) < 24 then
                    -- каченя вистрибує з листка в човен
                    local sx = d.x - o.cam
                    d.cx = sx; d.cy = LANE_Y[d.lane] - 14
                    o.got = o.got + 1
                    d.seat = o.got
                    hopTo(d, 0, 0)
                    d.boarding = true
                    Snd.play("splash")
                    Bk.splash(Fx, sx, LANE_Y[d.lane], 6)
                    o.idle = 0
                    if k == 1 then Snd.voice("boat1_hint") end
                end
            end
            for _, ob in ipairs(o.obst) do
                if ob.hit == 0 and math.abs(ob.x - wx) < 55 and math.abs(o.ly - LANE_Y[ob.lane]) < 26 then
                    ob.hit = 0.7
                    o.bumped = o.bumped + 1
                    o.wob = 0.7
                    Snd.play("bump")
                    Bk.splash(Fx, BOAT_SX + 60, o.ly, 8)
                end
                if ob.hit > 0 and ob.hit < 1 then ob.hit = math.max(0.001, ob.hit - dt) end
            end
            if o.cam >= STOP_CAM - 0.5 then
                o.phase = "unload"; o.unloadT = 0
                Snd.loop("engine", false)
                Snd.voice("boat1_done")
            end
        else
            o.speed = 0
            o.unloadT = o.unloadT + dt
            local bx = LEN - o.cam
            -- вистрибуємо по одному кожні 0.8 с
            local idx = math.floor((o.unloadT - 0.8) / 0.8) + 1
            for k, d in ipairs(o.ducks) do
                if k <= idx and not d.toBank and d.state ~= "hop" then
                    d.toBank = true; d.boarding = false
                    if d.state == "float" then d.cx, d.cy = bx - 40 - k * 24, LANE_Y[2] - 14
                    else d.cx, d.cy = seatPos(d.seat) end
                    hopTo(d, bx + 58 + k * 20, 336 + (k % 2) * 12)
                    d.slot = k
                end
            end
            if o.landed == #o.ducks and not o.doneT then
                o.doneT = o.unloadT
                Snd.play("cheer")
                Fx.burst("confetti", bx + 150, 260, 40, 240, 2.2, 11)
            end
            return o.doneT ~= nil and o.unloadT - o.doneT > 2.6
        end
        return false
    end

    local function laneObjects(l, t)
        local cam = o.cam
        local L = LAYERS[l]
        L.cam = cam
        for _, ob in ipairs(o.obst) do
            local sx = ob.x - cam
            if ob.lane == l and sx > -70 and sx < Dr.W + 70 then
                local y = LANE_Y[l] + Bk.height(L, sx, t)
                if ob.kind == "rock" then drawRock(sx, y, t, ob.hit > 0 and ob.hit < 1)
                else drawBranch(sx, y, t, ob.hit > 0 and ob.hit < 1) end
            end
        end
        for _, d in ipairs(o.ducks) do
            local sx = d.x - cam
            if d.state == "float" and d.lane == l and sx > -50 and sx < Dr.W + 50 then
                local y = LANE_Y[l] + Bk.height(L, sx, t)
                drawLeaf(sx, y)
                duckling(sx, y - 18 + math.sin(t * 3 + d.phase) * 1.5, 0.5, t, "sad")
            end
        end
    end

    local function lilies(l, t)
        local cam = o.cam
        local L = LAYERS[l]
        for _, li in ipairs(o.lilies) do
            if li.lane == l then
                local sx = li.x - cam
                if sx > -30 and sx < Dr.W + 30 then
                    local y = LANE_Y[l] + li.dy + Bk.height(L, sx, t)
                    Dr.ellipse(sx, y, li.big and 20 or 13, li.big and 5 or 3.5, C.green, 0.9, true)
                    if li.big then Dr.circle(sx + 4, y - 4, 4, C.pink, 1, true) end
                end
            end
        end
    end

    local function drawBank(t)
        local bx = LEN - o.cam
        if bx > Dr.W + 40 then return end
        Dr.poly({ bx - 10, 490, bx + 6, 410, bx + 36, 350, bx + 100, 318, 1400, 312, 1400, 490 }, C.grass)
        Dr.line(C.grassD, 7, bx + 36, 352, bx + 100, 320, 1400, 314)
        lg.setColor(1, 1, 1, 0.75)
        lg.ellipse("fill", bx + 2 + math.sin(t * 2) * 2, 412, 26, 5, 16)
        lg.ellipse("fill", bx + 30 + math.sin(t * 2.4) * 2, 352, 16, 4, 16)
        Dr.bush(bx + 240, 318, 1.3)
        Dr.tree(bx + 330, 316, 1.1, t)
        -- мама-качка
        local mx, my = bx + 165, 322
        Dr.shadow(mx, my + 14, 36, 8)
        local hop = o.doneT and math.abs(math.sin(t * 6)) * 8 or math.sin(t * 2) * 2
        Dr.ellipse(mx, my - 4 - hop, 44, 28, C.yellow)
        Dr.poly({ mx - 40, my - 10 - hop, mx - 62, my - 24 - hop, mx - 50, my + 4 - hop }, C.yellow)
        Dr.animal("duck", mx + 22, my - 38 - hop, 1.15, t, "happy")
        if not o.doneT then Dr.arrow(mx + 22, my - 118 + math.sin(t * 4) * 3, 0, 0.8, C.yellow, t) end
    end

    function o.draw()
        local t, cam = o.t, o.cam
        Kit.sky("town", t)
        Kit.clouds(t, cam)
        Kit.hills(cam, 205)
        -- далекий берег: дерева й кущі
        for k = 0, 40 do
            local dd = o.deco[k]
            local sx = dd.x - cam * 0.45
            if sx > -80 and sx < Dr.W + 80 then
                if dd.kind == "tree" then Dr.tree(sx, 262, 0.8, t) else Dr.bush(sx, 258, 0.9) end
            end
        end
        BASE.cam = cam
        Bk.layer(BASE, t)
        Bk.glints(t, 262, 300, cam, 0.5, 0.5, 1)
        local by, bl, bL = boatY(t)
        local bs = boatScale()
        local dying = {}
        for l = 1, 3 do
            laneObjects(l, t)
            if l == bl then
                local tilt = math.atan(Bk.slope(bL, BOAT_SX, t) * 1.2)
                local bob = o.wob > 0 and math.abs(math.sin(o.wob * 20)) * 6 or 0
                Bk.wake(BOAT_SX, by, bs, 1, o.speed, t)
                Bk.boat(BOAT_SX, by - bob, bs, t, tilt, 1, o.speed)
                -- каченята на борту
                for k, d in ipairs(o.ducks) do
                    if d.state == "seat" then
                        local sx, sy = seatPos(d.seat)
                        duckling(sx, sy - bob + math.sin(t * 5 + k) * 1.5, 0.55 * bs, t, "happy")
                    elseif d.state == "hop" then dying[#dying + 1] = d end
                end
            else
                for _, d in ipairs(o.ducks) do if d.state == "hop" and l == 3 then dying[#dying + 1] = d end end
            end
            LAYERS[l].cam = cam
            Bk.layer(LAYERS[l], t)
            lilies(l, t)
        end
        drawBank(t)
        -- каченята у стрибку (поверх усього)
        local seen = {}
        for _, d in ipairs(dying) do
            if not seen[d] then
                seen[d] = true
                local p = d.hopT
                local tx, ty = d.tx, d.ty
                if d.boarding then tx, ty = seatPos(d.seat) end
                local x = d.fx + (tx - d.fx) * p
                local y = d.fy + (ty - d.fy) * p - math.sin(p * math.pi) * 70
                local sc = d.boarding and (0.5 + (0.55 * bs - 0.5) * p) or (0.5 - 0.1 * p)
                duckling(x, y, sc, t, "happy")
            end
        end
        for _, d in ipairs(o.ducks) do
            if d.state == "bank" then
                local bx = LEN - cam
                local x, y = d.tx, d.ty
                if bx < Dr.W + 60 then
                    local hop = o.doneT and math.abs(math.sin(t * 6 + d.slot)) * 6 or 0
                    duckling(x, y - hop, 0.4, t, "happy")
                end
            end
        end
        Fx.draw()
        -- табло: скільки каченят у човні
        Dr.rrect(14, 12, 150, 44, 16, C.panel)
        for i = 1, #DUCKS do
            local x = 38 + (i - 1) * 28
            if i <= o.got then Dr.circle(x, 34, 11, C.yellow); Dr.poly({ x + 6, 36, x + 15, 34, x + 8, 42 }, C.orange, 1, true)
            else Dr.circle(x, 34, 11, hex(0xD6D0C4), 1, true) end
        end
        Kit.progress(cam / STOP_CAM, "boat")
        -- підказка: у яку смугу пливти
        if o.phase == "sail" and o.idle > 2 then
            local nxt
            for _, d in ipairs(o.ducks) do
                if d.state == "float" and d.x > o.cam + BOAT_SX - 90 then nxt = d; break end
            end
            if nxt and nxt.lane ~= o.lane then
                local up = nxt.lane < o.lane
                Dr.arrow(BOAT_SX, by + (up and -150 or -140), up and 2 or 0, 1.2, C.yellow, t)
            end
        end
    end

    function o.stars()
        local s = 1
        if o.got >= 3 then s = 2 end
        if o.got >= 5 and o.bumped <= 3 then s = 3 end
        return s
    end

    -- бот: у лінію до наступного каченяти, повз перешкоди
    function o.bot()
        if o.phase ~= "sail" then In.release("right"); return end
        In.press("right")
        local wx = o.cam + BOAT_SX
        local want = o.lane
        for _, d in ipairs(o.ducks) do
            if d.state == "float" and d.x > wx - 80 and d.x < wx + 900 then want = d.lane; break end
        end
        local function blocked(l)
            for _, ob in ipairs(o.obst) do
                if ob.lane == l and ob.x > wx - 60 and ob.x < wx + 320 then return true end
            end
            return false
        end
        for _, d in ipairs(o.ducks) do
            if d.state == "float" and d.lane == want and math.abs(d.x - wx) < 260 then goto ok end
        end
        if blocked(want) then
            for l = 1, 3 do if not blocked(l) then want = l; break end end
        end
        ::ok::
        if want ~= o.lane then
            local nm = want < o.lane and "up" or "down"
            In.press(nm); In.release(nm)
        end
    end

    function o.leave() Snd.loop("engine", false) end

    return o
end

return M
