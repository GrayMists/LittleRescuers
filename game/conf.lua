function love.conf(t)
    t.identity = "littlerescuers"
    t.version = "11.5"
    t.window.title = "Little Rescuers"
    t.window.width = tonumber(os.getenv("LR_W") or "") or 640
    t.window.height = tonumber(os.getenv("LR_H") or "") or 480
    t.window.vsync = 1
    t.window.msaa = 4
    t.modules.physics = false
    t.modules.video = false
end
