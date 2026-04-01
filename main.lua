local shadows = {}
local enemies = {}
local particles = {}
local score = 0
local gameState = "menu" 

local invertShader = love.graphics.newShader[[
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 texcolor = Texel(texture, texture_coords);
        return vec4(1.0 - texcolor.rgb, texcolor.a) * color;
    }
]]

local settings = {
    volume = 0.5,
    fullscreen = false,
    resolutionIdx = 1,
    resolutions = {
        {w = 800, h = 600},
        {w = 1280, h = 720},
        {w = 1920, h = 1080}
    }
}

function love.load()
    anim8 = require 'libraries/anim8'
    
    player = {
        h = 80 * 2.3, 
        w = 96 * 2.3,
        speed = 250,
        y = 400,
        x = 200,
        health = 100,
        dir = "down",
        dashTimer = 0,
        isAttacking = false,
        deadTimer = 0,
        flicker = 0
    }
    
    player.sprites = {
        idle_down = love.graphics.newImage("sprite/idle/idle_down.png"),
        idle_up = love.graphics.newImage("sprite/idle/idle_up.png"),
        idle_left = love.graphics.newImage("sprite/idle/idle_left.png"),
        idle_right = love.graphics.newImage("sprite/idle/idle_right.png"),
        run_down = love.graphics.newImage("sprite/run/run_down.png"),
        run_up = love.graphics.newImage("sprite/run/run_up.png"),
        run_left = love.graphics.newImage("sprite/run/run_left.png"),
        run_right = love.graphics.newImage("sprite/run/run_right.png"),
        attack1_down = love.graphics.newImage("sprite/attack1/attack1_down.png"),
        attack1_up = love.graphics.newImage("sprite/attack1/attack1_up.png"),
        attack1_left = love.graphics.newImage("sprite/attack1/attack1_left.png"),
        attack1_right = love.graphics.newImage("sprite/attack1/attack1_right.png"),
        attack2_down = love.graphics.newImage("sprite/attack2/attack2_down.png"),
        attack2_up = love.graphics.newImage("sprite/attack2/attack2_up.png"),
        attack2_left = love.graphics.newImage("sprite/attack2/attack2_left.png"),
        attack2_right = love.graphics.newImage("sprite/attack2/attack2_right.png")
    }

    for _, s in pairs(player.sprites) do
        s:setFilter("nearest", "nearest")
    end

    player.grid = anim8.newGrid(96, 80, player.sprites.idle_down:getWidth(), player.sprites.idle_down:getHeight())
    
    player.animations = {
        idle_down = anim8.newAnimation(player.grid('1-8', 1), 0.2),
        idle_up = anim8.newAnimation(player.grid('1-8', 1), 0.2),
        idle_left = anim8.newAnimation(player.grid('1-8', 1), 0.2),
        idle_right = anim8.newAnimation(player.grid('1-8', 1), 0.2),
        run_down = anim8.newAnimation(player.grid('1-8', 1), 0.1),
        run_up = anim8.newAnimation(player.grid('1-8', 1), 0.1),
        run_left = anim8.newAnimation(player.grid('1-8', 1), 0.1),
        run_right = anim8.newAnimation(player.grid('1-8', 1), 0.1)
    }

    local dirs = {"down", "up", "left", "right"}
    for _, d in ipairs(dirs) do
        player.animations["attack1_"..d] = anim8.newAnimation(player.grid('1-8', 1), 0.05, function() player.isAttacking = false end)
        player.animations["attack2_"..d] = anim8.newAnimation(player.grid('1-8', 1), 0.05, function() player.isAttacking = false end)
    end

    player.currentAnim = player.animations.idle_down
    player.currentSprite = player.sprites.idle_down
        
    screen = {
        width = settings.resolutions[settings.resolutionIdx].w,
        height = settings.resolutions[settings.resolutionIdx].h
    }
    love.window.setMode(screen.width, screen.height, {fullscreen = settings.fullscreen})
    
    isPause = false
    mainFont = love.graphics.newFont("font/PixelPurl.ttf", 26)
    titleFont = love.graphics.newFont("font/PixelPurl.ttf", 60)
    
    sound = {
        dash = love.audio.newSource("sound/dash.mp3", "static"),
        music = love.audio.newSource("sound/bg-music.mp3", "stream"),
        sword = love.audio.newSource("sound/sword.mp3", "static"),
        damage = love.audio.newSource("sound/damage.mp3", "static")
    }
    sound.music:setLooping(true)
    sound.music:setVolume(settings.volume)
    sound.music:play()

    enemies = {}
    particles = {}
    score = 0
    spawnEnemies(5)
end

function spawnParticles(x, y)
    for i = 1, 20 do
        table.insert(particles, {
            x = x, y = y,
            vx = math.random(-200, 200),
            vy = math.random(-200, 200),
            life = 1.0
        })
    end
end

function spawnEnemies(count)
    for i = 1, count do
        table.insert(enemies, {
            x = math.random(0, screen.width - 100),
            y = math.random(0, screen.height - 100),
            w = 40, h = 40,
            speed = math.random(150, 220),
            dir = "down",
            attackTimer = 0
        })
    end
end

function checkCollision(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
end

function love.mousepressed(x, y, button)
    if gameState == "menu" or (gameState == "playing" and isPause) then
        if button == 1 then
            if x > screen.width/2 - 150 and x < screen.width/2 + 150 then
                if y > screen.height/2 + 10 and y < screen.height/2 + 50 then
                    if isPause then isPause = false sound.music:play() else gameState = "playing" end
                elseif y > screen.height/2 + 60 and y < screen.height/2 + 100 then
                    gameState = "options"
                elseif y > screen.height/2 + 110 and y < screen.height/2 + 150 then
                    love.event.quit()
                end
            end
        end
    elseif gameState == "options" then
        if button == 1 then
            if x > screen.width/2 - 100 and x < screen.width/2 + 100 then
                if y > 200 and y < 240 then
                    settings.volume = math.max(0, math.min(1, (x - (screen.width/2 - 100)) / 200))
                    sound.music:setVolume(settings.volume)
                elseif y > 260 and y < 300 then
                    settings.fullscreen = not settings.fullscreen
                    love.window.setFullscreen(settings.fullscreen)
                elseif y > 320 and y < 360 then
                    settings.resolutionIdx = settings.resolutionIdx % #settings.resolutions + 1
                    screen.width = settings.resolutions[settings.resolutionIdx].w
                    screen.height = settings.resolutions[settings.resolutionIdx].h
                    love.window.setMode(screen.width, screen.height, {fullscreen = settings.fullscreen})
                elseif y > 450 and y < 500 then
                    gameState = isPause and "playing" or "menu"
                end
            end
        end
    elseif gameState == "playing" and not isPause then
        if player.health > 0 and not player.isAttacking then
            if button == 1 or button == 2 then
                player.isAttacking = true
                sound.sword:stop()
                sound.sword:play()
                local animPrefix = button == 1 and "attack1_" or "attack2_"
                player.currentAnim = player.animations[animPrefix .. player.dir]
                player.currentSprite = player.sprites[animPrefix .. player.dir]
                player.currentAnim:gotoFrame(1)

                local killedCount = 0
                for i = #enemies, 1, -1 do
                    local e = enemies[i]
                    if checkCollision(player.x - 40, player.y - 40, player.w + 80, player.h + 80, e.x, e.y, 80, 80) then
                        spawnParticles(e.x + 40, e.y + 40)
                        table.remove(enemies, i)
                        killedCount = killedCount + 1
                        score = score + 10
                    end
                end
                if killedCount > 0 then spawnEnemies(killedCount) end
            end
        end
    end
end

function love.update(dt)
    if gameState == "menu" or gameState == "options" or isPause then return end

    if player.health <= 0 then
        gameState = "gameover"
        player.deadTimer = player.deadTimer + dt
        player.flicker = math.sin(player.deadTimer * 30)
        return 
    end

    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt * 2
        if p.life <= 0 then table.remove(particles, i) end
    end

    local moving = false
    local vx, vy = 0, 0
    local currentSpeed = player.speed * dt

    if player.dashTimer > 0 then
        currentSpeed = player.speed * 3 * dt
        player.dashTimer = player.dashTimer - dt
        table.insert(shadows, {anim = player.currentAnim, sprite = player.currentSprite, x = player.x, y = player.y, a = 1})
    end

    if not player.isAttacking then
        if love.keyboard.isDown('d') then vx = currentSpeed player.dir = "right" moving = true
        elseif love.keyboard.isDown('a') then vx = -currentSpeed player.dir = "left" moving = true end
        if love.keyboard.isDown('w') then vy = -currentSpeed player.dir = "up" moving = true
        elseif love.keyboard.isDown('s') then vy = currentSpeed player.dir = "down" moving = true end

        player.x = player.x + vx
        player.y = player.y + vy

        if moving then
            player.currentAnim = player.animations["run_" .. player.dir]
            player.currentSprite = player.sprites["run_" .. player.dir]
        else
            player.currentAnim = player.animations["idle_" .. player.dir]
            player.currentSprite = player.sprites["idle_" .. player.dir]
        end
    end
    player.currentAnim:update(dt)

    for i = #enemies, 1, -1 do
        local e = enemies[i]
        local angle = math.atan2(player.y - e.y, player.x - e.x)
        local dist = math.sqrt((player.x - e.x)^2 + (player.y - e.y)^2)
        
        if dist > 50 then
            e.x = e.x + math.cos(angle) * e.speed * dt
            e.y = e.y + math.sin(angle) * e.speed * dt
            e.isAttacking = false
        else
            e.isAttacking = true
            if e.attackTimer <= 0 then
                player.health = player.health - 5
                sound.damage:stop()
                sound.damage:play()
                e.attackTimer = 1.0 
            end
        end

        if e.attackTimer > 0 then e.attackTimer = e.attackTimer - dt end
        e.dir = math.abs(math.cos(angle)) > math.abs(math.sin(angle)) and (math.cos(angle) > 0 and "right" or "left") or (math.sin(angle) > 0 and "down" or "up")
    end
    
    for _, anim in pairs(player.animations) do anim:update(dt) end

    for i = #shadows, 1, -1 do
        shadows[i].a = shadows[i].a - 4 * dt
        if shadows[i].a <= 0 then table.remove(shadows, i) end
    end
    
    player.x = math.min(math.max(player.x, 0), screen.width - 100)
    player.y = math.min(math.max(player.y, 0), screen.height - 100)
end

function love.draw()
    if gameState == "menu" then
        love.graphics.setFont(titleFont)
        love.graphics.printf("SHADOW SLAYER", 0, screen.height/2 - 100, screen.width, "center")
        love.graphics.setFont(mainFont)
        love.graphics.printf("START GAME", 0, screen.height/2 + 10, screen.width, "center")
        love.graphics.printf("OPTIONS", 0, screen.height/2 + 60, screen.width, "center")
        love.graphics.printf("QUIT", 0, screen.height/2 + 110, screen.width, "center")
        return
    elseif gameState == "options" then
        love.graphics.setFont(titleFont)
        love.graphics.printf("OPTIONS", 0, 80, screen.width, "center")
        love.graphics.setFont(mainFont)
        love.graphics.printf("Volume: " .. math.floor(settings.volume * 100) .. "%", 0, 200, screen.width, "center")
        love.graphics.printf("Fullscreen: " .. (settings.fullscreen and "ON" or "OFF"), 0, 260, screen.width, "center")
        love.graphics.printf("Resolution: " .. screen.width .. "x" .. screen.height, 0, 320, screen.width, "center")
        love.graphics.printf("BACK", 0, 450, screen.width, "center")
        return
    end

    mainFont:setFilter("nearest")
    love.graphics.setFont(mainFont)
    
    for _, s in ipairs(shadows) do
        love.graphics.setColor(0.3, 0.6, 1, s.a)
        s.anim:draw(s.sprite, s.x, s.y, 0, 2.3)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(invertShader)
    for _, e in ipairs(enemies) do
        local state = e.isAttacking and "attack1_" or "run_"
        player.animations[state .. e.dir]:draw(player.sprites[state .. e.dir], e.x, e.y, 0, 2.3)
    end
    love.graphics.setShader()

    love.graphics.setColor(0.5, 0.5, 1)
    for _, p in ipairs(particles) do
        love.graphics.setPointSize(3)
        love.graphics.points(p.x, p.y)
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS : ".. love.timer.getFPS(), 1, 0)
    love.graphics.print("Score: " .. score, 1, 30)
    love.graphics.setColor(1, 0, 0)
    love.graphics.print("Health : ".. player.health, 15, screen.height - 40)
    
    if player.health > 0 or (player.health <= 0 and player.flicker > 0) then
        love.graphics.setColor(1, 1, 1)
        player.currentAnim:draw(player.currentSprite, player.x, player.y, 0, 2.3)
    end

    if isPause then
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", 0, 0, screen.width, screen.height)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(titleFont)
        love.graphics.printf("PAUSED", 0, screen.height/2 - 100, screen.width, "center")
        love.graphics.setFont(mainFont)
        love.graphics.printf("RESUME", 0, screen.height/2 + 10, screen.width, "center")
        love.graphics.printf("OPTIONS", 0, screen.height/2 + 60, screen.width, "center")
        love.graphics.printf("QUIT GAME", 0, screen.height/2 + 110, screen.width, "center")
    end

    if gameState == "gameover" then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, screen.width, screen.height)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("YOU DIED", 0, screen.height/2 - 60, screen.width, "center")
        love.graphics.printf("Final Score: " .. score, 0, screen.height/2 - 20, screen.width, "center")
        love.graphics.printf("Press 'R' to Restart", 0, screen.height/2 + 40, screen.width, "center")
    end
end

function love.keypressed(key)
    if key == "escape" and gameState == "playing" then
        isPause = not isPause
        if isPause then sound.music:pause() else sound.music:play() end
    end
    if key == "r" and gameState == "gameover" then
        gameState = "menu"
        love.load()
    end
    if key == "space" and gameState == "playing" and player.dashTimer <= 0 and not isPause and not player.isAttacking and player.health > 0 then
        sound.dash:stop()
        sound.dash:play()
        player.dashTimer = 0.2
    end
end