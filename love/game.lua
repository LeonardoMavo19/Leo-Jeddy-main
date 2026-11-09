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
  fireflies = {},
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
  local trunkLeft = tree.x - 6
  local trunkRight = tree.x + 6
  local trunkTop = tree.y - 9
  return playerLeft < trunkRight
    and playerRight > trunkLeft
    and y - 6 < tree.y
    and y > trunkTop
end

local function resetGame()
  local width, height = love.graphics.getDimensions()
  local mapScale = 1.7
  game.worldWidth, game.worldHeight = width * mapScale, height * mapScale
  game.player = {
    x = game.worldWidth / 2,
    y = game.worldHeight / 2,
    width = 20,
    height = 35,
    scale = 0.72,
    speed = 160,
    facingX = 0,
    facingY = 1,
    isMoving = false,
    walkTimer = 0,
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

  game.fireflies = {}
  for _ = 1, 35 do
    table.insert(game.fireflies, {
      x = love.math.random() * game.worldWidth,
      y = love.math.random() * game.worldHeight,
      speed = 1.0 + love.math.random() * 1.8,
      seed = love.math.random() * 50,
      size = 1.2 + love.math.random() * 1.2,
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
      width = 22 * position[3],
      height = 50 * position[3],
      scale = position[3] * 0.75,
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
    width = 19,
    height = 25,
    scale = 0.72,
    speed = 55,
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
  if dx ~= 0 or dy ~= 0 then
    player.facingX, player.facingY = dx, dy
    player.isMoving = true
    player.walkTimer = (player.walkTimer or 0) + dt * 14
  else
    player.isMoving = false
  end
  local speed = player.speed or 160
  local nextX = clamp(player.x + dx * speed * dt, player.width / 2, game.worldWidth - player.width / 2)
  local nextY = clamp(player.y + dy * speed * dt, player.height, game.worldHeight)

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
      local eSpeed = enemy.speed or 55
      enemy.x = enemy.x + dx / magnitude * eSpeed * dt
      enemy.y = enemy.y + dy / magnitude * eSpeed * dt
      enemy.facingX = dx / magnitude
      enemy.facingY = dy / magnitude
      enemy.walkTimer = (enemy.walkTimer or 0) + dt * 11
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
        rotation = love.math.random() * math.pi * 2,
        spin = (love.math.random() > 0.5 and 1 or -1) * (10 + love.math.random() * 8),
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
    shot.animTime = (shot.animTime or 0) + dt
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
    stone.rotation = (stone.rotation or 0) + (stone.spin or 12) * dt
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
  -- Sombra nocturna profunda sobre el suelo
  love.graphics.setColor(0.015, 0.035, 0.03, 0.65)
  love.graphics.ellipse("fill", x, y - 2 * scale, 26 * scale, 7.5 * scale)

  -- Tronco de corteza nocturna oscura
  love.graphics.setColor(0.12, 0.09, 0.07)
  love.graphics.rectangle("fill", x - 7 * scale, y - 25 * scale, 14 * scale, 25 * scale, 4 * scale, 4 * scale)
  love.graphics.setColor(0.18, 0.14, 0.10)
  love.graphics.rectangle("fill", x - 3 * scale, y - 23 * scale, 3 * scale, 20 * scale, 1 * scale, 1 * scale)

  -- Follaje nocturno oscuro (pino de medianoche)
  love.graphics.setColor(0.035, 0.075, 0.060)
  love.graphics.circle("fill", x, y - 48 * scale, 23 * scale)
  love.graphics.circle("fill", x - 14 * scale, y - 43 * scale, 16 * scale)
  love.graphics.circle("fill", x + 14 * scale, y - 43 * scale, 16 * scale)

  -- Capa media de hojas
  love.graphics.setColor(0.055, 0.115, 0.090)
  love.graphics.circle("fill", x - 3 * scale, y - 51 * scale, 18 * scale)
  love.graphics.circle("fill", x + 12 * scale, y - 48 * scale, 12 * scale)

  -- Brillo plateado de luz de luna en la copa superior
  love.graphics.setColor(0.14, 0.26, 0.24, 0.70)
  love.graphics.circle("fill", x - 9 * scale, y - 58 * scale, 7 * scale)
end

local function drawStone(stone)
  love.graphics.push()
  love.graphics.translate(stone.x, stone.y)
  love.graphics.rotate(stone.rotation or 0)
  local r = stone.radius

  -- Polígono facetado irregular de piedra
  local p1x, p1y = -r * 0.85, -r * 0.55
  local p2x, p2y = -r * 0.25, -r * 0.95
  local p3x, p3y =  r * 0.65, -r * 0.80
  local p4x, p4y =  r * 0.95, -r * 0.15
  local p5x, p5y =  r * 0.75,  r * 0.70
  local p6x, p6y =  r * 0.10,  r * 0.95
  local p7x, p7y = -r * 0.70,  r * 0.75
  local p8x, p8y = -r * 0.95,  r * 0.05

  -- Cuerpo base rocoso (gris granito medio)
  love.graphics.setColor(0.48, 0.46, 0.44)
  love.graphics.polygon("fill", p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y, p5x, p5y, p6x, p6y, p7x, p7y, p8x, p8y)

  -- Faceta de sombra inferior-derecha (gris pizarra oscuro)
  love.graphics.setColor(0.28, 0.27, 0.26)
  love.graphics.polygon("fill", 0, 0, p4x, p4y, p5x, p5y, p6x, p6y)
  love.graphics.polygon("fill", 0, 0, p6x, p6y, p7x, p7y)

  -- Faceta iluminada superior-izquierda (gris claro granítico)
  love.graphics.setColor(0.68, 0.66, 0.63)
  love.graphics.polygon("fill", 0, 0, p1x, p1y, p2x, p2y, p3x, p3y)

  -- Resaltado brillante en la arista superior
  love.graphics.setColor(0.82, 0.80, 0.77)
  love.graphics.polygon("fill", 0, 0, p2x, p2y, p3x * 0.7, p3y * 0.7)

  -- Grietas y texturas minerales sobre la roca
  love.graphics.setColor(0.20, 0.19, 0.18, 0.85)
  love.graphics.setLineWidth(1)
  love.graphics.line(0, 0, p1x * 0.7, p1y * 0.7)
  love.graphics.line(0, 0, p5x * 0.75, p5y * 0.75)
  love.graphics.line(p2x * 0.5, p2y * 0.5, p8x * 0.5, p8y * 0.5)

  -- Motas minerales blancas y oscuras
  love.graphics.setColor(0.90, 0.88, 0.85, 0.8)
  love.graphics.points(r * 0.25, -r * 0.2, -r * 0.3, r * 0.15)
  love.graphics.setColor(0.15, 0.14, 0.13, 0.8)
  love.graphics.points(-r * 0.1, -r * 0.4, r * 0.35, r * 0.3)

  -- Contorno rocoso biselado
  love.graphics.setColor(0.24, 0.23, 0.22)
  love.graphics.polygon("line", p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y, p5x, p5y, p6x, p6y, p7x, p7y, p8x, p8y)

  love.graphics.pop()
end

local function drawFearShot(shot)
  local x, y, r = shot.x, shot.y, shot.radius
  local t = (shot.animTime or game.elapsed or 0) * 8
  local dirX, dirY = shot.vx or 0, shot.vy or 0
  local mag = length(dirX, dirY)
  local normX, normY = 0, 0
  if mag > 0 then normX, normY = dirX / mag, dirY / mag end

  -- Estela de miedo ondulante (3 colas espectrales detrás)
  for i = 1, 3 do
    local offset = i * (r * 0.75)
    local wave = math.sin(t + i * 1.5) * (r * 0.4)
    local perpX, perpY = -normY * wave, normX * wave
    local trailX = x - normX * offset + perpX
    local trailY = y - normY * offset + perpY
    local alpha = 0.45 - i * 0.12
    love.graphics.setColor(0.65, 0.25, 0.95, alpha)
    love.graphics.circle("fill", trailX, trailY, r * (0.85 - i * 0.2))
    love.graphics.setColor(0.35, 0.05, 0.60, alpha * 0.8)
    love.graphics.circle("fill", trailX, trailY, r * (0.55 - i * 0.15))
  end

  -- Halo exterior pulsante de miedo (resplandor espectral)
  local pulse = 1 + math.sin(t * 1.2) * 0.15
  love.graphics.setColor(0.85, 0.35, 1.0, 0.35)
  love.graphics.circle("fill", x, y, r * 1.45 * pulse)
  love.graphics.setColor(0.68, 0.18, 0.90, 0.6)
  love.graphics.circle("fill", x, y, r * 1.15 * pulse)

  -- Manto de pesadilla
  love.graphics.setColor(0.45, 0.08, 0.70)
  love.graphics.circle("fill", x, y, r)

  -- Núcleo abisal oscuro
  love.graphics.setColor(0.12, 0.02, 0.22, 0.95)
  love.graphics.circle("fill", x, y, r * 0.65)

  -- Ojos espectrales que miran hacia adelante
  local eyeOffX = normX * (r * 0.25)
  local eyeOffY = normY * (r * 0.25)
  local perpX, perpY = -normY * (r * 0.35), normX * (r * 0.35)

  love.graphics.setColor(1.0, 0.2, 0.3, 0.95)
  love.graphics.circle("fill", x + eyeOffX + perpX, y + eyeOffY + perpY, 1.8)
  love.graphics.circle("fill", x + eyeOffX - perpX, y + eyeOffY - perpY, 1.8)
  love.graphics.setColor(1.0, 0.9, 0.95)
  love.graphics.circle("fill", x + eyeOffX + perpX + normX * 0.5, y + eyeOffY + perpY + normY * 0.5, 0.8)
  love.graphics.circle("fill", x + eyeOffX - perpX + normX * 0.5, y + eyeOffY - perpY + normY * 0.5, 0.8)
end

local function drawPlayer(player)
  local x, y = player.x, player.y
  local s = player.scale or 0.72
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(s, s)

  -- Animación de caminata (balanceo de piernas y cuerpo)
  local legSwing = 0
  local bodyBob = 0
  if player.isMoving then
    local phase = player.walkTimer or 0
    legSwing = math.sin(phase) * 3.5
    bodyBob = math.abs(math.sin(phase)) * 1.5
  end

  -- Determinar si está de espaldas: cuando camina hacia arriba o diagonales superiores
  local facingX = player.facingX or 0
  local facingY = player.facingY or 1
  local isFacingUp = facingY < -0.25

  -- 1. Sombra suave de contacto
  love.graphics.setColor(0.05, 0.13, 0.08, 0.45)
  love.graphics.ellipse("fill", 0, -1, 16, 5)
  love.graphics.setColor(0.04, 0.10, 0.06, 0.30)
  love.graphics.ellipse("fill", 0, -1, 20, 6.5)

  -- 2. Piernas y Botas animadas (zancada alterna)
  local leftLegY = -legSwing
  local rightLegY = legSwing

  -- Bota izquierda
  love.graphics.setColor(0.14, 0.20, 0.30)
  love.graphics.rectangle("fill", -10, -20 + leftLegY * 0.6, 8, 12, 2, 2)
  love.graphics.setColor(0.20, 0.30, 0.44)
  love.graphics.rectangle("fill", -9, -20 + leftLegY * 0.6, 7, 10, 2, 2)
  love.graphics.setColor(0.38, 0.24, 0.16)
  love.graphics.rectangle("fill", -12, -12 + leftLegY, 9, 8, 3, 3)
  love.graphics.setColor(0.78, 0.74, 0.65)
  love.graphics.rectangle("fill", -12, -4 + leftLegY, 9, 4, 1, 1)
  love.graphics.setColor(0.92, 0.88, 0.80)
  love.graphics.line(-10, -9 + leftLegY, -6, -7 + leftLegY)

  -- Bota derecha
  love.graphics.setColor(0.14, 0.20, 0.30)
  love.graphics.rectangle("fill", 2, -20 + rightLegY * 0.6, 8, 12, 2, 2)
  love.graphics.setColor(0.20, 0.30, 0.44)
  love.graphics.rectangle("fill", 2, -20 + rightLegY * 0.6, 7, 10, 2, 2)
  love.graphics.setColor(0.38, 0.24, 0.16)
  love.graphics.rectangle("fill", 3, -12 + rightLegY, 9, 8, 3, 3)
  love.graphics.setColor(0.78, 0.74, 0.65)
  love.graphics.rectangle("fill", 3, -4 + rightLegY, 9, 4, 1, 1)
  love.graphics.setColor(0.92, 0.88, 0.80)
  love.graphics.line(5, -9 + rightLegY, 9, -7 + rightLegY)

  -- Trasladar torso y cabeza según el bamboleo de paso
  love.graphics.push()
  love.graphics.translate(0, -bodyBob)

  if isFacingUp then
    -- ==========================================
    -- VISTA DE ESPALDA (caminando hacia arriba)
    -- ==========================================
    -- Torso trasero chaqueta
    love.graphics.setColor(0.18, 0.40, 0.26)
    love.graphics.rectangle("fill", -11, -37, 22, 17, 5, 5)
    love.graphics.setColor(0.24, 0.50, 0.32)
    love.graphics.rectangle("fill", -9, -37, 18, 16, 4, 4)

    -- Brazos hacia arriba/costados
    love.graphics.setColor(0.18, 0.40, 0.26)
    love.graphics.rectangle("fill", -14, -36, 6, 17, 3, 3)
    love.graphics.rectangle("fill", 8, -36, 6, 17, 3, 3)
    love.graphics.setColor(0.26, 0.54, 0.36)
    love.graphics.rectangle("fill", -13, -35, 5, 14, 2, 2)
    love.graphics.rectangle("fill", 8, -35, 5, 14, 2, 2)

    -- Mochila aventurera grande y detallada en la espalda
    love.graphics.setColor(0.42, 0.22, 0.12)
    love.graphics.rectangle("fill", -11, -38, 22, 20, 5, 5)
    love.graphics.setColor(0.55, 0.30, 0.16)
    love.graphics.rectangle("fill", -9, -36, 18, 16, 4, 4)
    -- Bolsillo trasero de la mochila
    love.graphics.setColor(0.38, 0.20, 0.10)
    love.graphics.rectangle("fill", -7, -29, 14, 8, 3, 3)
    love.graphics.setColor(0.75, 0.72, 0.65)
    love.graphics.line(-7, -25, 7, -25) -- Cremallera bolsillo

    -- Capucha doblada en la espalda
    love.graphics.setColor(0.16, 0.36, 0.24)
    love.graphics.ellipse("fill", 0, -39, 10, 4)

    -- Nuca y cabello abundante desde atrás
    love.graphics.setColor(0.22, 0.14, 0.09)
    love.graphics.circle("fill", 0, -45, 11)
    love.graphics.setColor(0.36, 0.20, 0.13)
    love.graphics.circle("fill", 0, -46, 10.5)
    -- Mechones traseros
    love.graphics.polygon("fill", -10, -45, -5, -40, -1, -45)
    love.graphics.polygon("fill", 0, -45, 5, -40, 10, -45)
    love.graphics.polygon("fill", -8, -52, -2, -56, 3, -52)
    love.graphics.polygon("fill", 2, -52, 7, -56, 11, -49)
    love.graphics.setColor(0.52, 0.32, 0.20)
    love.graphics.ellipse("fill", 0, -50, 7, 3)

  else
    -- =========================================================
    -- VISTA DE FRENTE / 3/4 (abajo, diagonales inferiores o lados)
    -- =========================================================
    -- 1. Cabello trasero (capa detrás de la cabeza)
    love.graphics.setColor(0.24, 0.15, 0.10)
    love.graphics.circle("fill", 0, -45, 11)
    love.graphics.setColor(0.34, 0.20, 0.13)
    love.graphics.circle("fill", 0, -46, 10.5)

    -- Mochila discretamente detrás
    love.graphics.setColor(0.38, 0.20, 0.10)
    love.graphics.rectangle("fill", -11, -37, 22, 16, 4, 4)

    -- 2. Torso frontal y chaqueta
    love.graphics.setColor(0.18, 0.40, 0.26)
    love.graphics.rectangle("fill", -11, -37, 22, 17, 5, 5)
    love.graphics.setColor(0.28, 0.58, 0.38)
    love.graphics.rectangle("fill", -9, -37, 18, 16, 4, 4)

    -- Brazos
    love.graphics.setColor(0.18, 0.40, 0.26)
    love.graphics.rectangle("fill", -14, -36, 6, 17, 3, 3)
    love.graphics.rectangle("fill", 8, -36, 6, 17, 3, 3)
    love.graphics.setColor(0.26, 0.54, 0.36)
    love.graphics.rectangle("fill", -13, -35, 5, 14, 2, 2)
    love.graphics.rectangle("fill", 8, -35, 5, 14, 2, 2)
    -- Puños y Manos
    love.graphics.setColor(0.18, 0.36, 0.24)
    love.graphics.rectangle("fill", -14, -22, 6, 3)
    love.graphics.rectangle("fill", 8, -22, 6, 3)
    love.graphics.setColor(0.88, 0.65, 0.46)
    love.graphics.circle("fill", -11, -18, 3)
    love.graphics.circle("fill", 11, -18, 3)

    -- Tirantes de mochila sobre el pecho
    love.graphics.setColor(0.42, 0.24, 0.12)
    love.graphics.rectangle("fill", -8, -37, 3, 16)
    love.graphics.rectangle("fill", 5, -37, 3, 16)
    love.graphics.setColor(0.70, 0.68, 0.60)
    love.graphics.rectangle("fill", -8.5, -30, 4, 3)
    love.graphics.rectangle("fill", 4.5, -30, 4, 3)

    -- Cremallera y bolsillos
    love.graphics.setColor(0.75, 0.75, 0.72)
    love.graphics.line(0, -36, 0, -22)
    love.graphics.setColor(0.20, 0.44, 0.30)
    love.graphics.rectangle("fill", -7, -27, 5, 4, 1, 1)
    love.graphics.rectangle("fill", 2, -27, 5, 4, 1, 1)

    -- Pañuelo rojo en el cuello
    love.graphics.setColor(0.80, 0.22, 0.20)
    love.graphics.polygon("fill", -6, -37, 6, -37, 0, -33)
    love.graphics.setColor(0.95, 0.35, 0.30)
    love.graphics.circle("fill", 0, -36, 2.5)

    -- 3. Cuello
    love.graphics.setColor(0.78, 0.54, 0.38)
    love.graphics.rectangle("fill", -3, -40, 6, 4)

    -- 4. Rostro (Cara despejada y piel cálida)
    love.graphics.setColor(0.92, 0.68, 0.48)
    love.graphics.circle("fill", 0, -43, 9.8)

    -- Orejas a los costados
    love.graphics.setColor(0.88, 0.62, 0.44)
    love.graphics.circle("fill", -9.5, -43, 2.8)
    love.graphics.circle("fill", 9.5, -43, 2.8)
    love.graphics.setColor(0.75, 0.48, 0.35)
    love.graphics.circle("fill", -9.5, -43, 1.3)
    love.graphics.circle("fill", 9.5, -43, 1.3)

    -- Mejillas sonrosadas
    love.graphics.setColor(0.95, 0.45, 0.45, 0.45)
    love.graphics.ellipse("fill", -5.5, -41, 2.5, 1.5)
    love.graphics.ellipse("fill", 5.5, -41, 2.5, 1.5)

    -- Dirección dinámica de la mirada: hacia donde camina
    local lookX = clamp(facingX * 2.2, -2.4, 2.4)
    local lookY = clamp(facingY * 1.5, -0.6, 1.6)

    -- 5. Ojos grandes y vivos
    -- Esclerótica blanca
    love.graphics.setColor(1, 1, 1, 0.98)
    love.graphics.ellipse("fill", -4 + lookX * 0.4, -43.5 + lookY * 0.3, 3.2, 3.8)
    love.graphics.ellipse("fill", 4 + lookX * 0.4, -43.5 + lookY * 0.3, 3.2, 3.8)
    -- Iris castaño
    love.graphics.setColor(0.36, 0.22, 0.14)
    love.graphics.circle("fill", -4 + lookX, -43.5 + lookY, 2.2)
    love.graphics.circle("fill", 4 + lookX, -43.5 + lookY, 2.2)
    -- Pupila
    love.graphics.setColor(0.08, 0.06, 0.06)
    love.graphics.circle("fill", -4 + lookX, -43.5 + lookY, 1.3)
    love.graphics.circle("fill", 4 + lookX, -43.5 + lookY, 1.3)
    -- Brillo especular blanco
    love.graphics.setColor(1, 1, 1, 0.98)
    love.graphics.circle("fill", -4.8 + lookX, -44.2 + lookY * 0.5, 0.8)
    love.graphics.circle("fill", 3.2 + lookX, -44.2 + lookY * 0.5, 0.8)

    -- Cejas expresivas
    love.graphics.setColor(0.30, 0.18, 0.12)
    love.graphics.setLineWidth(1.2)
    love.graphics.line(-6.5 + lookX * 0.3, -47 + lookY * 0.2, -2 + lookX * 0.3, -47.5 + lookY * 0.2)
    love.graphics.line(2 + lookX * 0.3, -47.5 + lookY * 0.2, 6.5 + lookX * 0.3, -47 + lookY * 0.2)

    -- Nariz y boca
    love.graphics.setColor(0.72, 0.45, 0.32)
    love.graphics.circle("fill", lookX * 0.4, -41 + lookY * 0.3, 1)
    love.graphics.setColor(0.55, 0.24, 0.20)
    love.graphics.arc("line", lookX * 0.4, -38.5 + lookY * 0.3, 2.2, 0.2, math.pi - 0.2)

    -- 6. Flequillo y coronilla superior (SOLO ARRIBA DE LA FRENTE, SIN TAPAR LOS OJOS)
    love.graphics.setColor(0.38, 0.22, 0.14)
    -- Coronilla semicircular superior
    love.graphics.arc("fill", 0, -46, 10.2, math.pi, math.pi * 2)
    love.graphics.circle("fill", 0, -50, 7.5)
    -- Mechones de flequillo peinado hacia los lados arriba de las cejas
    love.graphics.polygon("fill", -9, -47, -4 + lookX * 0.4, -46, -1, -49)
    love.graphics.polygon("fill", -3, -49, 2 + lookX * 0.4, -46, 6, -48)
    love.graphics.polygon("fill", 4, -48, 8 + lookX * 0.4, -46, 10, -47)
    -- Mechones laterales
    love.graphics.polygon("fill", -10, -47, -8, -44, -9, -50)
    love.graphics.polygon("fill", 10, -47, 8, -44, 9, -50)
    -- Highlight coronilla
    love.graphics.setColor(0.55, 0.35, 0.22, 0.8)
    love.graphics.ellipse("fill", -2 + lookX * 0.4, -51, 5.5, 2.2)
  end

  love.graphics.pop() -- fin de bodyBob
  love.graphics.pop() -- fin de drawPlayer
end

local function drawEnemy(enemy)
  local x, y = enemy.x, enemy.y
  local s = enemy.scale or 0.72
  local t = (game.elapsed or 0) * 6
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(s, s)

  -- Animación de zancadas y garras monstruosas
  local phase = enemy.walkTimer or 0
  local clawSwing = math.sin(phase) * 3.5
  local monsterBob = math.abs(math.sin(phase)) * 1.3

  -- 1. Sombra / aura oscura pulsante
  local pulse = 1 + math.sin(t) * 0.08
  love.graphics.setColor(0.12, 0.02, 0.06, 0.5)
  love.graphics.ellipse("fill", 0, -1, 16 * pulse, 6 * pulse)
  love.graphics.setColor(0.35, 0.05, 0.12, 0.25)
  love.graphics.ellipse("fill", 0, -1, 22 * pulse, 8 * pulse)

  -- 2. Garras inferiores animadas (pasos de monstruo)
  local clawPaint = { 0.15, 0.04, 0.08 }
  love.graphics.setColor(clawPaint[1], clawPaint[2], clawPaint[3])
  -- Pata izquierda (animada con clawSwing)
  love.graphics.polygon("fill", -10, -6 - clawSwing, -13, -1 - clawSwing, -7, -4 - clawSwing)
  love.graphics.polygon("fill", -4, -4 - clawSwing * 0.5, -5, 0 - clawSwing * 0.5, -2, -3 - clawSwing * 0.5)
  -- Pata derecha (animada opuesta con +clawSwing)
  love.graphics.polygon("fill", 10, -6 + clawSwing, 13, -1 + clawSwing, 7, -4 + clawSwing)
  love.graphics.polygon("fill", 4, -4 + clawSwing * 0.5, 5, 0 + clawSwing * 0.5, 2, -3 + clawSwing * 0.5)

  -- Trasladar cuerpo y cabeza con monsterBob
  love.graphics.push()
  love.graphics.translate(0, -monsterBob)

  -- 3. Espinas en la espalda y hombros
  love.graphics.setColor(0.18, 0.06, 0.10)
  love.graphics.polygon("fill", -13, -22, -18, -26, -11, -16)
  love.graphics.polygon("fill", 13, -22, 18, -26, 11, -16)
  love.graphics.polygon("fill", -12, -14, -17, -17, -10, -9)
  love.graphics.polygon("fill", 12, -14, 17, -17, 10, -9)

  -- 4. Cuerpo de pesadilla con textura
  love.graphics.setColor(0.26, 0.10, 0.15)
  love.graphics.ellipse("fill", 0, -16, 15, 18)
  love.graphics.setColor(0.48, 0.16, 0.22)
  love.graphics.ellipse("fill", 0, -16, 13, 16)

  -- Vientre / grietas de energía oscura
  love.graphics.setColor(0.80, 0.15, 0.28, 0.65 + math.sin(t * 1.5) * 0.25)
  love.graphics.line(-4, -18, 0, -14, 3, -19)
  love.graphics.line(-2, -12, 1, -9, 4, -13)
  love.graphics.circle("fill", 0, -14, 2)

  -- Dirección de mirada del monstruo hacia el jugador
  local mFacingX = enemy.facingX or 0
  local mLookX = mFacingX < -0.15 and -1.8 or (mFacingX > 0.15 and 1.8 or 0)

  -- 5. Cabeza monstruosa
  love.graphics.setColor(0.32, 0.10, 0.16)
  love.graphics.circle("fill", mLookX * 0.3, -23, 12)
  love.graphics.setColor(0.55, 0.18, 0.24)
  love.graphics.circle("fill", mLookX * 0.3, -23, 10.5)

  -- Cuernos espectrales curvados
  love.graphics.setColor(0.14, 0.04, 0.08)
  love.graphics.polygon("fill", -8 + mLookX * 0.3, -27, -14 + mLookX * 0.5, -36, -3 + mLookX * 0.3, -29)
  love.graphics.polygon("fill", 8 + mLookX * 0.3, -27, 14 + mLookX * 0.5, -36, 3 + mLookX * 0.3, -29)
  love.graphics.setColor(0.70, 0.20, 0.30)
  love.graphics.line(-8 + mLookX * 0.3, -27, -14 + mLookX * 0.5, -36)
  love.graphics.line(8 + mLookX * 0.3, -27, 14 + mLookX * 0.5, -36)

  -- Boca oscura y colmillos
  love.graphics.setColor(0.08, 0.02, 0.04)
  love.graphics.polygon("fill", -7 + mLookX * 0.4, -17, 7 + mLookX * 0.4, -17, 5 + mLookX * 0.4, -12, -5 + mLookX * 0.4, -12)

  love.graphics.setColor(0.96, 0.94, 0.88)
  love.graphics.polygon("fill", -6 + mLookX * 0.4, -17, -4 + mLookX * 0.4, -17, -5 + mLookX * 0.4, -14)
  love.graphics.polygon("fill", -2 + mLookX * 0.4, -17, 0 + mLookX * 0.4, -17, -1 + mLookX * 0.4, -13.5)
  love.graphics.polygon("fill", 2 + mLookX * 0.4, -17, 4 + mLookX * 0.4, -17, 3 + mLookX * 0.4, -14)
  love.graphics.polygon("fill", 5 + mLookX * 0.4, -17, 7 + mLookX * 0.4, -17, 6 + mLookX * 0.4, -13)
  love.graphics.polygon("fill", -4 + mLookX * 0.4, -12, -2 + mLookX * 0.4, -12, -3 + mLookX * 0.4, -15)
  love.graphics.polygon("fill", 1 + mLookX * 0.4, -12, 3 + mLookX * 0.4, -12, 2 + mLookX * 0.4, -15)

  -- Ojos incandescentes de fuego orientados al jugador
  love.graphics.setColor(1.0, 0.65, 0.10, 0.45)
  love.graphics.circle("fill", -4.5 + mLookX, -24, 4)
  love.graphics.circle("fill", 4.5 + mLookX, -24, 4)
  love.graphics.setColor(1.0, 0.85, 0.15)
  love.graphics.ellipse("fill", -4.5 + mLookX, -24, 2.5, 3)
  love.graphics.ellipse("fill", 4.5 + mLookX, -24, 2.5, 3)
  love.graphics.setColor(0.60, 0.05, 0.05)
  love.graphics.ellipse("fill", -4.5 + mLookX, -24, 0.9, 2.5)
  love.graphics.ellipse("fill", 4.5 + mLookX, -24, 0.9, 2.5)
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.circle("fill", -5 + mLookX, -25, 0.7)
  love.graphics.circle("fill", 4 + mLookX, -25, 0.7)

  love.graphics.pop() -- fin de monsterBob
  love.graphics.pop() -- fin de drawEnemy
end

local function drawGround()
  -- Bosque nocturno profundo (verde abeto / medianoche)
  love.graphics.setColor(0.045, 0.080, 0.070)
  love.graphics.rectangle("fill", 0, 0, game.worldWidth, game.worldHeight)
  for _, mark in ipairs(game.groundMarks) do
    if mark.kind == 1 then
      -- Mancha de musgo nocturno
      love.graphics.setColor(0.035, 0.065, 0.055, 0.50)
      love.graphics.ellipse("fill", mark.x, mark.y, 13, 5)
    elseif mark.kind == 2 then
      -- Briznas de hierba bajo la luz de la luna (tono plata tenue)
      love.graphics.setColor(0.12, 0.20, 0.17, 0.45)
      love.graphics.line(mark.x - 3, mark.y + 3, mark.x, mark.y - 3, mark.x + 4, mark.y + 2)
    elseif mark.kind == 3 then
      -- Suelo y sombras de tierra oscura húmeda
      love.graphics.setColor(0.02, 0.035, 0.03, 0.55)
      love.graphics.circle("fill", mark.x, mark.y, 3 + mark.shade * 5)
    else
      -- Guijarros y motas minerales que reflejan la noche
      love.graphics.setColor(0.18, 0.24, 0.26, 0.35)
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
    drawFearShot(shot)
  end
  for _, stone in ipairs(game.stones) do
    drawStone(stone)
  end

  local drawOrder = {}
  for _, tree in ipairs(game.trees) do table.insert(drawOrder, { entity = tree, draw = drawTree }) end
  table.insert(drawOrder, { entity = game.player, draw = drawPlayer })
  for _, enemy in ipairs(game.enemies) do table.insert(drawOrder, { entity = enemy, draw = drawEnemy }) end
  table.sort(drawOrder, function(a, b) return a.entity.y < b.entity.y end)
  for _, item in ipairs(drawOrder) do item.draw(item.entity) end

  -- Luciérnagas flotantes en la noche
  local t = game.elapsed or 0
  if game.fireflies then
    for _, ff in ipairs(game.fireflies) do
      local fx = (ff.x + math.sin(t * ff.speed + ff.seed) * 22) % game.worldWidth
      local fy = (ff.y + math.cos(t * ff.speed * 0.7 + ff.seed) * 18) % game.worldHeight
      local glow = 0.5 + 0.5 * math.sin(t * 3.2 + ff.seed)
      love.graphics.setColor(0.80, 0.95, 0.35, 0.18 * glow)
      love.graphics.circle("fill", fx, fy, 6 * glow + 2)
      love.graphics.setColor(1.0, 1.0, 0.65, 0.85 * glow)
      love.graphics.circle("fill", fx, fy, ff.size)
    end
  end

  love.graphics.pop()
end

-- Viñeta cinematográfica de noche profunda en pantalla
local function drawNightVignette()
  local width, height = love.graphics.getDimensions()
  -- Tinte azul noche sutil global
  love.graphics.setColor(0.015, 0.030, 0.060, 0.18)
  love.graphics.rectangle("fill", 0, 0, width, height)

  -- Marco de oscuridad envolvente en los bordes
  for i = 1, 6 do
    local inset = (6 - i) * 12
    local alpha = 0.05 * i
    love.graphics.setColor(0.01, 0.02, 0.04, alpha)
    love.graphics.rectangle("line", inset, inset, width - inset * 2, height - inset * 2, 24, 24)
  end
end

local function drawJoystick(x, y, radius, inputX, inputY, color)
  love.graphics.setColor(color[1], color[2], color[3], 0.35)
  love.graphics.circle("fill", x, y, radius)
  love.graphics.setColor(1, 1, 1, 0.18)
  love.graphics.circle("line", x, y, radius)
  love.graphics.setColor(0.92, 0.96, 0.96, 0.88)
  love.graphics.circle("fill", x + inputX * radius * 0.66, y + inputY * radius * 0.66, radius * 0.31)
end

local function drawMinimap()
  local width, height = love.graphics.getDimensions()
  local mapW = 108
  local aspectRatio = game.worldWidth / math.max(1, game.worldHeight)
  local mapH = math.floor(clamp(mapW / aspectRatio, 58, 78))
  local mapX = 16
  local mapY = 16

  love.graphics.setColor(0.03, 0.06, 0.08, 0.52)
  love.graphics.rectangle("fill", mapX, mapY, mapW, mapH, 7, 7)
  love.graphics.setColor(0.35, 0.65, 0.78, 0.35)
  love.graphics.rectangle("line", mapX, mapY, mapW, mapH, 7, 7)

  local scaleX = mapW / game.worldWidth
  local scaleY = mapH / game.worldHeight

  love.graphics.setColor(0.22, 0.40, 0.25, 0.4)
  for _, tree in ipairs(game.trees) do
    love.graphics.circle("fill", mapX + tree.x * scaleX, mapY + tree.y * scaleY, 1.6)
  end

  local camW = width * scaleX
  local camH = height * scaleY
  local camLeft = (game.cameraX or 0) * scaleX
  local camTop = (game.cameraY or 0) * scaleY
  love.graphics.setColor(1, 1, 1, 0.06)
  love.graphics.rectangle("fill", mapX + camLeft, mapY + camTop, camW, camH)
  love.graphics.setColor(1, 1, 1, 0.18)
  love.graphics.rectangle("line", mapX + camLeft, mapY + camTop, camW, camH)

  for _, enemy in ipairs(game.enemies) do
    local ex = mapX + enemy.x * scaleX
    local ey = mapY + enemy.y * scaleY
    love.graphics.setColor(1, 0.32, 0.32, 0.25)
    love.graphics.circle("fill", ex, ey, 4.0)
    love.graphics.setColor(1, 0.32, 0.32, 0.90)
    love.graphics.circle("fill", ex, ey, 2.5)
  end

  local px = mapX + game.player.x * scaleX
  local py = mapY + game.player.y * scaleY
  love.graphics.setColor(0.48, 0.89, 0.58, 0.3)
  love.graphics.circle("fill", px, py, 5.0)
  love.graphics.setColor(0.48, 0.89, 0.58, 0.95)
  love.graphics.circle("fill", px, py, 3.2)
  love.graphics.setColor(1, 1, 1, 0.95)
  love.graphics.circle("fill", px, py, 1.2)

  love.graphics.setFont(game.fonts.small)
  love.graphics.setColor(0.78, 0.83, 0.83, 0.45)
  love.graphics.print("MAPA", mapX + 5, mapY + 3)
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

  drawMinimap()

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
  drawNightVignette()
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