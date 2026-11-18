-- Частинки: краплі води, дим, конфеті, блискітки.
local Dr = require("core.draw")
local lg = love.graphics
local C = Dr.C

local Fx = {}

local parts = {}

-- kind: "drop" | "smoke" | "confetti" | "spark" | "bubble"
function Fx.add(kind, x, y, vx, vy, life, size, col)
    table.insert(parts, { kind = kind, x = x, y = y, vx = vx or 0, vy = vy or 0, life = life or 1,
        age = 0, size = size or 6, col = col, rot = love.math.random() * 6 })
end

function Fx.burst(kind, x, y, n, speed, life, size)
    for _ = 1, n do
        local a = love.math.random() * math.pi * 2
        local sp = (speed or 120) * (0.4 + love.math.random() * 0.6)
        local col = nil
        if kind == "confetti" then
            local list = { C.red, C.yellow, C.blue, C.green, C.pink, C.purple, C.orange }
            col = list[love.math.random(#list)]
        end
        Fx.add(kind, x, y, math.cos(a) * sp, math.sin(a) * sp - (kind == "confetti" and 120 or 0), life, size, col)
    end
end

function Fx.clear() parts = {} end

function Fx.update(dt)
    for k = #parts, 1, -1 do
        local p = parts[k]
        p.age = p.age + dt
        if p.age >= p.life then
            table.remove(parts, k)
        else
            p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
            if p.kind == "drop" then p.vy = p.vy + 600 * dt
            elseif p.kind == "confetti" then p.vy = p.vy + 260 * dt; p.vx = p.vx * 0.99; p.rot = p.rot + dt * 6
            elseif p.kind == "smoke" then p.size = p.size + dt * 18; p.vx = p.vx * 0.98
            elseif p.kind == "bubble" then p.vx = p.vx + math.sin(p.age * 8) * 20 * dt end
        end
    end
end

function Fx.draw()
    for _, p in ipairs(parts) do
        local k = 1 - p.age / p.life
        if p.kind == "drop" then
            Dr.color(C.water, 0.9)
            lg.circle("fill", p.x, p.y, p.size, 12)
            lg.setColor(1, 1, 1, 0.6)
            lg.circle("fill", p.x - p.size * 0.3, p.y - p.size * 0.3, p.size * 0.3, 8)
        elseif p.kind == "smoke" then
            Dr.color(C.smoke, 0.45 * k)
            lg.circle("fill", p.x, p.y, p.size, 20)
        elseif p.kind == "confetti" then
            lg.push(); lg.translate(p.x, p.y); lg.rotate(p.rot)
            Dr.color(p.col, math.min(1, k * 2))
            lg.rectangle("fill", -p.size / 2, -p.size / 4, p.size, p.size / 2, 2, 2)
            lg.pop()
        elseif p.kind == "spark" then
            Dr.star(p.x, p.y, p.size * k + 2, C.gold, k)
        elseif p.kind == "bubble" then
            lg.setColor(1, 1, 1, 0.7 * k)
            lg.setLineWidth(2)
            lg.circle("line", p.x, p.y, p.size, 16)
        end
    end
end

return Fx
