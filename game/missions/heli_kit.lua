-- Спільне для вертолітних місій: політ у 2D з інерцією, гвинт, трос із кошиком, гори.
local Dr = require("core.draw")
local Ve = require("core.vehicles")
local In = require("core.input")
local Snd = require("core.sound")
local lg = love.graphics
local C = Dr.C

local HK = {}

-- вертоліт: x, y — низ вертольота (полози)
function HK.new(x, y)
    return { x = x, y = y, vx = 0, vy = 0, tilt = 0, face = 1, sway = 0, t = 0, moved = 0 }
end

-- b = { x0, y0, x1, y1, speed } — межі польоту. Повертає dx, dy натиснутого.
function HK.update(h, dt, b)
    h.t = h.t + dt
    local dx, dy = In.axis()
    local sp = b.speed or 190
    local k = math.min(1, dt * 2.4)
    h.vx = h.vx + (dx * sp - h.vx) * k
    h.vy = h.vy + (dy * sp * 0.8 - h.vy) * k
    h.x, h.y = h.x + h.vx * dt, h.y + h.vy * dt
    if h.x < b.x0 then h.x, h.vx = b.x0, 0 elseif h.x > b.x1 then h.x, h.vx = b.x1, 0 end
    if h.y < b.y0 then h.y, h.vy = b.y0, 0 elseif h.y > b.y1 then h.y, h.vy = b.y1, 0 end
    if math.abs(h.vx) > 25 then h.face = h.vx > 0 and 1 or -1 end
    h.tilt = h.tilt + ((h.vx / sp) * 0.2 * h.face * h.face - h.tilt) * math.min(1, dt * 5)
    -- гойдання троса/кошика
    local want = math.max(-1, math.min(1, -h.vx / sp))
    h.sway = h.sway + (want - h.sway) * math.min(1, dt * 3)
    h.moved = (dx == 0 and dy == 0) and h.moved + dt or 0   -- скільки секунд стоїмо
    Snd.loop("rotor", true, 0.35)
    return dx, dy
end

function HK.draw(h, t, scale, opt)
    lg.push()
    lg.translate(h.x, h.y)
    lg.rotate(h.tilt)
    opt = opt or {}
    opt.flip, opt.shadowK = h.face, 0.0001
    Ve.draw("heli", 0, 0, scale or 0.55, t, opt)
    lg.pop()
end

-- кошик на тросі: ropeLen, наповнення fill (0..1) — для води, або вміст малює викликач
-- повертає координати кошика (bx, by — центр дна)
function HK.basketPos(h, ropeLen)
    return h.x + h.sway * 34 * math.min(1, ropeLen / 120), h.y + 4 + ropeLen
end

function HK.drawRope(h, ropeLen, kind, fill, t)
    local bx, by = HK.basketPos(h, ropeLen)
    Dr.line(C.dark, 3, h.x, h.y + 2, bx - 12, by - 20)
    Dr.line(C.dark, 3, h.x, h.y + 2, bx + 12, by - 20)
    if kind == "bucket" then
        -- відро: вода видно зверху
        Dr.poly({ bx - 15, by - 26, bx + 15, by - 26, bx + 11, by, bx - 11, by }, C.red)
        Dr.ellipse(bx, by - 26, 15, 4, C.dark)
        if fill and fill > 0 then Dr.ellipse(bx, by - 26 + (1 - fill) * 2, 12, 3, C.water, 1, true) end
        Dr.line(C.white, 2, bx - 11, by - 14, bx + 11, by - 14)
    else
        -- плетений кошик
        Dr.rrect(bx - 20, by - 26, 40, 26, 8, C.wood)
        for k = -1, 1 do Dr.line(Dr.outlineOf(C.wood), 2, bx + k * 12, by - 24, bx + k * 12, by - 3) end
        Dr.line(Dr.outlineOf(C.wood), 2, bx - 18, by - 14, bx + 18, by - 14)
    end
end

-- гладкий гірський хребет (меш-смужка): base — лінія основи, amp — висота, snow — де починається сніг
function HK.ridge(seed, base, amp, c1, c2, snow)
    local rnd = love.math.newRandomGenerator(seed)
    local p1, p2, p3 = rnd:random() * 6, rnd:random() * 6, rnd:random() * 6
    local verts, caps = {}, {}
    local col1, col2 = c1, c2
    for x = 0, Dr.W + 8, 8 do
        local u = x / Dr.W
        local hgt = (math.abs(math.sin(u * 4.2 + p1)) * 0.6 + math.sin(u * 9 + p2) * 0.15 + math.sin(u * 2.1 + p3) * 0.25 + 0.3) * amp
        local top = base - hgt
        table.insert(verts, { x, top, 0, 0, col1[1], col1[2], col1[3], 1 })
        table.insert(verts, { x, base, 0, 0, col2[1], col2[2], col2[3], 1 })
        if snow then
            local d = math.max(0, snow - top) * 0.55
            table.insert(caps, { x, top, 0, 0, 1, 1, 1, 1 })
            table.insert(caps, { x, top + d, 0, 0, 1, 1, 1, d > 0 and 1 or 0 })
        end
    end
    return { mesh = lg.newMesh(verts, "strip", "static"), caps = snow and lg.newMesh(caps, "strip", "static") or nil }
end

function HK.drawRidge(r)
    lg.setColor(1, 1, 1, 1)
    lg.draw(r.mesh)
    if r.caps then lg.draw(r.caps) end
end

-- бот для автотесту: тримає напрямки, щоб долетіти до (tx, ty). true — долетів.
function HK.botMove(h, tx, ty, tol)
    tol = tol or 12
    local ex, ey = tx - h.x, ty - h.y
    local function key(name, on) if on then if not In.down(name) then In.press(name) end elseif In.down(name) then In.release(name) end end
    key("right", ex > math.abs(h.vx) * 0.5 + tol)
    key("left", -ex > math.abs(h.vx) * 0.5 + tol)
    key("down", ey > math.abs(h.vy) * 0.5 + tol)
    key("up", -ey > math.abs(h.vy) * 0.5 + tol)
    return math.abs(ex) <= tol * 2 and math.abs(ey) <= tol * 2
end

function HK.botRelease()
    for _, k in ipairs({ "up", "down", "left", "right", "a" }) do if In.down(k) then In.release(k) end end
end

function HK.stop() Snd.loop("rotor", false) end

return HK
