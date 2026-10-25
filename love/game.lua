local game = {
  state = "menu",
  fear = 0,
  elapsed = 0,
  spawnTimer = 0,
  stoneCooldown = 0,
  enemies = {},
  stones = {},
  fearShots = {},
  trees = {},
  groundMarks = {},
  touches = {},
  mouseJoysticks = {},
  mouseFiring = false,
  activeMouseButton = nil,
  moveInput = { x = 0, y = 0 },
  aimInput = { x = 0, y = 0 },
  maxEnemies = 4,
  spawnInterval = 4,
}

local function length(x, y)
  return math.sqrt(x * x + y * y)
end

local function normalized(x, y)
  local magnitude = length(x, y)
  if magnitude == 0 then return 0, 0 end
  if magnitude > 1 then return x / magnitude, y / magnitude end
  return x, y
end

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(value, maximum))
end

local function overlapsCircleRect(x, y, radius, left, top, width, height)
  local closestX = clamp(x, left, left + width)
  local closestY = clamp(y, top, top + height)
  return length(x - closestX, y - closestY) <= radius
end

local function joystickGeometry()
  local width, height = love.graphics.getDimensions()
  local radius = math.min(70, height * 0.11)
  local inset = radius + 20
  return inset, width - inset, height - inset, radius
end

local function joystickValue(x, y, centerX, centerY, radius)
  local dx, dy = x - centerX, y - centerY
  local magnitude = length(dx, dy)
  local deadzone = radius * 0.12
  local travel = radius * 0.66
  if magnitude <= deadzone then return 0, 0 end
  local strength = math.min(1, (magnitude - deadzone) / (travel - deadzone))
  return dx / magnitude * strength, dy / magnitude * strength
end

local function mouseJoystickFor(side)
  for _, joystick in pairs(game.mouseJoysticks) do
    if joystick.side == side then return joystick end
  end
end

local function refreshJoystickInput(side)
  local target = side == "left" and game.moveInput or game.aimInput
  local touch = game[side .. "Touch"]
  local mouseJoystick = mouseJoystickFor(side)
  if touch then
    target.x, target.y = touch.x, touch.y
  elseif mouseJoystick then
    target.x, target.y = mouseJoystick.x, mouseJoystick.y
  else
    target.x, target.y = 0, 0
  end
end

local function setJoystickInput(side, x, y)
  local leftX, rightX, centerY, radius = joystickGeometry()
  local centerX = side == "left" and leftX or rightX
  local inputX, inputY = joystickValue(x, y, centerX, centerY, radius)
  local target = side == "left" and game.moveInput or game.aimInput
  target.x, target.y = inputX, inputY
  local mouseJoystick = mouseJoystickFor(side)
  if mouseJoystick then mouseJoystick.x, mouseJoystick.y = inputX, inputY end
end

local function playerBoundsAt(x, y)
  local player = game.player
  return x - player.width / 2, y - player.height, player.width, player.height
end

local function treeBlocksPlayer(tree, x, y)
  local player = game.player
  local playerLeft = x - player.width / 2
  local playerRight = x + player.width / 2
  local trunkLeft = tree.x - 8
  local trunkRight = tree.x + 8
  local trunkTop = tree.y - 12
  return playerLeft < trunkRight
    and playerRight > trunkLeft
    and y - 6 < tree.y
    and y > trunkTop
end

local function resetGame()
  local width, height = love.graphics.getDimensions()
  game.worldWidth, game.worldHeight = width * 3, height * 3
  game.player = {
    x = game.worldWidth / 2,
    y = game.worldHeight / 2,
    width = 28,
    height = 48,
    facingX = 0,
    facingY = -1,
  }
  game.fear = 0
  game.elapsed = 0
  game.spawnTimer = 0
  game.stoneCooldown = 0
  game.enemies = {}
  game.stones = {}
  game.fearShots = {}
  game.touches = {}
  game.leftTouch = nil
  game.rightTouch = nil
  game.mouseJoysticks = {}
  game.mouseFiring = false
  game.activeMouseButton = nil
  game.moveInput.x, game.moveInput.y = 0, 0
  game.aimInput.x, game.aimInput.y = 0, 0

  game.groundMarks = {}
  for _ = 1, 420 do
    table.insert(game.groundMarks, {
      x = love.math.random() * game.worldWidth,
      y = love.math.random() * game.worldHeight,
      kind = love.math.random(1, 4),
      shade = love.math.random(),
    })
  end

  local treePositions = {
    { 0.08, 0.12, 1.0 }, { 0.28, 0.08, 0.72 }, { 0.53, 0.15, 0.86 },
    { 0.78, 0.09, 1.12 }, { 0.94, 0.23, 0.76 }, { 0.13, 0.41, 0.72 },
    { 0.90, 0.52, 1.0 }, { 0.06, 0.73, 1.08 }, { 0.31, 0.88, 0.90 },
    { 0.59, 0.82, 1.12 }, { 0.83, 0.91, 0.86 },
  }
  game.trees = {}
  for _, position in ipairs(treePositions) do
    table.insert(game.trees, {
      x = game.worldWidth * position[1],
      y = game.worldHeight * position[2],
      width = 30 * position[3],
      height = 68 * position[3],
      scale = position[3],
    })
  end
  game.state = "playing"
end

local function spawnEnemy()
  local edge = love.math.random(1, 4)
  local x = edge == 1 and 0 or (edge == 2 and game.worldWidth or love.math.random() * game.worldWidth)
  local y = edge == 3 and 0 or (edge == 4 and game.worldHeight or love.math.random() * game.worldHeight)
  table.insert(game.enemies, {
    x = x,
    y = y,
    width = 26,
    height = 34,
    shootTimer = 1.2,
  })
end

local function fireFearShot(enemy)
  local dx, dy = game.player.x - enemy.x, game.player.y - enemy.y
  local magnitude = length(dx, dy)
  if magnitude == 0 then return end
  table.insert(game.fearShots, {
    x = enemy.x,
    y = enemy.y,
    vx = dx / magnitude * 145,
    vy = dy / magnitude * 145,
    radius = 10,
  })
end

local function updateKeyboardInput()
  local moveX, moveY = 0, 0
  if love.keyboard.isDown("a", "left") then moveX = moveX - 1 end
  if love.keyboard.isDown("d", "right") then moveX = moveX + 1 end
  if love.keyboard.isDown("w", "up") then moveY = moveY - 1 end
  if love.keyboard.isDown("s", "down") then moveY = moveY + 1 end
  if game.leftTouch then
    moveX, moveY = game.leftTouch.x, game.leftTouch.y
  else
    local mouseJoystick = mouseJoystickFor("left")
    if mouseJoystick then moveX, moveY = mouseJoystick.x, mouseJoystick.y end
  end
  game.moveInput.x, game.moveInput.y = normalized(moveX, moveY)

  local aimX, aimY = 0, 0
  if love.keyboard.isDown("j", "kp4") then aimX = aimX - 1 end
  if love.keyboard.isDown("l", "kp6") then aimX = aimX + 1 end
  if love.keyboard.isDown("i", "kp8") then aimY = aimY - 1 end
  if love.keyboard.isDown("k", "kp2") then aimY = aimY + 1 end
  local mouseAim = mouseJoystickFor("right")
  if game.rightTouch then
    aimX, aimY = game.rightTouch.x, game.rightTouch.y
  elseif mouseAim then
    aimX, aimY = mouseAim.x, mouseAim.y
  elseif game.mouseFiring and love.mouse.isDown(1) then
    local screenX, screenY = love.mouse.getPosition()
    aimX = screenX + (game.cameraX or 0) - game.player.x
    aimY = screenY + (game.cameraY or 0) - game.player.y
  end
  game.aimInput.x, game.aimInput.y = normalized(aimX, aimY)
end

local function movePlayer(dt)
  local player = game.player
  local dx, dy = normalized(game.moveInput.x, game.moveInput.y)
  if dx ~= 0 or dy ~= 0 then player.facingX, player.facingY = dx, dy end
  local nextX = clamp(player.x + dx * 220 * dt, player.width / 2, game.worldWidth - player.width / 2)
  local nextY = clamp(player.y + dy * 220 * dt, player.height, game.worldHeight)

  local blocked = false
  for _, tree in ipairs(game.trees) do
    if treeBlocksPlayer(tree, nextX, player.y) then blocked = true; break end
  end
  if not blocked then player.x = nextX end

  blocked = false
  for _, tree in ipairs(game.trees) do
    if treeBlocksPlayer(tree, player.x, nextY) then blocked = true; break end
  end
  if not blocked then player.y = nextY end
end

local function updateGame(dt)
  updateKeyboardInput()
  movePlayer(dt)
  game.elapsed = game.elapsed + dt
  game.spawnTimer = game.spawnTimer + dt
  if game.spawnTimer >= game.spawnInterval then
    game.spawnTimer = game.spawnTimer - game.spawnInterval
    if #game.enemies < game.maxEnemies then spawnEnemy() end
  end

  for _, enemy in ipairs(game.enemies) do
    local dx, dy = game.player.x - enemy.x, game.player.y - enemy.y
    local magnitude = length(dx, dy)
    if magnitude > 0 then
      enemy.x = enemy.x + dx / magnitude * 76 * dt
      enemy.y = enemy.y + dy / magnitude * 76 * dt
    end
    enemy.shootTimer = enemy.shootTimer - dt
    if enemy.shootTimer <= 0 then
      fireFearShot(enemy)
      enemy.shootTimer = 2.4
    end
  end

  if length(game.aimInput.x, game.aimInput.y) > 0 then
    game.stoneCooldown = game.stoneCooldown - dt
    if game.stoneCooldown <= 0 then
      table.insert(game.stones, {
        x = game.player.x,
        y = game.player.y,
        vx = game.aimInput.x * 390,
        vy = game.aimInput.y * 390,
        radius = 7,
      })
      game.stoneCooldown = 0.38
    end
  else
    game.stoneCooldown = 0
  end

  local playerLeft, playerTop, playerWidth, playerHeight = playerBoundsAt(game.player.x, game.player.y)
  for index = #game.fearShots, 1, -1 do
    local shot = game.fearShots[index]
    shot.x = shot.x + shot.vx * dt
    shot.y = shot.y + shot.vy * dt
    if overlapsCircleRect(shot.x, shot.y, shot.radius, playerLeft, playerTop, playerWidth, playerHeight) then
      game.fear = math.min(100, game.fear + 20)
      table.remove(game.fearShots, index)
      if game.fear >= 100 then game.state = "gameover" end
    elseif shot.x < 0 or shot.x > game.worldWidth or shot.y < 0 or shot.y > game.worldHeight then
      table.remove(game.fearShots, index)
    end
  end

  for index = #game.stones, 1, -1 do
    local stone = game.stones[index]
    stone.x = stone.x + stone.vx * dt
    stone.y = stone.y + stone.vy * dt
    local hitEnemy
    for enemyIndex, enemy in ipairs(game.enemies) do
      local left, top = enemy.x - enemy.width / 2, enemy.y - enemy.height
      if overlapsCircleRect(stone.x, stone.y, stone.radius, left, top, enemy.width, enemy.height) then
        hitEnemy = enemyIndex
        break
      end
    end
    if hitEnemy then
      table.remove(game.enemies, hitEnemy)
      table.remove(game.stones, index)
    elseif stone.x < 0 or stone.x > game.worldWidth or stone.y < 0 or stone.y > game.worldHeight then
      table.remove(game.stones, index)
    end
  end
end

local function cameraOffset()
  local width, height = love.graphics.getDimensions()
  return clamp(game.player.x - width / 2, 0, math.max(0, game.worldWidth - width)),
    clamp(game.player.y - height / 2, 0, math.max(0, game.worldHeight - height))
end

local function drawTree(tree)
  local scale, x, y = tree.scale, tree.x, tree.y
  love.graphics.setColor(0.07, 0.19, 0.12, 0.38)
  love.graphics.ellipse("fill", x, y - 2 * scale, 25 * scale, 7 * scale)
  love.graphics.setColor(0.30, 0.20, 0.12)
  love.graphics.rectangle("fill", x - 7 * scale, y - 25 * scale, 14 * scale, 25 * scale, 4 * scale, 4 * scale)
  love.graphics.setColor(0.40, 0.27, 0.15)
  love.graphics.rectangle("fill", x - 3 * scale, y - 23 * scale, 3 * scale, 20 * scale, 1 * scale, 1 * scale)
  love.graphics.setColor(0.08, 0.25, 0.15)
  love.graphics.circle("fill", x, y - 48 * scale, 23 * scale)
  love.graphics.circle("fill", x - 14 * scale, y - 43 * scale, 16 * scale)
  love.graphics.circle("fill", x + 14 * scale, y - 43 * scale, 16 * scale)
  love.graphics.setColor(0.13, 0.38, 0.21)
  love.graphics.circle("fill", x - 3 * scale, y - 51 * scale, 18 * scale)
  love.graphics.circle("fill", x + 12 * scale, y - 48 * scale, 12 * scale)
  love.graphics.setColor(0.25, 0.51, 0.27, 0.8)
  love.graphics.circle("fill", x - 9 * scale, y - 58 * scale, 7 * scale)
end

local function drawPlayer(player)
  local x, y = player.x, player.y
  love.graphics.setColor(0.06, 0.16, 0.11, 0.38)
  love.graphics.ellipse("fill", x, y - 1, 15, 5)
  love.graphics.setColor(0.34, 0.22, 0.16)
  love.graphics.rectangle("fill", x - 11, y - 13, 9, 11, 3, 3)
  love.graphics.rectangle("fill", x + 2, y - 13, 9, 11, 3, 3)
  love.graphics.setColor(0.18, 0.24, 0.34)
  love.graphics.rectangle("fill", x - 9, y - 18, 7, 13, 3, 3)
  love.graphics.rectangle("fill", x + 2, y - 18, 7, 13, 3, 3)
  love.graphics.setColor(0.62, 0.31, 0.20)
  love.graphics.rectangle("fill", x - 13, y - 34, 7, 17, 3, 3)
  love.graphics.rectangle("fill", x + 6, y - 34, 7, 17, 3, 3)
  love.graphics.setColor(0.24, 0.49, 0.34)
  love.graphics.rectangle("fill", x - 10, y - 35, 20, 21, 6, 6)
  love.graphics.setColor(0.86, 0.63, 0.34)
  love.graphics.rectangle("fill", x - 2, y - 33, 4, 17, 2, 2)
  love.graphics.setColor(0.53, 0.34, 0.20)
  love.graphics.rectangle("fill", x - 13, y - 33, 5, 14, 2, 2)
  love.graphics.setColor(0.88, 0.62, 0.43)
  love.graphics.circle("fill", x, y - 42, 10)
  love.graphics.setColor(0.20, 0.14, 0.12)
  love.graphics.arc("fill", x, y - 44, 10, math.pi, math.pi * 2)
  love.graphics.circle("fill", x - 8, y - 45, 4)
  love.graphics.setColor(0.16, 0.13, 0.12)
  local eyeX = player.facingX < -0.2 and -3 or (player.facingX > 0.2 and 3 or 2)
  love.graphics.circle("fill", x + eyeX, y - 42, 1.3)
  love.graphics.setColor(0.56, 0.25, 0.22)
  love.graphics.arc("line", x + eyeX + 1, y - 39, 2.5, 0, math.pi)
end

local function drawEnemy(enemy)
  local x, y = enemy.x, enemy.y
  love.graphics.setColor(0.08, 0.15, 0.11, 0.35)
  love.graphics.ellipse("fill", x, y - 1, 14, 5)
  love.graphics.setColor(0.42, 0.24, 0.27)
  love.graphics.ellipse("fill", x, y - 15, 14, 17)
  love.graphics.setColor(0.75, 0.31, 0.34)
  love.graphics.circle("fill", x, y - 21, 11)
  love.graphics.setColor(0.92, 0.72, 0.57)
  love.graphics.circle("fill", x - 4, y - 22, 1.5)
  love.graphics.circle("fill", x + 4, y - 22, 1.5)
  love.graphics.setColor(0.28, 0.12, 0.16)
  love.graphics.arc("line", x, y - 18, 4, 0, math.pi)
end

local function drawGround()
  love.graphics.setColor(0.14, 0.29, 0.19)
  love.graphics.rectangle("fill", 0, 0, game.worldWidth, game.worldHeight)
  for _, mark in ipairs(game.groundMarks) do
    if mark.kind == 1 then
      love.graphics.setColor(0.25, 0.40, 0.22, 0.55)
      love.graphics.ellipse("fill", mark.x, mark.y, 13, 5)
    elseif mark.kind == 2 then
      love.graphics.setColor(0.37, 0.45, 0.24, 0.5)
      love.graphics.line(mark.x - 3, mark.y + 3, mark.x, mark.y - 3, mark.x + 4, mark.y + 2)
    elseif mark.kind == 3 then
      love.graphics.setColor(0.08, 0.22, 0.14, 0.34)
      love.graphics.circle("fill", mark.x, mark.y, 3 + mark.shade * 5)
    else
      love.graphics.setColor(0.58, 0.57, 0.32, 0.65)
      love.graphics.circle("fill", mark.x, mark.y, 1.5)
    end
  end
end

local function drawWorld()
  game.cameraX, game.cameraY = cameraOffset()
  love.graphics.push()
  love.graphics.translate(-game.cameraX, -game.cameraY)
  drawGround()

  for _, shot in ipairs(game.fearShots) do
    love.graphics.setColor(0.81, 0.44, 1)
    love.graphics.circle("fill", shot.x, shot.y, shot.radius)
  end
  for _, stone in ipairs(game.stones) do
    love.graphics.setColor(0.72, 0.63, 0.54)
    love.graphics.circle("fill", stone.x, stone.y, stone.radius)
    love.graphics.setColor(1, 0.89, 0.73)
    love.graphics.circle("fill", stone.x + stone.radius * 0.32, stone.y - stone.radius * 0.3, stone.radius * 0.28)
  end

  local drawOrder = {}
  for _, tree in ipairs(game.trees) do table.insert(drawOrder, { entity = tree, draw = drawTree }) end
  table.insert(drawOrder, { entity = game.player, draw = drawPlayer })
  for _, enemy in ipairs(game.enemies) do table.insert(drawOrder, { entity = enemy, draw = drawEnemy }) end
  table.sort(drawOrder, function(a, b) return a.entity.y < b.entity.y end)
  for _, item in ipairs(drawOrder) do item.draw(item.entity) end
  love.graphics.pop()
end

local function drawJoystick(x, y, radius, inputX, inputY, color)
  love.graphics.setColor(color[1], color[2], color[3], 0.35)
  love.graphics.circle("fill", x, y, radius)
  love.graphics.setColor(1, 1, 1, 0.18)
  love.graphics.circle("line", x, y, radius)
  love.graphics.setColor(0.92, 0.96, 0.96, 0.88)
  love.graphics.circle("fill", x + inputX * radius * 0.66, y + inputY * radius * 0.66, radius * 0.31)
end

local function drawHud()
  local width, height = love.graphics.getDimensions()
  love.graphics.setFont(game.fonts.hud)
  local seconds = math.floor(game.elapsed)
  local timeText = string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
  love.graphics.setColor(0.06, 0.09, 0.11, 0.82)
  love.graphics.rectangle("fill", width / 2 - 82, 18, 164, 42, 16, 16)
  love.graphics.setColor(0.92, 0.96, 0.96)
  love.graphics.printf("Tiempo " .. timeText, width / 2 - 82, 29, 164, "center")

  local barWidth, barX = 220, width / 2 - 110
  love.graphics.setColor(0.06, 0.09, 0.11, 0.82)
  love.graphics.rectangle("fill", barX, 68, barWidth, 54, 10, 10)
  local fearColor = game.fear >= 75 and { 1, 0.42, 0.42 } or { 0.81, 0.44, 1 }
  love.graphics.setColor(0.92, 0.96, 0.96)
  love.graphics.print("Miedo", barX + 12, 76)
  love.graphics.printf(game.fear .. "%", barX, 76, barWidth - 12, "right")
  love.graphics.setColor(1, 1, 1, 0.16)
  love.graphics.rectangle("fill", barX + 12, 99, barWidth - 24, 8, 4, 4)
  love.graphics.setColor(fearColor[1], fearColor[2], fearColor[3])
  love.graphics.rectangle("fill", barX + 12, 99, (barWidth - 24) * game.fear / 100, 8, 4, 4)

  local leftX, rightX, centerY, radius = joystickGeometry()
  drawJoystick(leftX, centerY, radius, game.moveInput.x, game.moveInput.y, { 0.35, 0.44, 0.50 })
  drawJoystick(rightX, centerY, radius, game.aimInput.x, game.aimInput.y, { 0.34, 0.42, 0.32 })
end

local function drawMenu()
  local width, height = love.graphics.getDimensions()
  love.graphics.clear(0.06, 0.09, 0.13)
  love.graphics.setFont(game.fonts.title)
  love.graphics.setColor(0.48, 0.89, 0.58)
  love.graphics.printf("Survivors Arena", 0, height * 0.31, width, "center")
  love.graphics.setFont(game.fonts.body)
  love.graphics.setColor(0.88, 0.92, 0.92)
  love.graphics.printf("Sobrevive a la horda", 0, height * 0.42, width, "center")
  love.graphics.setColor(0.13, 0.24, 0.19)
  love.graphics.rectangle("fill", width / 2 - 115, height * 0.55, 230, 54, 8, 8)
  love.graphics.setFont(game.fonts.button)
  love.graphics.setColor(0.92, 0.96, 0.92)
  love.graphics.printf("Iniciar partida  [Enter]", width / 2 - 115, height * 0.55 + 17, 230, "center")
  love.graphics.setFont(game.fonts.small)
  love.graphics.setColor(0.78, 0.83, 0.83)
  love.graphics.printf("WASD para moverte | Mantén clic y apunta con el ratón", 20, height * 0.72, width - 40, "center")
  love.graphics.printf("En móvil: usa un dedo en cada joystick", 20, height * 0.77, width - 40, "center")
end

local function drawGameOver()
  local width, height = love.graphics.getDimensions()
  love.graphics.setColor(0, 0, 0, 0.62)
  love.graphics.rectangle("fill", 0, 0, width, height)
  love.graphics.setColor(0.08, 0.12, 0.14, 0.96)
  love.graphics.rectangle("fill", width / 2 - 180, height / 2 - 105, 360, 210, 10, 10)
  love.graphics.setFont(game.fonts.title)
  love.graphics.setColor(0.95, 0.96, 0.94)
  love.graphics.printf("Fin de la partida", width / 2 - 160, height / 2 - 65, 320, "center")
  love.graphics.setFont(game.fonts.body)
  love.graphics.setColor(0.8, 0.84, 0.84)
  love.graphics.printf("El miedo te venció.", width / 2 - 160, height / 2 - 24, 320, "center")
  love.graphics.setColor(0.2, 0.43, 0.28)
  love.graphics.rectangle("fill", width / 2 - 120, height / 2 + 22, 240, 48, 8, 8)
  love.graphics.setFont(game.fonts.button)
  love.graphics.setColor(0.96, 0.97, 0.95)
  love.graphics.printf("Volver a jugar  [R]", width / 2 - 120, height / 2 + 37, 240, "center")
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.math.setRandomSeed(os.time())
  game.fonts = {
    title = love.graphics.newFont(30),
    body = love.graphics.newFont(18),
    button = love.graphics.newFont(16),
    hud = love.graphics.newFont(15),
    small = love.graphics.newFont(14),
  }
end

function love.update(dt)
  if game.state == "playing" then updateGame(dt) end
end

function love.draw()
  if game.state == "menu" then
    drawMenu()
    return
  end
  drawWorld()
  drawHud()
  if game.state == "gameover" then drawGameOver() end
end

function love.keypressed(key)
  if game.state == "menu" and (key == "return" or key == "space") then
    resetGame()
  elseif game.state == "gameover" and (key == "r" or key == "return") then
    resetGame()
  elseif key == "escape" then
    if game.state == "playing" then game.state = "menu" else love.event.quit() end
  end
end

function love.mousepressed(x, y, button)
  if button ~= 1 and button ~= 2 then return end
  local width, height = love.graphics.getDimensions()
  if game.state == "menu" and button == 1 then
    if x >= width / 2 - 115 and x <= width / 2 + 115 and y >= height * 0.55 and y <= height * 0.55 + 54 then
      resetGame()
    end
    return
  elseif game.state == "gameover" and button == 1 then
    resetGame()
    return
  elseif game.state ~= "playing" then
    return
  end

  local leftX, rightX, centerY, radius = joystickGeometry()
  local leftDistance = length(x - leftX, y - centerY)
  local rightDistance = length(x - rightX, y - centerY)
  if math.min(leftDistance, rightDistance) <= radius * 1.25 then
    local side = leftDistance <= rightDistance and "left" or "right"
    game.mouseJoysticks[button] = { side = side, x = 0, y = 0 }
    game.activeMouseButton = button
    setJoystickInput(side, x, y)
  elseif button == 1 then
    game.mouseFiring = true
  end
end

function love.mousemoved(x, y)
  local button = game.activeMouseButton
  local joystick = button and game.mouseJoysticks[button]
  if game.state ~= "playing" or not joystick then return end
  local leftX, rightX, centerY, radius = joystickGeometry()
  local centerX = joystick.side == "left" and leftX or rightX
  if length(x - centerX, y - centerY) <= radius * 1.25 then
    setJoystickInput(joystick.side, x, y)
  else
    game.activeMouseButton = nil
  end
end

function love.mousereleased(_, _, button)
  if button == 1 then game.mouseFiring = false end
  local joystick = game.mouseJoysticks[button]
  if not joystick then return end
  game.mouseJoysticks[button] = nil
  if game.activeMouseButton == button then
    game.activeMouseButton = game.mouseJoysticks[1] and 1 or (game.mouseJoysticks[2] and 2 or nil)
  end
  refreshJoystickInput(joystick.side)
end

function love.touchpressed(id, x, y)
  local width, height = love.graphics.getDimensions()
  local screenX, screenY = x, y
  if game.state == "menu" then
    if screenX >= width / 2 - 115 and screenX <= width / 2 + 115
      and screenY >= height * 0.55 and screenY <= height * 0.55 + 54 then
      resetGame()
    end
    return
  elseif game.state == "gameover" then
    resetGame()
    return
  elseif game.state ~= "playing" then
    return
  end

  local leftX, rightX, centerY, radius = joystickGeometry()
  local leftDistance = length(screenX - leftX, screenY - centerY)
  local rightDistance = length(screenX - rightX, screenY - centerY)
  if math.min(leftDistance, rightDistance) > radius * 1.25 then return end
  local side = leftDistance <= rightDistance and "left" or "right"
  local centerX = side == "left" and leftX or rightX
  local inputX, inputY = joystickValue(screenX, screenY, centerX, centerY, radius)
  local touch = { side = side, x = inputX, y = inputY }
  game.touches[id] = touch
  game[side .. "Touch"] = touch
  refreshJoystickInput(side)
end

function love.touchmoved(id, x, y)
  local touch = game.touches[id]
  if not touch then return end
  local leftX, rightX, centerY, radius = joystickGeometry()
  local centerX = touch.side == "left" and leftX or rightX
  touch.x, touch.y = joystickValue(x, y, centerX, centerY, radius)
  refreshJoystickInput(touch.side)
end

function love.touchreleased(id)
  local touch = game.touches[id]
  if not touch then return end
  if game[touch.side .. "Touch"] == touch then
    game[touch.side .. "Touch"] = nil
    refreshJoystickInput(touch.side)
  end
  game.touches[id] = nil
end