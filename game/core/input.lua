-- Кнопки: хрестовина / лівий стік / клавіатура -> up, down, left, right; A (= B), X, Y, back (Start/Select).
-- In.down(name) — чи затиснуто зараз; натискання передаються в screens через In.onPress.
local In = {}

In.onPress = nil   -- function(name)

local held = {}
local stick = { left = false, right = false, up = false, down = false }

local PAD = {
    dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
    a = "a", b = "a", x = "x", y = "y", start = "back", back = "back",
}
local KEY = {
    up = "up", down = "down", left = "left", right = "right",
    space = "a", ["return"] = "a", z = "a", x = "x", c = "y", escape = "back", tab = "back",
}

local function press(name)
    held[name] = true
    if In.onPress then In.onPress(name) end
end
local function release(name) held[name] = false end

function In.down(name) return held[name] or stick[name] or false end

-- напрямок, затиснутий зараз (dx, dy з -1/0/1)
function In.axis()
    local dx = (In.down("right") and 1 or 0) - (In.down("left") and 1 or 0)
    local dy = (In.down("down") and 1 or 0) - (In.down("up") and 1 or 0)
    return dx, dy
end

function love.gamepadpressed(_, btn) if PAD[btn] then press(PAD[btn]) end end
function love.gamepadreleased(_, btn) if PAD[btn] then release(PAD[btn]) end end
function love.keypressed(k) if KEY[k] then press(KEY[k]) end end
function love.keyreleased(k) if KEY[k] then release(KEY[k]) end end
-- джойстик без мапінгу: будь-яка кнопка — A
function love.joystickpressed(j) if not j:isGamepad() then press("a") end end
function love.joystickreleased(j) if not j:isGamepad() then release("a") end end

-- лівий стік як хрестовина (з натисканням при першому відхиленні)
function In.update()
    local nx = { left = false, right = false, up = false, down = false }
    for _, j in ipairs(love.joystick.getJoysticks()) do
        if j:isGamepad() then
            local ax, ay = j:getGamepadAxis("leftx"), j:getGamepadAxis("lefty")
            if ax < -0.5 then nx.left = true elseif ax > 0.5 then nx.right = true end
            if ay < -0.5 then nx.up = true elseif ay > 0.5 then nx.down = true end
        end
    end
    for k, v in pairs(nx) do
        if v and not stick[k] and In.onPress then In.onPress(k) end
        stick[k] = v
    end
end

-- для автотесту: натиснути/відпустити віртуально
In.press, In.release = press, release

-- Вихід: Select+Start, утримувати секунду
function In.quitHeld()
    for _, j in ipairs(love.joystick.getJoysticks()) do
        if j:isGamepad() and j:isGamepadDown("back") and j:isGamepadDown("start") then return true end
    end
    return false
end

return In
