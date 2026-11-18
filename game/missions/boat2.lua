-- Човен 2: «Човен Жабки зламався». Озеро: допливи до Жабки (збирай зірочки), натисни A — кинь линву з гачком,
-- потім тягни її човник до причалу ліворуч: з прив'язаним човном пливеш повільніше, а хвилі стають більшими.
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
    id = "boat2", vehicle = "boat", rescued = "frog",
    intro = "boat2_intro",
    icon = function(x, y, s, t)
        local bob = math.sin(t * 3) * 2 * s
        Dr.ellipse(x, y + 26 * s, 42 * s, 12 * s, C.water)
        lg.push(); lg.translate(x, y + 18 * s + bob); lg.rotate(-0.1)
        Dr.poly({ -30 * s, -4 * s, 30 * s, -4 * s, 20 * s, 12 * s, -20 * s, 12 * s }, C.wood)
        Dr.line(C.brown, 4 * s, 0, -4 * s, 9 * s, -30 * s)
        Dr.poly({ 2 * s, -22 * s, 22 * s, -8 * s, 4 * s, -8 * s }, C.cream, 0.9)
        lg.pop()
        Dr.animal("frog", x, y - 4 * s + bob, 0.55 * s, t, "sad")
        Dr.circle(x + 28 * s, y - 20 * s + bob, 3 * s, C.smoke, 0.7, true)
        Dr.circle(x + 34 * s, y - 30 * s + bob, 4.5 * s, C.smoke, 0.5, true)
    end,
}

local W, PIER_X, PIER_Y = 2700, 190, 338
local FROG_X, REST = 2450, 215
local PX_MIN = 292
local Y_MIN, Y_MAX = 325, 405

local function mix(a, b, p)
    return { a[1] + (b[1] - a[1]) * p, a[2] + (b[2] - a[2]) * p, a[3] + (b[3] - a[3]) * p, 1 }
end
local NEAR1, NEAR2, FAR1, FAR2 = hex(0x7BCBF2), hex(0x4BA8DE), hex(0x3FA3E0), hex(0x1F6CAA)

-- човник Жабки: поламана щогла, роздерте вітрило, дим
local function drawFrogBoat(x, y, t, tilt, mood, smoking, noFrog)
    lg.push(); lg.translate(x, y); lg.rotate(tilt)
    Dr.poly({ -62, -26, 62, -26, 44, 8, -44, 8 }, C.wood)
    Dr.rrect(-56, -22, 112, 7, 3, C.cream, 1, true)
    Dr.circle(-24, -6, 5, C.brown)
    -- зламана щогла й вітрило
    Dr.line(C.brown, 6, 18, -26, 30, -62)
    Dr.line(Dr.shade(C.brown, 0.3), 4, 30, -62, 42, -70)
    Dr.poly({ 24, -50, 24, -30, 4, -32 }, C.cream)
    -- Жабка
    if not noFrog then Dr.animal("frog", -8, -52 + math.sin(t * 3) * 1, 0.85, t, mood) end
    lg.pop()
    if smoking and math.floor(t * 8) % 4 == 0 then Fx.add("smoke", x + 34, y - 40, 14, -46, 1.6, 7) end
end

function M.new()
    local o = {
        t = 0, phase = "out", px = 330, py = 360, vx = 0, vy = 0, dir = 1, cam = 100,
        fx = FROG_X, fy = 358, tow = 0, hookT = 0, attached = false, throw = false,
        items = {}, got = 0, total = 0, idle = 0, jumpT = 0, doneT = nil, said = {},
    }
    local rnd = love.math.newRandomGenerator(9)
    for k = 1, 7 do table.insert(o.items, { x = 700 + (k - 1) * 250 + rnd:random(-40, 40), y = rnd:random(Y_MIN + 5, Y_MAX - 5) }) end
    for k = 1, 7 do table.insert(o.items, { x = 2200 - (k - 1) * 255 + rnd:random(-40, 40), y = rnd:random(Y_MIN + 5, Y_MAX - 5) }) end
    o.total = #o.items
    local isl = { { 900, 1.0 }, { 1700, 0.8 }, { 2350, 1.1 } }

    local function bs() return 0.78 + (o.py - Y_MIN) / (Y_MAX - Y_MIN) * 0.14 end
    local function say(id) if not o.said[id] then o.said[id] = true; Snd.voice(id) end end

    function o.press(name)
        if name == "a" then o.throw = true end
    end

    local function inRange()
        return o.phase == "out" and math.abs(o.px - o.fx) < 240 and math.abs(o.py - o.fy) < 55
    end

    function o.update(dt)
        o.t = o.t + dt
        local t = o.t
        local dx, dy = In.axis()
        local towing = o.attached and o.phase == "tow"
        o.tow = o.tow + ((towing and 1 or 0) - o.tow) * math.min(1, dt * 1.5)
        Snd.loop("engine", o.phase ~= "dock" and o.phase ~= "done", 0.2 + o.tow * 0.15)
        if o.phase == "out" or o.phase == "hook" or o.phase == "tow" then
            local sp = towing and 105 or 230
            if o.phase == "hook" then sp = 0 end
            o.vx = o.vx + (dx * sp - o.vx) * math.min(1, dt * 3)
            o.vy = o.vy + (dy * 120 - o.vy) * math.min(1, dt * 6)
            o.px = math.max(PX_MIN, math.min(W - 100, o.px + o.vx * dt))
            o.py = math.max(Y_MIN, math.min(Y_MAX, o.py + o.vy * dt))
            if dx ~= 0 and not o.attached then o.dir = dx end
            o.idle = (dx == 0 and dy == 0) and o.idle + dt or 0
            -- зірочки
            for _, st in ipairs(o.items) do
                if not st.taken and math.abs(st.x - o.px) < 55 and math.abs(st.y - o.py) < 34 then
                    st.taken = true
                    o.got = o.got + 1
                    Snd.play("ding")
                    Fx.burst("spark", st.x - o.cam, st.y - 40, 6, 120, 0.6, 8)
                end
            end
        end
        local target = (o.phase == "out" or o.phase == "hook") and (o.px - 230) or (o.px - 330)
        target = math.max(0, math.min(W - Dr.W, target))
        o.cam = o.cam + (target - o.cam) * math.min(1, dt * 3)

        if o.phase == "out" then
            if inRange() then
                say("boat2_throw")
                if o.throw or In.down("a") then o.phase = "hook"; o.hookT = 0; Snd.play("whoosh") end
            end
            if o.px > 600 then say("boat2_hint") end
        elseif o.phase == "hook" then
            o.hookT = o.hookT + dt / 0.8
            if o.hookT >= 1 then
                o.attached = true
                o.phase = "tow"
                o.dir = -1
                Snd.play("ding"); Snd.play("splash")
                Bk.splash(Fx, o.fx - 60 - o.cam, o.fy, 8)
                Snd.voice("boat2_tow")
            end
        elseif o.phase == "tow" then
            -- линва натягується — човник Жабки тягнеться за нами
            local taut = o.fx - o.px > REST
            if taut then o.fx = o.fx + ((o.px + REST) - o.fx) * math.min(1, dt * 6) end
            o.fy = o.fy + (o.py - o.fy) * math.min(1, dt * 1.5)
            if math.floor(t * 12) % 3 == 0 and taut then
                Fx.add("bubble", o.fx - 30 - o.cam, o.fy + 6, 0, -20, 0.8, 3)
            end
            if o.px <= PX_MIN + 3 and o.fx - o.px < REST + 25 then
                o.phase = "dock"; o.jumpT = 0
                Snd.loop("engine", false)
            end
        elseif o.phase == "dock" then
            o.vx = o.vx * (1 - math.min(1, dt * 4))
            o.jumpT = o.jumpT + dt
            if o.jumpT > 0.6 and not o.jumped then
                o.jumped = true
                Snd.play("splash")
            end
            if o.jumpT > 0.6 + 1.1 and not o.landed then
                o.landed = true
                o.doneT = t
                Snd.play("cheer")
                Snd.voice("boat2_done")
                Fx.burst("confetti", PIER_X - 90 - o.cam, 270, 45, 240, 2.4, 11)
            end
            if o.doneT and t - o.doneT > 2.6 then return true end
        end
        return false
    end

    local function layerFor(py, amp, t)
        local p = math.max(0, math.min(1, (py - Y_MIN) / (Y_MAX - Y_MIN)))
        return { y0 = py - 3, amp = amp * (0.8 + p * 0.5), par = 1, ph = py * 0.021 + 0.7, cam = o.cam,
            c1 = mix(NEAR1, FAR1, p), c2 = mix(NEAR2, FAR2, p), bottom = py + 170 }
    end

    local function ropePts(x1, y1, x2, y2, sag)
        local curve = love.math.newBezierCurve({ x1, y1, (x1 + x2) / 2, math.max(y1, y2) + sag, x2, y2 })
        return curve:render(3)
    end

    local function hook(x, y, ang)
        lg.push(); lg.translate(x, y); lg.rotate(ang)
        Dr.circle(0, 0, 6, C.grey)
        lg.setLineWidth(3.5); Dr.color(C.dark)
        lg.arc("line", "open", 0, 6, 8, -0.4, math.pi + 0.4, 12)
        lg.pop()
    end

    function o.draw()
        local t, cam = o.t, o.cam
        local amp = 1 + o.tow * 1.1
        Kit.sky("town", t)
        Kit.clouds(t, cam)
        Kit.hills(cam, 200, hex(0xA6DE8A))
        for _, is in ipairs(isl) do
            local sx = is[1] - cam * 0.5
            if sx > -150 and sx < Dr.W + 150 then
                Dr.ellipse(sx, 264, 90 * is[2], 20, C.grassD)
                Dr.tree(sx - 10, 258, 0.9 * is[2], t)
            end
        end
        local base = { y0 = 262, amp = 0.5 * amp, par = 0.5, ph = 0.3, cam = cam, c1 = hex(0x9ADCF7), c2 = hex(0x6EC1EA), bottom = 360 }
        Bk.layer(base, t)
        Bk.glints(t, 266, 300, cam, 0.5, 0.5, 2)
        local mid = { y0 = 292, amp = 0.8 * amp, par = 0.75, ph = 1.1, cam = cam, c1 = hex(0x84D0F4), c2 = hex(0x58B2E6), bottom = 400 }
        Bk.layer(mid, t)
        -- причал
        local pxs = PIER_X - cam
        if pxs > -20 then Bk.pier(pxs, PIER_Y, 220, t) end
        -- камені під човном Жабки
        local frx = o.fx - cam
        if not o.attached then
            for _, r in ipairs({ { -52, 6 }, { 44, 8 }, { 70, 2 } }) do
                Dr.ellipse(frx + r[1], o.fy + r[2], 16, 8, hex(0x8C94A3))
            end
        end
        -- човни за глибиною (далі — раніше), кожен з водою спереду
        local ents = {
            { y = o.py, id = "me" },
            { y = o.fy, id = "frog" },
        }
        table.sort(ents, function(a, b) return a.y < b.y end)
        local sc = bs()
        local meSX = o.px - cam
        local meL = layerFor(o.py, amp, t)
        local frL = layerFor(o.fy, amp, t)
        local meY = o.py + Bk.height(meL, meSX, t)
        local frY = o.fy + Bk.height(frL, frx, t)
        local frogMood = o.attached and "happy" or "sad"
        for _, e in ipairs(ents) do
            if e.id == "me" then
                Bk.wake(meSX, meY, sc, o.dir, o.vx, t)
                Bk.boat(meSX, meY, sc, t, math.atan(Bk.slope(meL, meSX, t) * 1.3), o.dir, o.vx)
                Bk.layer(meL, t)
            else
                if frx > -120 and frx < Dr.W + 120 then
                    if o.attached then Bk.wake(frx, frY, 0.85, -1, o.vx, t) end
                    drawFrogBoat(frx, frY, t, math.atan(Bk.slope(frL, frx, t) * 1.3), frogMood, not o.attached, o.phase == "dock" and o.jumpT > 0.6)
                end
                Bk.layer(frL, t)
            end
        end
        -- линва
        local ox, oy = meSX + 80 * sc, meY - 44 * sc
        local tx, ty = frx - 55, frY - 34
        if o.phase == "hook" then
            local p = o.hookT
            local hx = ox + (tx - ox) * p
            local hy = oy + (ty - oy) * p - math.sin(p * math.pi) * 70
            local pts = ropePts(ox, oy, hx, hy, 14)
            Dr.line(C.dark, 6, pts); Dr.line(hex(0xE8D3A8), 3.5, pts)
            hook(hx, hy, p * 5)
        elseif o.attached then
            local taut = o.phase == "tow" and (o.fx - o.px > REST - 6)
            local pts = ropePts(ox, oy, tx, ty, taut and 6 or 30)
            Dr.line(C.dark, 6, pts); Dr.line(hex(0xE8D3A8), 3.5, pts)
            hook(tx, ty, 0.6)
        end
        -- зірочки на воді
        for _, st in ipairs(o.items) do
            local sx = st.x - cam
            if not st.taken and sx > -30 and sx < Dr.W + 30 then
                local wy = st.y + Bk.height(layerFor(st.y, amp, t), sx, t)
                Dr.shadow(sx, wy + 2, 14, 3, 0.15)
                Dr.star(sx, wy - 30 + math.sin(t * 4 + st.x) * 4, 16, C.gold, 1, math.sin(t * 2 + st.x) * 0.3)
            end
        end
        -- Жабка стрибає на причал
        if o.phase == "dock" and o.jumpT > 0.6 then
            local p = math.min(1, (o.jumpT - 0.6) / 1.1)
            local sx0, sy0 = frx - 8, frY - 52
            local sx1, sy1 = PIER_X - 90 - cam, PIER_Y - 40
            local x = sx0 + (sx1 - sx0) * p
            local y = sy0 + (sy1 - sy0) * p - math.sin(p * math.pi) * 130
            Dr.animal("frog", x, y, 0.85, t, "happy")
        elseif o.landed then
            Dr.animal("frog", PIER_X - 90 - cam, PIER_Y - 40 - math.abs(math.sin(t * 6)) * 10, 0.85, t, "happy")
        end
        -- передній план: найбільші хвилі
        Bk.layer({ y0 = 446, amp = 1.5 * amp, par = 1.3, ph = 2.2, cam = cam, c1 = hex(0x3C97D8), c2 = hex(0x1C5F9C), a = 0.93 }, t)
        Fx.draw()
        Kit.starCount(o.got, o.total)
        local p
        if o.phase == "out" or o.phase == "hook" then p = (o.px - PX_MIN) / (FROG_X - PX_MIN) * 0.5
        else p = 0.5 + 0.5 * (FROG_X - o.fx) / (FROG_X - (PX_MIN + REST)) end
        Kit.progress(p, "boat")
        -- підказки
        if o.phase == "out" and inRange() then
            Dr.buttonA(meSX, meY - 130 * sc - 14, 1.1, t)
        elseif o.phase == "out" and o.idle > 2 then
            Dr.arrow(meSX + 40, meY - 100, 3, 1.2, C.yellow, t)
        elseif o.phase == "tow" and o.idle > 2 then
            Dr.arrow(meSX - 30, meY - 100, 1, 1.2, C.yellow, t)
        end
    end

    function o.stars()
        if o.got >= 7 then return 3 elseif o.got >= 3 then return 2 end
        return 1
    end

    -- бот: пливе до човна, кидає линву, тягне до причалу, на шляху ловить зірочки
    function o.bot()
        local function steerY(y)
            if math.abs(o.py - y) > 6 then
                local nm = (y < o.py) and "up" or "down"
                In.press(nm); In.release(nm == "up" and "down" or "up")
            else In.release("up"); In.release("down") end
        end
        if o.phase == "out" then
            In.release("left"); In.press("right")
            local want = o.fy
            for _, st in ipairs(o.items) do
                if not st.taken and st.x > o.px - 20 and st.x < o.px + 300 then want = st.y; break end
            end
            if inRange() then want = o.fy; steerY(want); In.press("a"); In.release("a") else steerY(want) end
        elseif o.phase == "tow" then
            In.release("right"); In.press("left")
            local want = o.py
            for _, st in ipairs(o.items) do
                if not st.taken and st.x < o.px + 20 and st.x > o.px - 300 then want = st.y; break end
            end
            steerY(want)
        else
            In.release("left"); In.release("right"); In.release("up"); In.release("down")
        end
    end

    function o.leave() Snd.loop("engine", false) end

    return o
end

return M
