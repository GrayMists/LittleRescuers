-- Спільне для човнових місій: гладкі хвилі (шари синусоїд з градієнтом і піною),
-- човен на хвилі, слід, відблиски, причал.
local Dr = require("core.draw")
local Ve = require("core.vehicles")
local lg = love.graphics
local C = Dr.C

local Bk = {}

local STEP = 16
local N = math.floor(Dr.W / STEP) + 2
local pool, poolI = {}, 0

-- Шар хвилі описує таблиця o: { y0, amp, cam, par, ph, c1, c2, a, foam, bottom }.
-- Висота води в точці екрана sx (від y0): сума трьох синусоїд, що пливуть із часом.
function Bk.height(o, sx, t)
    local wx = sx + (o.cam or 0) * (o.par or 1)
    local ph = o.ph or 0
    return (math.sin(wx * 0.017 + t * 1.5 + ph) * 5 + math.sin(wx * 0.041 - t * 2.2 + ph * 1.7) * 2.2
        + math.sin(wx * 0.0063 + t * 0.7 + ph * 0.6) * 4) * (o.amp or 1)
end

function Bk.slope(o, sx, t)
    return (Bk.height(o, sx + 8, t) - Bk.height(o, sx - 8, t)) / 16
end

-- намалювати шар води від хвилястої лінії до низу екрана
function Bk.layer(o, t)
    poolI = poolI % 14 + 1
    local m = pool[poolI]
    if not m then m = lg.newMesh(N * 2, "strip", "stream"); pool[poolI] = m end
    local c1, c2, a = o.c1 or C.water, o.c2 or C.waterD, o.a or 1
    local bot = o.bottom or Dr.H + 10
    local verts, pts, ys = {}, {}, {}
    for i = 0, N - 1 do
        local sx = i * STEP
        local y = o.y0 + Bk.height(o, sx, t)
        ys[i] = y
        verts[#verts + 1] = { sx, y, 0, 0, c1[1], c1[2], c1[3], a }
        verts[#verts + 1] = { sx, bot, 0, 0, c2[1], c2[2], c2[3], a }
        pts[#pts + 1] = sx; pts[#pts + 1] = y
    end
    m:setVertices(verts)
    lg.setColor(1, 1, 1, 1)
    lg.draw(m)
    local foam = o.foam or 1
    if foam > 0 then
        -- світла кромка і пінні шапки на гребенях
        lg.setLineStyle("smooth"); lg.setLineJoin("bevel")
        lg.setLineWidth(3)
        lg.setColor(1, 1, 1, 0.55 * foam * a)
        lg.line(pts)
        local amp = o.amp or 1
        for i = 1, N - 2 do
            local curv = ys[i - 1] + ys[i + 1] - 2 * ys[i]
            local k = math.max(0, math.min(1, curv / (2.6 * amp + 0.5) - 0.15))
            if k > 0.05 then
                local x, y = i * STEP, ys[i] + 1
                lg.setColor(1, 1, 1, 0.85 * k * foam * a)
                lg.circle("fill", x, y, 3 + 2.5 * k, 12)
                lg.circle("fill", x - 8, y + 2, 2 + 1.6 * k, 10)
                lg.circle("fill", x + 8, y + 2, 2 + 1.6 * k, 10)
            end
        end
    end
end

-- блиски сонця на воді
function Bk.glints(t, y0, y1, cam, par, a, seed)
    for k = 1, 16 do
        local x = ((k * 97 + (seed or 0) * 31 - (cam or 0) * (par or 1)) % (Dr.W + 40)) - 20
        local y = y0 + ((k * 53 + (seed or 0) * 17) % 100) / 100 * (y1 - y0)
        local s = math.max(0, math.sin(t * 2.1 + k * 1.9))
        if s > 0.2 then
            lg.setColor(1, 1, 1, (a or 0.6) * s)
            lg.rectangle("fill", x - 8 * s, y, 16 * s, 2, 1, 1)
        end
    end
end

-- відбиток світла (місяць, ліхтар) стовпчиком на воді
function Bk.reflect(x, y0, y1, t, col, w, a)
    local n = 14
    for k = 0, n - 1 do
        local p = k / (n - 1)
        local y = y0 + (y1 - y0) * p
        local ww = w * (1 - p * 0.35) * (0.55 + 0.45 * math.sin(t * 3 + k * 1.3))
        local xx = x + math.sin(t * 2 + k * 0.9) * 5 * p
        lg.setColor(col[1], col[2], col[3], (a or 0.6) * (1 - p * 0.75))
        lg.rectangle("fill", xx - ww / 2, y, ww, 3, 1.5, 1.5)
    end
end

-- човен: y — рівень води, tilt — нахил від хвилі, dir = 1 (вправо) або -1
function Bk.boat(x, y, s, t, tilt, dir, speed)
    lg.push()
    lg.translate(x, y)
    lg.rotate((tilt or 0) * dir)
    Ve.draw("boat", 0, 0, s, t, { flip = dir, siren = true, speed = speed })
    lg.pop()
end

-- піна за кормою
function Bk.wake(x, y, s, dir, speed, t)
    local k = math.min(1, math.abs(speed or 0) / 140)
    if k < 0.05 then return end
    for i = 1, 5 do
        local p = i / 5
        local wx = x - dir * (62 + i * 20) * s + math.sin(t * 5 + i) * 3
        lg.setColor(1, 1, 1, 0.7 * (1 - p) * k)
        lg.ellipse("fill", wx, y + 1, (16 - i * 1.6) * s, 3.2 * s, 16)
    end
end

-- бризки навколо точки
function Bk.splash(Fx, x, y, n)
    for _ = 1, n or 8 do
        Fx.add("drop", x + love.math.random(-10, 10), y, love.math.random(-70, 70), -love.math.random(120, 240), 0.6, 3 + love.math.random() * 3)
    end
end

-- причал: дошки йдуть від x - len до x, поверхня на висоті y
function Bk.pier(x, y, len, t, noLamp)
    len = len or 260
    for k = 0, 2 do
        local px = x - 24 - k * (len - 40) / 2
        Dr.rrect(px - 7, y, 14, 70, 4, Dr.shade(C.brown, -0.2))
    end
    Dr.rrect(x - len, y - 12, len, 16, 5, C.wood)
    for k = 1, math.floor(len / 28) do
        Dr.line(Dr.outlineOf(C.wood), 2, x - len + k * 28, y - 11, x - len + k * 28, y + 2)
    end
    Dr.rrect(x - 22, y - 26, 14, 16, 5, C.grey)   -- тумба для линви
    -- ліхтар на стовпі
    if noLamp then return end
    local lx = x - len + 36
    Dr.rrect(lx - 4, y - 78, 8, 68, 3, C.dark)
    Dr.rrect(lx - 10, y - 96, 20, 20, 6, C.yellow)
    lg.setColor(1, 0.95, 0.55, 0.22 + 0.06 * math.sin(t * 3))
    lg.circle("fill", lx, y - 86, 28, 24)
end

return Bk
