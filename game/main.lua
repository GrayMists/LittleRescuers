-- Маленькі рятувальники — гра для дітей 4–6 років (LÖVE 11.5, PortMaster).
-- Логічний екран 640x480; на приставці масштабується під будь-яку роздільність без пікселізації.
local Dr = require("core.draw")
local In = require("core.input")
local Snd = require("core.sound")
local Fx = require("core.fx")
local Save = require("core.save")
local Sc = require("core.screens")
local lg = love.graphics

local view = { s = 1, ox = 0, oy = 0 }
local Dev = nil
if os.getenv("LR_TEST") or os.getenv("LR_SHOT") then Dev = require("dev") end

local function layout()
    local w, h = lg.getDimensions()
    view.s = math.min(w / Dr.W, h / Dr.H)
    view.ox = math.floor((w - Dr.W * view.s) / 2)
    view.oy = math.floor((h - Dr.H * view.s) / 2)
end

function love.load()
    lg.setLineStyle("smooth")
    lg.setLineJoin("bevel")
    love.mouse.setVisible(false)
    layout()
    Snd.init()
    Save.read()
    In.onPress = function(name) Sc.press(name) end
    if Dev then Dev.init(); return end
    Sc.go("title", nil, true)
end

function love.resize() layout() end

local quitHold = 0
function love.update(dt)
    dt = math.min(dt, 1 / 20)
    if Dev then dt = Dev.dt(dt) end
    In.update()
    Snd.update()
    Fx.update(dt)
    Sc.update(dt)
    if Dev then Dev.update(dt) end
    quitHold = In.quitHeld() and quitHold + dt or 0
    if quitHold > 1 then Save.write(); love.event.quit() end
end

function love.draw()
    lg.clear(0.08, 0.1, 0.2, 1)
    lg.push()
    lg.translate(view.ox, view.oy)
    lg.scale(view.s)
    lg.setScissor(view.ox, view.oy, math.ceil(Dr.W * view.s), math.ceil(Dr.H * view.s))
    Sc.draw()
    lg.setScissor()
    lg.pop()
    if Dev then Dev.afterDraw() end
end

function love.quit() Save.write() end
