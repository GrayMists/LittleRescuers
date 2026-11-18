-- Збереження: save.txt, рядки «ключ=значення». Числа — числа, решта — рядки.
local Save = {}

Save.data = { stars = {} }   -- stars[місія] = 1..3

function Save.read()
    local txt = love.filesystem.read("save.txt")
    if not txt then return end
    for line in txt:gmatch("[^\n]+") do
        local k, v = line:match("^([%w_]+)=(.*)$")
        if k == "stars" then
            for id, n in v:gmatch("([%w_]+):(%d+)") do Save.data.stars[id] = tonumber(n) end
        elseif k then
            Save.data[k] = tonumber(v) or v
        end
    end
end

function Save.write()
    local out = {}
    local st = {}
    for id, n in pairs(Save.data.stars) do table.insert(st, id .. ":" .. n) end
    table.sort(st)
    table.insert(out, "stars=" .. table.concat(st, ","))
    for k, v in pairs(Save.data) do
        if k ~= "stars" and (type(v) == "number" or type(v) == "string") then table.insert(out, k .. "=" .. v) end
    end
    love.filesystem.write("save.txt", table.concat(out, "\n") .. "\n")
end

function Save.stars(id) return Save.data.stars[id] or 0 end

function Save.setStars(id, n)
    if n > Save.stars(id) then Save.data.stars[id] = n end
    Save.write()
end

function Save.totalStars()
    local n = 0
    for _, v in pairs(Save.data.stars) do n = n + v end
    return n
end

return Save
