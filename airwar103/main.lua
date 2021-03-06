-- LuaTools需要PROJECT和VERSION这两个信息
PROJECT = "airwar"
VERSION = "1.0.0"

-- 引入必要的库文件(lua编写), 内部库不需要require
local sys = require "sys"

print(_VERSION)

width = 80
height = 160

if wdt then
    wdt.init(15000) -- 初始化watchdog设置为15s
    sys.timerLoopStart(wdt.feed, 10000) -- 10s喂一次狗
end

spi_lcd = spi.deviceSetup(0, pin.PB04, 0, 0, 8, 20 * 1000 * 1000, spi.MSB, 1, 1)
log.info("lcd.init", lcd.init("st7735", {
    port = "device",
    pin_dc = pin.PB01,
    pin_pwr = pin.PB00,
    pin_rst = pin.PB03,
    direction = 2,
    w = width,
    h = height,
    xoffset = 24,
    yoffset = 0
}, spi_lcd))

local gameover = false
local player = {}
local enemys = {}
local foods = {}
local projectiles = {}
local score = 0

local xbm_hero = string.char(0xFF, 0xFF, 0x7F, 0xFE, 0x7F, 0xFE, 0x3F, 0xFC, 0x3F, 0xFC, 0xDF, 0xFB, 0xCF, 0xF3, 0xEF,
    0xF7, 0xAF, 0xF5, 0xF7, 0xEF, 0xFB, 0xDF, 0x1D, 0xB8, 0x5B, 0xDA, 0x67, 0xE6, 0xEF, 0xF7, 0xEF, 0xF7)
local xbm_enemy = string.char(0xFB, 0xFE, 0x77, 0xFF, 0x03, 0xFE, 0x89, 0xFC, 0x00, 0xF8, 0x02, 0xFA, 0xFA, 0xFA, 0x27,
    0xFF)

function checkCollision(a, b, padding_up, padding_down, padding_left, padding_right)
    local a_left = a.x + padding_left
    local a_right = a.x + a.width - padding_right
    local a_top = a.y + padding_up
    local a_bottom = a.y + a.height - padding_down

    local b_left = b.x + padding_left
    local b_right = b.x + b.width - padding_right
    local b_top = b.y + padding_up
    local b_bottom = b.y + b.height - padding_down
    return a_right > b_left and a_left < b_right and a_bottom > b_top and a_top < b_bottom
end

sys.taskInit(function()
    gpio.setup(pin.PA04, function(val)
        if gameover then
            for k, v in pairs(projectiles) do
                projectiles[k] = nil
            end
            for k, v in pairs(enemys) do
                enemys[k] = nil
            end
            score = 0
            lcd.setFont(lcd.font_opposansm8)
            gameover = false
            return
        end
        -- projectile
        local projectile = {}
        projectile.width = 2
        projectile.height = 6
        projectile.x = player.x + player.width / 2 - projectile.width / 2
        projectile.y = player.y
        projectile.speed = 8
        table.insert(projectiles, projectile)
    end, gpio.PULLUP) -- 按键按下接地，因此需要上拉

    gpio.setup(pin.PA01, function(val)
        -- up
        if val == 0 then
            player.vy = -1
            player.vx = 0
        end
    end, gpio.PULLUP) -- 按键按下接地，因此需要上拉

    gpio.setup(pin.PA00, function(val)
        -- down
        if val == 0 then
            player.vy = 1
            player.vx = 0
        end
    end, gpio.PULLUP) -- 按键按下接地，因此需要上拉

    gpio.setup(pin.PB11, function(val)
        -- left
        if val == 0 then
            player.vx = -1
            player.vy = 0
        end
    end, gpio.PULLUP) -- 按键按下接地，因此需要上拉

    gpio.setup(pin.PA07, function(val)
        -- right
        if val == 0 then
            player.vx = 1
            player.vy = 0
        end
    end, gpio.PULLUP) -- 按键按下接地，因此需要上拉

    player.width = 16
    player.height = 16
    player.x = width / 2 - player.width / 2
    player.y = height - player.height * 2
    player.vx = 0
    player.vy = 0
    player.speed = 5
    lcd.setFont(lcd.font_opposansm8)
end)

sys.timerLoopStart(function()

    if gameover then
        lcd.setFont(lcd.font_opposansm18)
        lcd.drawStr(2, 70, "GAME", 0x001F)  --0x001F是蓝色，0xF800是红色。但是合宙101 颜色R和B反了，所以这里用0x001F刚好屏幕是红色。
        lcd.drawStr(2, 110, "OVER", 0x001F) --同上
        return
    end

    lcd.clear(0x0000)

    lcd.drawStr(2, 10, "score:" .. score, 0xFFFF)

    player.x = player.x + player.vx * player.speed
    player.y = player.y + player.vy * player.speed
    if player.x < 0 then
        player.x = 0
    end
    if player.x > width - player.width then
        player.x = width - player.width
    end
    if player.y < 0 then
        player.y = 0
    end
    if player.y > height - player.height then
        player.y = height - player.height
    end

    -- lcd.fill(player.x, player.y, player.x + player.width, player.y + player.height, 0xB3F7)
    lcd.drawXbm(player.x, player.y, player.width, player.height, xbm_hero)

    for i, v in ipairs(projectiles) do
        v.y = v.y - v.speed
        if v.y < v.height * -1 then
            table.remove(projectiles, i)
        end
        lcd.fill(v.x, v.y, v.x + v.width, v.y + v.height, 0xFE03)
    end

    for i, a in ipairs(projectiles) do
        for ii, b in ipairs(enemys) do
            if checkCollision(a, b, 0, 0, 0, 0) then
                table.remove(projectiles, i)
                table.remove(enemys, ii)
                score = score + 1
            end
        end
    end

    for i, v in ipairs(enemys) do
        v.y = v.y + v.speed
        if v.y > height then
            table.remove(enemys, i)
        end
        if checkCollision(v, player, 0, 0, 0, 0) then
            gameover = true
        end
        -- lcd.fill(v.x, v.y, v.x + v.width, v.y + v.height, 0x001F)
        lcd.drawXbm(v.x, v.y, v.width, v.height, xbm_enemy)
    end

end, 300)

sys.timerLoopStart(function()
    if #enemys < 3 and gameover == false then
        local enemy = {}
        enemy.width = 11
        enemy.height = 8
        enemy.x = math.random(0, width - enemy.width)
        enemy.y = -1 * math.random(1, 5) * enemy.height
        enemy.speed = 6
        table.insert(enemys, enemy)
    end
end, 100)
-- sys.taskInit(function()
--     while true do
--         lcd.clear(0x0000)
--         lcd.drawRectangle(x, y, x+30, y+30, 0x001F) 
--     end
-- end)
-- 用户代码已结束---------------------------------------------
-- 结尾总是这一句

sys.run()
-- sys.run()之后后面不要加任何语句!!!!!
