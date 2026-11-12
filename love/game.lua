local UPGRADE_CATALOG = {
  {
    id = "multi_stone",
    name = "Lluvia de Piedras",
    category = "OFENSIVA",
    icon = "[3x]",
    desc = "Lanzas +1 piedra adicional por disparo en abanico.",
    apply = function(player, game)
      player.projectileCount = (player.projectileCount or 1) + 1
    end,
  },
  {
    id = "rapid_fire",
    name = "Brazos Veloces",
    category = "CADENCIA",
    icon = "[>>]",
    desc = "Disparas piedras un 28% más rápido.",
    apply = function(player, game)
      player.fireCooldown = math.max(0.12, (player.fireCooldown or 0.38) * 0.72)
    end,
  },
  {
    id = "swift_boots",
    name = "Zapatos Ligeros",
    category = "MOVILIDAD",
    icon = "[^^]",
    desc = "Velocidad de movimiento del niño +22%.",
    apply = function(player, game)
      player.speed = (player.speed or 160) * 1.22
    end,
  },
  {
    id = "heavy_rocks",
    name = "Roca Volcánica",
    category = "POTENCIA",
    icon = "[##]",
    desc = "Piedras más grandes que perforan +1 enemigo.",
    apply = function(player, game)
      player.stoneRadius = (player.stoneRadius or 7) + 2.5
      player.stonePierce = (player.stonePierce or 1) + 1
    end,
  },
  {
    id = "fear_calm",
    name = "Mente Serena",
    category = "SUPERVIVENCIA",
    icon = "[++]",
    desc = "Disminuye el Miedo acumulado un 40%.",
    apply = function(player, game)
      game.fear = math.max(0, game.fear - 40)
      player.fearResistance = (player.fearResistance or 1.0) * 0.8
    end,
  },
  {
    id = "stone_speed",
    name = "Honda Reforzada",
    category = "ALCANCE",
    icon = "[!!]",
    desc = "Velocidad de proyectil +35% y mayor alcance.",
    apply = function(player, game)
      player.stoneSpeed = (player.stoneSpeed or 390) * 1.35
    end,
  },
  {
    id = "ricochet",
    name = "Piedra Rebotadora",
    category = "TACTICA",
    icon = "[~~]",
    desc = "Tus piedras rebotan hacia otro monstruo cercano.",
    apply = function(player, game)
      player.stoneBounce = (player.stoneBounce or 0) + 1
    end,
  },
  {
    id = "vital_relief",
    name = "Coraje Heroico",
    category = "SUPERVIVENCIA",
    icon = "[**]",
    desc = "Limpia TODO el miedo a 0% de inmediato.",
    apply = function(player, game)
      game.fear = 0
    end,
  },
}

local game = {
  state = "menu",
  fear = 0,
  elapsed = 0,
  spawnTimer = 0,
  stoneCooldown = 0,
  wave = 1,
  enemiesDefeated = 0,
  enemiesTotal = 5,
  enemiesSpawned = 0,
  waveBannerTimer = 0,
  upgradeOptions = {},
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
  spawnInterval = 3.0,
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

local function pick3RandomUpgrades()
  local pool = {}
  for _, u in ipairs(UPGRADE_CATALOG) do
    table.insert(pool, u)
  end
  local result = {}
  for _ = 1, 3 do
    if #pool > 0 then
      local idx = love.math.random(1, #pool)
      table.insert(result, pool[idx])
      table.remove(pool, idx)
    end
  end
  return result
end

local VENEZUELAN_BOSSES = {
  {
    id = "el_silbon",
    name = "EL SILBON",
    subtitle = "El silbador errante de los llanos",
    lore = "Si se escucha lejos... ya esta a tu lado",
    baseHp = 22,
    speed = 52,
    scale = 1.6,
    shotType = "silbon",
    assetKey = "el_silbon",
    color = { 0.96, 0.82, 0.40 },
  },
  {
    id = "la_llorona",
    name = "LA LLORONA",
    subtitle = "El espectro del rio y los sauces",
    lore = "Aaaaay mis hijos... Su llanto hiela el bosque",
    baseHp = 34,
    speed = 46,
    scale = 1.6,
    shotType = "llorona",
    assetKey = "la_llorona",
    color = { 0.45, 0.85, 1.00 },
  },
  {
    id = "el_cabron",
    name = "EL CABRON LEYENDARIO",
    subtitle = "La bestia cornuda de los montes",
    lore = "Blande su temible machete con furia infernal",
    baseHp = 48,
    speed = 56,
    scale = 1.7,
    shotType = "cabron",
    assetKey = "el_cabron",
    color = { 1.00, 0.35, 0.30 },
  },
  {
    id = "duendes",
    name = "LOS DUENDES",
    subtitle = "Espiritus traviesos de los hongos",
    lore = "Embaucan a los caminantes y lanzan oro maldito",
    baseHp = 60,
    speed = 64,
    scale = 1.45,
    shotType = "duendes",
    assetKey = "duendes",
    color = { 0.48, 0.95, 0.45 },
  },
  {
    id = "las_animas",
    name = "LAS ANIMAS",
    subtitle = "Procesion de almas con cirios encendidos",
    lore = "Almas en pena con velas. No las mires de frente",
    baseHp = 76,
    speed = 42,
    scale = 1.65,
    shotType = "animas",
    assetKey = "las_animas",
    color = { 0.88, 0.94, 0.98 },
  },
  {
    id = "brujas",
    name = "LAS BRUJAS",
    subtitle = "Hechiceras de la noche sobre la luna",
    lore = "Surcan el firmamento nocturno en escobas magicas",
    baseHp = 92,
    speed = 60,
    scale = 1.6,
    shotType = "brujas",
    assetKey = "brujas",
    color = { 0.88, 0.48, 0.98 },
  },
}

local function spawnBoss()
  local edge = love.math.random(1, 4)
  local x = edge == 1 and 0 or (edge == 2 and game.worldWidth or love.math.random() * game.worldWidth)
  local y = edge == 3 and 0 or (edge == 4 and game.worldHeight or love.math.random() * game.worldHeight)
  local bossTier = math.floor(game.wave / 5)
  local bossIndex = ((bossTier - 1) % #VENEZUELAN_BOSSES) + 1
  local loop = math.floor((bossTier - 1) / #VENEZUELAN_BOSSES)
  local data = VENEZUELAN_BOSSES[bossIndex]
  local bHp = data.baseHp + loop * 30

  table.insert(game.enemies, {
    isBoss = true,
    bossId = data.id,
    name = data.name,
    subtitle = data.subtitle,
    lore = data.lore,
    color = data.color,
    shotType = data.shotType,
    assetKey = data.assetKey,
    x = x,
    y = y,
    width = 36,
    height = 46,
    scale = data.scale,
    speed = data.speed,
    hp = bHp,
    maxHp = bHp,
    shootTimer = 1.0,
    hitFlash = 0,
    walkTimer = 0,
  })
end

local function spawnEnemy()
  if game.enemiesSpawned >= game.enemiesTotal then return end
  local isBossWave = (game.wave % 5 == 0)
  -- En oleada de jefe, el primer enemigo generado es el Jefe
  if isBossWave and game.enemiesSpawned == 0 then
    spawnBoss()
    game.enemiesSpawned = game.enemiesSpawned + 1
    return
  end

  local edge = love.math.random(1, 4)
  local x = edge == 1 and 0 or (edge == 2 and game.worldWidth or love.math.random() * game.worldWidth)
  local y = edge == 3 and 0 or (edge == 4 and game.worldHeight or love.math.random() * game.worldHeight)
  table.insert(game.enemies, {
    isBoss = false,
    x = x,
    y = y,
    width = 19,
    height = 25,
    scale = 0.72,
    speed = 52 + math.min(26, game.wave * 2),
    hp = 1,
    maxHp = 1,
    shootTimer = math.max(1.3, 2.8 - game.wave * 0.08),
    hitFlash = 0,
  })
  game.enemiesSpawned = game.enemiesSpawned + 1
end

local function startWave(waveNumber)
  game.wave = waveNumber
  game.enemiesDefeated = 0
  game.enemiesSpawned = 0
  game.waveBannerTimer = 3.6
  local isBossWave = (game.wave % 5 == 0)
  if isBossWave then
    local bossTier = math.floor(game.wave / 5)
    local bossIndex = ((bossTier - 1) % #VENEZUELAN_BOSSES) + 1
    game.currentBossData = VENEZUELAN_BOSSES[bossIndex]
    game.enemiesTotal = 1 + math.min(5, 1 + bossTier) -- 1 Boss + esbirros
    game.spawnInterval = 2.0
    game.maxEnemies = 5
  else
    game.currentBossData = nil
    game.enemiesTotal = 4 + (game.wave * 2) -- Oleada 1: 6, Oleada 2: 8, Oleada 3: 10...
    game.spawnInterval = math.max(1.2, 3.2 - game.wave * 0.14)
    game.maxEnemies = math.min(8, 3 + math.floor(game.wave * 0.7))
  end
  game.spawnTimer = 0.5
end

local function triggerWaveUpgrade()
  game.state = "upgrade"
  game.upgradeOptions = pick3RandomUpgrades()
end

local function selectUpgrade(index)
  local option = game.upgradeOptions and game.upgradeOptions[index]
  if option and option.apply then
    option.apply(game.player, game)
  end
  startWave(game.wave + 1)
  game.state = "playing"
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
    projectileCount = 1,
    fireCooldown = 0.38,
    stoneSpeed = 390,
    stoneRadius = 7,
    stonePierce = 1,
    stoneBounce = 0,
    fearResistance = 1.0,
  }
  game.fear = 0
  game.elapsed = 0
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

  startWave(1)
  game.state = "playing"
end

local function fireFearShot(enemy)
  local dx, dy = game.player.x - enemy.x, game.player.y - enemy.y
  local magnitude = length(dx, dy)
  if magnitude == 0 then return end
  local baseAngle = math.atan2(dy, dx)
  local shots = enemy.isBoss and 3 or 1
  local spread = 0.28
  local startAngle = baseAngle - (shots - 1) * spread / 2
  for i = 1, shots do
    local angle = (shots == 1) and baseAngle or (startAngle + (i - 1) * spread)
    table.insert(game.fearShots, {
      x = enemy.x,
      y = enemy.y,
      vx = math.cos(angle) * (enemy.isBoss and 165 or 145),
      vy = math.sin(angle) * (enemy.isBoss and 165 or 145),
      radius = enemy.isBoss and 13 or 10,
      shotType = enemy.shotType or "fear",
      color = enemy.color or { 0.81, 0.44, 1.0 },
    })
  end
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
  game.waveBannerTimer = math.max(0, game.waveBannerTimer - dt)

  game.spawnTimer = game.spawnTimer + dt
  if game.spawnTimer >= game.spawnInterval then
    game.spawnTimer = 0
    if game.enemiesSpawned < game.enemiesTotal and #game.enemies < game.maxEnemies then
      spawnEnemy()
    end
  end

  for _, enemy in ipairs(game.enemies) do
    if enemy.hitFlash and enemy.hitFlash > 0 then
      enemy.hitFlash = enemy.hitFlash - dt
    end
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
      enemy.shootTimer = enemy.isBoss and 1.8 or 2.5
    end
  end

  if length(game.aimInput.x, game.aimInput.y) > 0 then
    game.stoneCooldown = game.stoneCooldown - dt
    if game.stoneCooldown <= 0 then
      local count = game.player.projectileCount or 1
      local speed = game.player.stoneSpeed or 390
      local baseVx = game.aimInput.x * speed
      local baseVy = game.aimInput.y * speed
      local baseAngle = math.atan2(baseVy, baseVx)
      local spread = 0.22
      local startAngle = baseAngle - (count - 1) * spread / 2

      for i = 1, count do
        local angle = (count == 1) and baseAngle or (startAngle + (i - 1) * spread)
        table.insert(game.stones, {
          x = game.player.x,
          y = game.player.y,
          vx = math.cos(angle) * speed,
          vy = math.sin(angle) * speed,
          radius = game.player.stoneRadius or 7,
          pierce = game.player.stonePierce or 1,
          bounce = game.player.stoneBounce or 0,
          hitEnemies = {},
          rotation = love.math.random() * math.pi * 2,
          spin = (love.math.random() > 0.5 and 1 or -1) * (10 + love.math.random() * 8),
        })
      end
      game.stoneCooldown = game.player.fireCooldown or 0.38
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
      local damage = math.floor(20 * (game.player.fearResistance or 1.0))
      game.fear = math.min(100, game.fear + damage)
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
    local hitEnemyIndex
    for enemyIndex, enemy in ipairs(game.enemies) do
      local left, top = enemy.x - enemy.width / 2, enemy.y - enemy.height
      if not stone.hitEnemies[enemy] and overlapsCircleRect(stone.x, stone.y, stone.radius, left, top, enemy.width, enemy.height) then
        stone.hitEnemies[enemy] = true
        enemy.hp = (enemy.hp or 1) - 1
        enemy.hitFlash = 0.16
        if enemy.hp <= 0 then
          hitEnemyIndex = enemyIndex
        end
        stone.pierce = (stone.pierce or 1) - 1
        if stone.pierce <= 0 then
          if (stone.bounce or 0) > 0 then
            stone.bounce = stone.bounce - 1
            stone.pierce = 1
            -- Rebote hacia otro enemigo si hay
            local nearestEnemy
            local minDist = 99999
            for _, otherE in ipairs(game.enemies) do
              if otherE ~= enemy and not stone.hitEnemies[otherE] then
                local d = length(otherE.x - stone.x, otherE.y - stone.y)
                if d < minDist then minDist = d; nearestEnemy = otherE end
              end
            end
            if nearestEnemy then
              local bdx, bdy = nearestEnemy.x - stone.x, nearestEnemy.y - stone.y
              local bMag = length(bdx, bdy)
              local bSpeed = length(stone.vx, stone.vy)
              stone.vx = (bdx / bMag) * bSpeed
              stone.vy = (bdy / bMag) * bSpeed
            else
              table.remove(game.stones, index)
            end
          else
            table.remove(game.stones, index)
          end
        end
        break
      end
    end
    if hitEnemyIndex then
      local defeated = game.enemies[hitEnemyIndex]
      if defeated.isBoss then
        game.fear = math.max(0, game.fear - 35)
      end
      table.remove(game.enemies, hitEnemyIndex)
      game.enemiesDefeated = game.enemiesDefeated + 1
      if game.enemiesDefeated >= game.enemiesTotal and #game.enemies == 0 then
        triggerWaveUpgrade()
      end
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

  local sType = shot.shotType or "fear"

  if sType == "silbon" then
    -- Proyectil de El Silbón: fragmento de hueso giratorio y estela de silbido dorada
    love.graphics.setColor(1, 0.85, 0.35, 0.3)
    love.graphics.circle("fill", x - normX * 8, y - normY * 8, r * 0.8)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(t * 2.2)
    love.graphics.setColor(0.96, 0.94, 0.88)
    love.graphics.rectangle("fill", -7, -2.5, 14, 5, 2, 2)
    love.graphics.circle("fill", -7, -3, 3)
    love.graphics.circle("fill", -7, 3, 3)
    love.graphics.circle("fill", 7, -3, 3)
    love.graphics.circle("fill", 7, 3, 3)
    love.graphics.pop()
    return

  elseif sType == "llorona" then
    -- Proyectil de La Llorona: lágrima espectral cian con estela de agua luminosa
    love.graphics.setColor(0.30, 0.80, 1.0, 0.28)
    love.graphics.circle("fill", x, y, r * 1.5)
    love.graphics.setColor(0.55, 0.90, 1.0, 0.85)
    love.graphics.circle("fill", x, y, r * 0.85)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.circle("fill", x - normX * 3, y - normY * 3, r * 0.4)
    return

  elseif sType == "cabron" then
    -- Proyectil de El Cabrón: tajo de fuego carmesí
    love.graphics.setColor(1.0, 0.25, 0.15, 0.35)
    love.graphics.circle("fill", x, y, r * 1.5)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(math.atan2(dirY, dirX))
    love.graphics.setColor(1.0, 0.38, 0.20)
    love.graphics.polygon("fill", -13, -6, 12, 0, -13, 6)
    love.graphics.setColor(1.0, 0.88, 0.35)
    love.graphics.circle("fill", 3, 0, 3)
    love.graphics.pop()
    return

  elseif sType == "duendes" then
    -- Proyectil de Los Duendes: moneda de oro giratoria y esporas verdes
    love.graphics.setColor(0.4, 0.92, 0.4, 0.32)
    love.graphics.circle("fill", x - normX * 8, y - normY * 8, r * 0.75)
    love.graphics.setColor(1.0, 0.85, 0.20, 0.95)
    love.graphics.circle("fill", x, y, r * 0.8)
    love.graphics.setColor(0.85, 0.65, 0.10)
    love.graphics.circle("line", x, y, r * 0.8)
    love.graphics.setColor(1, 1, 0.8, 0.9)
    love.graphics.circle("fill", x - 2, y - 2, r * 0.3)
    return

  elseif sType == "animas" then
    -- Proyectil de Las Ánimas: cirio espectral con llama dorada
    love.graphics.setColor(1.0, 0.88, 0.40, 0.38)
    love.graphics.circle("fill", x, y, r * 1.5)
    love.graphics.setColor(1.0, 0.82, 0.25, 0.95)
    love.graphics.circle("fill", x, y, r * 0.8)
    love.graphics.setColor(1, 1, 1, 0.98)
    love.graphics.circle("fill", x, y, r * 0.4)
    return

  elseif sType == "brujas" then
    -- Proyectil de Las Brujas: estrella mágica púrpura de 4 puntas
    love.graphics.setColor(0.85, 0.35, 1.0, 0.35)
    love.graphics.circle("fill", x, y, r * 1.5)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(t * 3)
    love.graphics.setColor(0.92, 0.60, 1.0, 0.95)
    love.graphics.polygon("fill", 0, -11, 3, -3, 11, 0, 3, 3, 0, 11, -3, 3, -11, 0, -3, -3)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", 0, 0, 2.5)
    love.graphics.pop()
    return
  end

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

local function drawVenezuelanBoss(enemy)
  local x, y = enemy.x, enemy.y
  local s = enemy.scale or 1.75
  local id = enemy.bossId or "el_silbon"
  local t = (game.elapsed or 0) * 5
  local phase = enemy.walkTimer or 0
  local swing = math.sin(phase) * 3.8
  local bob = math.abs(math.sin(phase)) * 1.6

  -- Dirección hacia donde mira el boss
  local mFacingX = enemy.facingX or 0
  local lookDir = mFacingX < -0.15 and -1 or (mFacingX > 0.15 and 1 or 1)

  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(s, s)
  love.graphics.push()
  love.graphics.scale(lookDir, 1)

  if id == "el_silbon" then
    -- =========================================================================
    -- 1. EL SILBÓN (El silbador errante de los llanos con su saco de huesos)
    -- =========================================================================
    -- Sombra doble realista sobre el suelo llanero
    love.graphics.setColor(0.015, 0.03, 0.02, 0.65)
    love.graphics.ellipse("fill", 0, 0, 24, 7)
    love.graphics.setColor(0.01, 0.02, 0.01, 0.35)
    love.graphics.ellipse("fill", 0, 0, 32, 10)

    -- Piernas largas y enjutas campesinas (con zancadas y tendones)
    -- Pierna izquierda
    love.graphics.setColor(0.16, 0.18, 0.22)
    love.graphics.polygon("fill", -7, -22, -3, -22, -5 + swing * 0.9, -4, -9 + swing * 0.9, -4)
    -- Pierna derecha
    love.graphics.setColor(0.20, 0.22, 0.26)
    love.graphics.polygon("fill", 3, -22, 7, -22, 9 - swing * 0.9, -4, 5 - swing * 0.9, -4)

    -- Pantorrillas y tobillos con tono tostado de sol llanero
    love.graphics.setColor(0.68, 0.46, 0.32)
    love.graphics.rectangle("fill", -8 + swing * 0.9, -4, 4, 4)
    love.graphics.rectangle("fill", 5 - swing * 0.9, -4, 4, 4)
    -- Pies descalzos polvorientos con dedos marcados
    love.graphics.setColor(0.72, 0.50, 0.36)
    love.graphics.polygon("fill", -9 + swing * 0.9, 0, -3 + swing * 0.9, 0, -4 + swing * 0.9, -3, -8 + swing * 0.9, -3)
    love.graphics.polygon("fill", 4 - swing * 0.9, 0, 10 - swing * 0.9, 0, 9 - swing * 0.9, -3, 5 - swing * 0.9, -3)

    love.graphics.push()
    love.graphics.translate(0, -bob)

    -- Pantalones de campesino arremangados y rotos
    love.graphics.setColor(0.22, 0.24, 0.28)
    love.graphics.rectangle("fill", -9, -24, 8, 16, 2, 2)
    love.graphics.rectangle("fill", 1, -24, 8, 16, 2, 2)
    -- Desgarros y parches en las rodillas
    love.graphics.setColor(0.32, 0.35, 0.40)
    love.graphics.rectangle("fill", -8, -16, 4, 4)
    love.graphics.setColor(0.14, 0.16, 0.18)
    love.graphics.line(-9, -10, -7, -7, -5, -10)
    love.graphics.line(1, -10, 3, -7, 5, -10)

    -- Cinturón / faja campesina rústica
    love.graphics.setColor(0.38, 0.24, 0.14)
    love.graphics.rectangle("fill", -10, -25, 20, 3.5, 1, 1)

    -- Torso alto campesino (camisa andrajosa blanca/crema de llanero)
    love.graphics.setColor(0.82, 0.78, 0.70)
    love.graphics.rectangle("fill", -10, -42, 20, 20, 3, 3)
    -- Pliegues de tela y sombras de costillas insinuadas bajo la camisa
    love.graphics.setColor(0.70, 0.65, 0.56)
    love.graphics.line(-4, -40, -4, -26)
    love.graphics.line(-7, -35, -2, -37)
    love.graphics.line(2, -37, 7, -35)
    love.graphics.line(-7, -31, -2, -33)
    love.graphics.line(2, -33, 7, -31)
    -- Dobladillo desgarrado en picos de la camisa
    love.graphics.setColor(0.76, 0.72, 0.64)
    love.graphics.polygon("fill", -10, -22, -7, -19, -4, -22, -1, -19, 2, -22, 5, -19, 8, -22, 10, -24, -10, -24)

    -- Gran Saco de Huesos Macabro a la espalda (yute/arpillera marrón con cuerda)
    love.graphics.setColor(0.40, 0.25, 0.14)
    love.graphics.ellipse("fill", -15, -34, 15, 20)
    love.graphics.setColor(0.55, 0.36, 0.20)
    love.graphics.ellipse("fill", -14, -35, 12, 17)
    -- Textura de tejido tosco y parches de arpillera en el saco
    love.graphics.setColor(0.32, 0.18, 0.10)
    love.graphics.line(-20, -38, -8, -38)
    love.graphics.line(-22, -32, -6, -32)
    love.graphics.line(-20, -26, -8, -26)
    -- Cuerda de cáñamo con nudo atada en el cuello del saco
    love.graphics.setColor(0.82, 0.76, 0.55)
    love.graphics.rectangle("fill", -18, -46, 10, 3.5, 1, 1)
    love.graphics.line(-18, -44, -22, -39)

    -- Múltiples huesos saliendo por la boca del saco
    love.graphics.setColor(0.96, 0.94, 0.88)
    -- 1. Gran Fémur humano detallado
    love.graphics.setLineWidth(3)
    love.graphics.line(-16, -46, -11, -56)
    love.graphics.setLineWidth(1)
    love.graphics.circle("fill", -13, -56, 3)
    love.graphics.circle("fill", -9, -55, 3)
    -- 2. Costilla curvada
    love.graphics.setColor(0.92, 0.90, 0.84)
    love.graphics.arc("line", -18, -50, 6, 0.4, math.pi * 0.85)
    -- 3. Cráneo humano asomando entre los huesos
    love.graphics.setColor(0.94, 0.92, 0.86)
    love.graphics.circle("fill", -18, -42, 5)
    love.graphics.setColor(0.12, 0.10, 0.10)
    love.graphics.circle("fill", -19, -42, 1.2) -- Ojo cráneo
    love.graphics.circle("fill", -16, -42, 1.2)
    love.graphics.rectangle("fill", -18.5, -39, 3, 1.5)

    -- Brazo derecho huesudo campesino
    love.graphics.setColor(0.68, 0.46, 0.32)
    love.graphics.line(9, -38, 12, -26)
    love.graphics.circle("fill", 12, -26, 2.5) -- Codo

    -- Cuello y rostro cadavérico demacrado
    love.graphics.setColor(0.65, 0.44, 0.30)
    love.graphics.rectangle("fill", -3.5, -46, 7, 6)
    -- Rostro alargado y mandíbula marcada
    love.graphics.polygon("fill", -7, -54, 7, -54, 5, -45, -5, -45)
    love.graphics.circle("fill", 0, -51, 7.5)

    -- Rasgos faciales siniestros
    -- Cuencas de ojos profundas en sombra
    love.graphics.setColor(0.18, 0.10, 0.08)
    love.graphics.ellipse("fill", -3.5, -52, 2.4, 2)
    love.graphics.ellipse("fill", 3.5, -52, 2.4, 2)
    -- Brillo blanco espectral vigilante en la mirada
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.circle("fill", -2.8, -52, 1)
    love.graphics.circle("fill", 4.2, -52, 1)

    -- Pómulos y sombras cadavéricas
    love.graphics.setColor(0.50, 0.32, 0.22)
    love.graphics.line(-5, -48, -2, -47)
    love.graphics.line(5, -48, 2, -47)

    -- Nariz afilada y boca fruncida silbando
    love.graphics.setColor(0.45, 0.26, 0.18)
    love.graphics.polygon("fill", 0, -52, -1.5, -49, 1.5, -49)
    love.graphics.circle("fill", 0, -47, 1.4) -- Boca silbando

    -- Mano izquierda huesuda levantada con dedos a los labios en pose de silbido
    love.graphics.setColor(0.68, 0.46, 0.32)
    love.graphics.line(-7, -38, -3, -47)
    love.graphics.line(-3, -47, 0, -47)
    love.graphics.circle("fill", 0, -47, 2)

    -- Gran Sombrero de Paja de Cogollo Llanero Tejido
    -- Copa del sombrero con hendidura de llanero
    love.graphics.setColor(0.76, 0.62, 0.34)
    love.graphics.polygon("fill", -10, -56, -8, -68, -2, -66, 0, -68, 2, -66, 8, -68, 10, -56)
    love.graphics.setColor(0.88, 0.74, 0.44)
    love.graphics.line(-7, -65, 7, -65)
    love.graphics.line(-8, -61, 8, -61)
    -- Ala ancha curvada tejida de llanero
    love.graphics.setColor(0.78, 0.65, 0.36)
    love.graphics.ellipse("fill", 0, -56, 26, 6)
    love.graphics.setColor(0.88, 0.76, 0.44)
    love.graphics.ellipse("fill", 0, -57, 24, 4.5)
    -- Cinta de cuero marrón oscuro con hebilla plateada
    love.graphics.setColor(0.35, 0.18, 0.10)
    love.graphics.rectangle("fill", -9.5, -58, 19, 3, 1, 1)
    love.graphics.setColor(0.85, 0.85, 0.90)
    love.graphics.rectangle("line", -2, -58.5, 4, 4)

    -- Notas musicales doradas flotantes animadas (Silbido maldito)
    for ni = 1, 3 do
      local noteCycle = (t * 2.5 + ni * 2) % 6
      local noteX = 8 + math.sin(t * 3 + ni * 1.5) * 8
      local noteY = -48 - noteCycle * 7
      local noteAlpha = math.max(0, 1.0 - noteCycle / 5.5)
      love.graphics.setColor(1.0, 0.88, 0.30, 0.9 * noteAlpha)
      love.graphics.circle("fill", noteX, noteY, 2.2)
      love.graphics.setLineWidth(1.2)
      love.graphics.line(noteX + 1.8, noteY, noteX + 1.8, noteY - 6)
      love.graphics.line(noteX + 1.8, noteY - 6, noteX + 5, noteY - 4)
      love.graphics.setLineWidth(1)
    end

    love.graphics.pop() -- fin de bob

  elseif id == "la_llorona" then
    -- =========================================================================
    -- 2. LA LLORONA (El espectro del río y los sauces con velo translúcido)
    -- =========================================================================
    local floatY = math.sin(t * 1.6) * 5 - 8
    -- Ondas concéntricas de agua espectral cian bajo sus pies flotantes
    local ripple = (t * 2) % 3
    love.graphics.setColor(0.25, 0.70, 0.95, 0.35 * (1.0 - ripple / 3))
    love.graphics.ellipse("line", 0, 0, 16 + ripple * 14, 5 + ripple * 4)
    love.graphics.setColor(0.12, 0.35, 0.50, 0.4)
    love.graphics.ellipse("fill", 0, 0, 18, 6)

    love.graphics.push()
    love.graphics.translate(0, floatY)

    -- Gran aura gélida azulada pulsante
    local auraPulse = 1.0 + math.sin(t * 2.8) * 0.12
    love.graphics.setColor(0.30, 0.80, 1.0, 0.18 * auraPulse)
    love.graphics.ellipse("fill", 0, -24, 30 * auraPulse, 38 * auraPulse)
    love.graphics.setColor(0.50, 0.90, 1.0, 0.10 * auraPulse)
    love.graphics.ellipse("fill", 0, -24, 42 * auraPulse, 50 * auraPulse)

    -- Vestido de novia largo con múltiples pliegues de seda ondeando al viento
    -- Capa trasera oscura
    love.graphics.setColor(0.62, 0.76, 0.88, 0.85)
    love.graphics.polygon("fill", -12, -32, 12, -32, 18 + math.sin(t * 2.2) * 4, 4, -18 + math.cos(t * 2.2) * 4, 4)
    -- Capa frontal iluminada por la luna
    love.graphics.setColor(0.88, 0.94, 1.0, 0.92)
    love.graphics.polygon("fill", -10, -32, 10, -32, 14 + math.sin(t * 2) * 3, 2, -14 + math.cos(t * 2) * 3, 2)
    -- Pliegues verticales de seda
    love.graphics.setColor(0.72, 0.85, 0.95, 0.6)
    love.graphics.line(-5, -30, -7 + math.sin(t * 2) * 2, 0)
    love.graphics.line(0, -30, math.sin(t * 2.1) * 2, 2)
    love.graphics.line(5, -30, 7 + math.sin(t * 2) * 2, 0)
    -- Jirones desvanecientes en la base del vestido (niebla en vez de pies)
    love.graphics.setColor(0.55, 0.82, 0.98, 0.45)
    love.graphics.polygon("fill", -16, 2, -11, -3, -7, 3, -2, -2, 3, 3, 8, -2, 13, 3, 17, 2, 14, 6, -14, 6)

    -- Cabello largo negro medianoche cayendo a los lados de los hombros hasta la cintura
    love.graphics.setColor(0.06, 0.08, 0.12)
    love.graphics.polygon("fill", -10, -42, -15, -16 + math.sin(t * 2) * 2, -7, -18)
    love.graphics.polygon("fill", 10, -42, 15, -16 - math.sin(t * 2) * 2, 7, -18)
    love.graphics.circle("fill", 0, -40, 10)

    -- Torso y cuello blanco pálido
    love.graphics.setColor(0.85, 0.92, 0.96)
    love.graphics.rectangle("fill", -3, -44, 6, 6)
    love.graphics.circle("fill", 0, -42, 8.5)

    -- Manos pálidas fantasmales cubriéndose el rostro en llanto desgarrador
    love.graphics.setColor(0.82, 0.90, 0.96)
    love.graphics.circle("fill", -3.5, -38, 3.5)
    love.graphics.circle("fill", 3.5, -38, 3.5)
    love.graphics.setColor(0.70, 0.80, 0.88)
    love.graphics.line(-4, -40, -4, -36)
    love.graphics.line(4, -40, 4, -36)

    -- Gran Velo translúcido de encaje nupcial cayendo desde la cabeza
    love.graphics.setColor(0.88, 0.95, 1.0, 0.65)
    love.graphics.polygon("fill", -8, -48, 8, -48, 16 + math.sin(t * 1.8) * 3, -12, -16 + math.cos(t * 1.8) * 3, -12)
    love.graphics.setColor(1, 1, 1, 0.45)
    love.graphics.ellipse("fill", 0, -48, 10, 4) -- Coronilla del velo

    -- Lágrimas espectrales de agua y luz cian brotando continuamente
    for di = 1, 4 do
      local dropCycle = (t * 4 + di * 2) % 8
      local dropX = (di % 2 == 0) and (3.5 + math.sin(di) * 1.5) or (-3.5 - math.sin(di) * 1.5)
      local dropY = -36 + dropCycle * 4.5
      love.graphics.setColor(0.40, 0.90, 1.0, math.max(0, 0.95 - dropCycle / 7.5))
      love.graphics.circle("fill", dropX, dropY, 1.8)
    end

    love.graphics.pop() -- fin de floatY

  elseif id == "el_cabron" then
    -- =========================================================================
    -- 3. EL CABRÓN LEYENDARIO (Bestia cornuda imponente con gran machete)
    -- =========================================================================
    -- Sombra densa y pesada en el suelo
    love.graphics.setColor(0.08, 0.02, 0.03, 0.7)
    love.graphics.ellipse("fill", 0, 0, 26, 8)

    -- Patas digitígradas musculosas de macho cabrío con pelaje espeso
    -- Pata izquierda
    love.graphics.setColor(0.18, 0.12, 0.10)
    love.graphics.polygon("fill", -13, -18, -16 + swing, 0, -9 + swing, 0, -7, -18)
    -- Pata derecha
    love.graphics.setColor(0.24, 0.16, 0.12)
    love.graphics.polygon("fill", 7, -18, 9 - swing, 0, 16 - swing, 0, 13, -18)
    -- Pezuñas hendidas pesadas con hendidura central
    love.graphics.setColor(0.06, 0.04, 0.04)
    love.graphics.rectangle("fill", -16 + swing, -3.5, 7, 3.5, 1, 1)
    love.graphics.rectangle("fill", 9 - swing, -3.5, 7, 3.5, 1, 1)
    love.graphics.setColor(0.45, 0.35, 0.30)
    love.graphics.line(-12.5 + swing, -3.5, -12.5 + swing, 0)
    love.graphics.line(12.5 - swing, -3.5, 12.5 - swing, 0)

    love.graphics.push()
    love.graphics.translate(0, -bob)

    -- Torso ancho y musculoso con pelaje negro y marrón rojizo
    love.graphics.setColor(0.20, 0.14, 0.11)
    love.graphics.rectangle("fill", -15, -40, 30, 26, 7, 7)
    love.graphics.setColor(0.30, 0.20, 0.15)
    love.graphics.rectangle("fill", -13, -38, 26, 22, 5, 5)
    -- Pectorales y abdominales marcados
    love.graphics.setColor(0.15, 0.10, 0.08)
    love.graphics.line(0, -38, 0, -18)
    love.graphics.line(-10, -28, 10, -28)
    love.graphics.line(-8, -23, 8, -23)
    -- Mechones de pelaje espeso en los hombros
    love.graphics.setColor(0.14, 0.09, 0.07)
    love.graphics.polygon("fill", -15, -38, -19, -42, -14, -34)
    love.graphics.polygon("fill", 15, -38, 19, -42, 14, -34)

    -- Morral / zurrón de cuero envejecido cruzado en diagonal con correa y hebilla
    love.graphics.setColor(0.48, 0.28, 0.14)
    love.graphics.setLineWidth(3)
    love.graphics.line(-14, -38, 12, -22)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("fill", 8, -26, 10, 10, 2, 2)
    love.graphics.setColor(0.85, 0.70, 0.30)
    love.graphics.rectangle("line", 11, -23, 4, 4) -- Hebilla de latón

    -- Brazo derecho musculoso que empuña el Gran Machete
    love.graphics.setColor(0.24, 0.16, 0.12)
    love.graphics.line(14, -36, 20, -24)
    love.graphics.circle("fill", 20, -24, 3.5)
    -- Empuñadura de madera oscura con remaches de latón
    love.graphics.setColor(0.35, 0.18, 0.08)
    love.graphics.rectangle("fill", 19, -26, 5, 3.5, 1, 1)
    love.graphics.setColor(0.95, 0.80, 0.30)
    love.graphics.circle("fill", 20, -24, 1)
    love.graphics.circle("fill", 23, -24, 1)
    -- Gran Hoja de Machete Plateada con filo reflectante
    love.graphics.setColor(0.85, 0.88, 0.94)
    love.graphics.polygon("fill", 22, -27, 36, -42, 40, -38, 24, -23)
    love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
    love.graphics.line(22, -27, 36, -42) -- Filo reluciente
    -- Muesca de batalla en el machete
    love.graphics.setColor(0.4, 0.4, 0.45)
    love.graphics.line(29, -34, 31, -34)

    -- Cabeza de macho cabrío negro
    love.graphics.setColor(0.18, 0.12, 0.10)
    love.graphics.circle("fill", 0, -46, 11)
    -- Hocico y barba de chivo larga
    love.graphics.setColor(0.12, 0.08, 0.06)
    love.graphics.polygon("fill", -6, -42, 6, -42, 2, -31, -2, -31)
    love.graphics.setColor(0.28, 0.18, 0.14)
    love.graphics.polygon("fill", -3, -33, 3, -33, 0, -26) -- Barba

    -- Enormes Cuernos Curvados Retorcidos de Macho Cabrío
    love.graphics.setColor(0.28, 0.22, 0.18)
    love.graphics.polygon("fill", -8, -52, -22, -68, -14, -71, -3, -53)
    love.graphics.polygon("fill", 8, -52, 22, -68, 14, -71, 3, -53)
    -- Anillos de relieve y textura de queratina en los cuernos
    love.graphics.setColor(0.48, 0.38, 0.30)
    love.graphics.line(-7, -54, -9, -58)
    love.graphics.line(-11, -60, -14, -64)
    love.graphics.line(7, -54, 9, -58)
    love.graphics.line(11, -60, 14, -64)
    love.graphics.line(-16, -67, -19, -70)
    love.graphics.line(16, -67, 19, -70)

    -- Ojos rojos demoníacos incandescentes con destello
    love.graphics.setColor(1.0, 0.15, 0.15)
    love.graphics.circle("fill", -4.5, -47, 3)
    love.graphics.circle("fill", 4.5, -47, 3)
    love.graphics.setColor(1.0, 0.85, 0.20)
    love.graphics.circle("fill", -4.5, -47, 1.2)
    love.graphics.circle("fill", 4.5, -47, 1.2)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.circle("fill", -5, -48, 0.7)
    love.graphics.circle("fill", 4, -48, 0.7)

    -- Brasas ardientes cayendo del cuerpo
    local emberY = -28 + (t * 8 % 16)
    love.graphics.setColor(1.0, 0.40, 0.10, 0.75)
    love.graphics.circle("fill", -12 + math.sin(t * 3) * 4, emberY, 1.5)
    love.graphics.circle("fill", 12 - math.sin(t * 3) * 4, emberY - 4, 1.2)

    love.graphics.pop() -- fin de bob

  elseif id == "duendes" then
    -- =========================================================================
    -- 4. LOS DUENDES (El Rey Duende con oro y hongos mágicos)
    -- =========================================================================
    love.graphics.setColor(0.03, 0.08, 0.04, 0.6)
    love.graphics.ellipse("fill", 0, 0, 20, 6)

    -- Gran Hongo Amanita Muscaria rojo decorativo en el suelo
    love.graphics.setColor(0.92, 0.90, 0.85)
    love.graphics.rectangle("fill", -19, -10, 5, 10, 1, 1) -- Pie hongo
    love.graphics.setColor(0.95, 0.22, 0.18)
    love.graphics.arc("fill", -16.5, -10, 10, math.pi, math.pi * 2) -- Sombrerillo rojo
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.circle("fill", -20, -14, 1.8)
    love.graphics.circle("fill", -14, -15, 2.0)
    love.graphics.circle("fill", -16.5, -17, 1.6)

    local duendeHop = math.abs(math.sin(t * 3.6)) * 4
    love.graphics.push()
    love.graphics.translate(0, -duendeHop)

    -- Piernas verdes con zapatitos campesinos marrones de punta curvada
    love.graphics.setColor(0.35, 0.65, 0.30)
    love.graphics.rectangle("fill", -7, -12, 5, 8)
    love.graphics.rectangle("fill", 2, -12, 5, 8)
    -- Botas con punta rizada hacia arriba
    love.graphics.setColor(0.48, 0.28, 0.16)
    love.graphics.polygon("fill", -10, -5, -2, -5, -1, -2, -11, -2)
    love.graphics.polygon("fill", 1, -5, 9, -5, 10, -2, 0, -2)

    -- Torso verde rechoncho con chaleco de corteza y faja roja
    love.graphics.setColor(0.38, 0.70, 0.32)
    love.graphics.circle("fill", 0, -20, 10.5)
    -- Chaleco marrón con botones dorados
    love.graphics.setColor(0.48, 0.30, 0.18)
    love.graphics.rectangle("fill", -8, -25, 16, 12, 3, 3)
    love.graphics.setColor(0.85, 0.20, 0.20)
    love.graphics.rectangle("fill", -8, -16, 16, 3) -- Faja roja
    love.graphics.setColor(1.0, 0.85, 0.20)
    love.graphics.circle("fill", 0, -21, 1.3)
    love.graphics.circle("fill", 0, -18, 1.3)

    -- Gran Pepita / Esfera de Oro Puro en las manos con destellos en cruz
    love.graphics.setColor(1.0, 0.85, 0.18)
    love.graphics.circle("fill", 0, -19, 6.5)
    love.graphics.setColor(1.0, 0.98, 0.65)
    love.graphics.circle("fill", -2, -21, 2.8)
    -- Destello en cruz de oro
    love.graphics.setColor(1.0, 1.0, 0.90, 0.95)
    love.graphics.line(-4, -19, 4, -19)
    love.graphics.line(0, -23, 0, -15)

    -- Cabeza verde duende con orejas largas puntiagudas
    love.graphics.setColor(0.40, 0.74, 0.34)
    love.graphics.circle("fill", 0, -31, 8.5)
    -- Orejas duende largas con zarcillo dorado
    love.graphics.polygon("fill", -8, -32, -18, -37, -7, -29)
    love.graphics.polygon("fill", 8, -32, 18, -37, 7, -29)
    love.graphics.setColor(1.0, 0.85, 0.20)
    love.graphics.circle("fill", -16, -35, 1.5) -- Pendiente

    -- Ojos negros pícaros, nariz bulbosa y colmillos
    love.graphics.setColor(0.08, 0.12, 0.08)
    love.graphics.circle("fill", -3, -32, 2)
    love.graphics.circle("fill", 3, -32, 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", -2.5, -32.5, 0.8)
    love.graphics.circle("fill", 3.5, -32.5, 0.8)
    -- Nariz bulbosa
    love.graphics.setColor(0.48, 0.82, 0.40)
    love.graphics.circle("fill", 0, -30, 2.2)
    -- Sonrisa pícara con colmillos
    love.graphics.setColor(0.20, 0.10, 0.10)
    love.graphics.arc("fill", 0, -27.5, 3.5, 0.2, math.pi - 0.2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.polygon("fill", -2, -28, -1, -28, -1.5, -26)
    love.graphics.polygon("fill", 1, -28, 2, -28, 1.5, -26)

    -- Gorro puntiagudo marrón de duende con cascabel dorado en la punta
    love.graphics.setColor(0.55, 0.35, 0.20)
    love.graphics.polygon("fill", -9, -35, 9, -35, 16, -50, 4, -38)
    love.graphics.setColor(1.0, 0.85, 0.20)
    love.graphics.circle("fill", 16, -50, 2.5) -- Cascabel

    -- Polvo de oro y esporas mágicas flotando
    for pi = 1, 3 do
      local pX = math.sin(t * 3 + pi * 2) * 14
      local pY = -25 + math.cos(t * 2.5 + pi * 2) * 12
      love.graphics.setColor(1.0, 0.88, 0.20, 0.8)
      love.graphics.circle("fill", pX, pY, 1.2)
    end

    love.graphics.pop() -- fin de duendeHop

  elseif id == "las_animas" then
    -- =========================================================================
    -- 5. LAS ÁNIMAS (Procesión solemne con cirios encendidos)
    -- =========================================================================
    local animFloat = math.sin(t * 1.8) * 3 - 6
    love.graphics.setColor(0.08, 0.12, 0.16, 0.45)
    love.graphics.ellipse("fill", 0, 0, 24, 7)

    love.graphics.push()
    love.graphics.translate(0, animFloat)

    -- Dos ánimas acompañantes fantasmales detrás en procesión solemne
    -- Ánima izquierda
    love.graphics.setColor(0.85, 0.90, 0.96, 0.35)
    love.graphics.polygon("fill", -24, -34, -14, -34, -12, 0, -26, 0)
    love.graphics.circle("fill", -19, -40, 6)
    love.graphics.setColor(1.0, 0.85, 0.30, 0.5)
    love.graphics.circle("fill", -16, -34, 2) -- Vela menor
    -- Ánima derecha
    love.graphics.setColor(0.85, 0.90, 0.96, 0.35)
    love.graphics.polygon("fill", 14, -34, 24, -34, 26, 0, 12, 0)
    love.graphics.circle("fill", 19, -40, 6)
    love.graphics.setColor(1.0, 0.85, 0.30, 0.5)
    love.graphics.circle("fill", 16, -34, 2)

    -- Gran Ánima Guía: Túnica mortuoria de lino blanco con pliegues profundos
    love.graphics.setColor(0.72, 0.80, 0.88, 0.85)
    love.graphics.polygon("fill", -12, -36, 12, -36, 16, 4, -16, 4)
    love.graphics.setColor(0.88, 0.94, 1.0, 0.95)
    love.graphics.polygon("fill", -10, -36, 10, -36, 13, 2, -13, 2)
    -- Pliegues sombreados
    love.graphics.setColor(0.65, 0.74, 0.82, 0.7)
    love.graphics.line(-5, -34, -6, 2)
    love.graphics.line(5, -34, 6, 2)

    -- Capucha blanca cónica que cubre la cabeza en sombra
    love.graphics.setColor(0.88, 0.94, 1.0)
    love.graphics.circle("fill", 0, -42, 10)
    love.graphics.polygon("fill", -9, -42, 9, -42, 0, -55) -- Pico de la capucha

    -- Rostro en profunda penumbra abisal
    love.graphics.setColor(0.10, 0.14, 0.18, 0.98)
    love.graphics.circle("fill", 0, -40, 7)
    -- Ojos de alma en pena (fuegos fatuos azul cian)
    love.graphics.setColor(0.40, 0.88, 1.0, 0.95)
    love.graphics.circle("fill", -3, -40, 1.6)
    love.graphics.circle("fill", 3, -40, 1.6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", -2.8, -40.5, 0.7)
    love.graphics.circle("fill", 3.2, -40.5, 0.7)

    -- Manos esqueléticas sosteniendo el gran cirio bendito
    love.graphics.setColor(0.88, 0.90, 0.88)
    love.graphics.circle("fill", 4, -32, 2.5)
    love.graphics.circle("fill", 8, -32, 2.5)
    -- Cirio de cera blanca con lágrimas de cera goteando
    love.graphics.setColor(0.94, 0.92, 0.85)
    love.graphics.rectangle("fill", 4.5, -33, 5, 18, 1, 1)
    love.graphics.setColor(0.85, 0.82, 0.75)
    love.graphics.circle("fill", 4.5, -28, 1.2) -- Gota cera
    love.graphics.circle("fill", 9.5, -24, 1.2)

    -- Llama dorada viva titilante del cirio
    local flameFlicker = math.sin(t * 9) * 1.2
    -- Halo cálido envolvente de luz de vela
    love.graphics.setColor(1.0, 0.85, 0.25, 0.26)
    love.graphics.circle("fill", 7, -38, 16)
    love.graphics.setColor(1.0, 0.88, 0.30)
    love.graphics.polygon("fill", 4.5, -33, 9.5, -33, 7 + flameFlicker, -44)
    love.graphics.setColor(1.0, 0.98, 0.70)
    love.graphics.circle("fill", 7, -35, 2.5)

    love.graphics.pop() -- fin de animFloat

  elseif id == "brujas" then
    -- =========================================================================
    -- 6. LAS BRUJAS (Hechiceras surcando el cielo nocturno en escoba mágica)
    -- =========================================================================
    local witchFloat = math.sin(t * 2.2) * 5 - 12
    love.graphics.setColor(0.06, 0.03, 0.08, 0.45)
    love.graphics.ellipse("fill", 0, 0, 24, 7)

    love.graphics.push()
    love.graphics.translate(0, witchFloat)

    -- Escoba mágica de palo retorcido con ataduras de soga
    love.graphics.setColor(0.48, 0.30, 0.16)
    love.graphics.setLineWidth(3.5)
    love.graphics.line(-28, -14, 26, -18)
    love.graphics.setLineWidth(1)
    -- Haz de paja y espigas secas en la popa de la escoba
    love.graphics.setColor(0.82, 0.68, 0.30)
    love.graphics.polygon("fill", -24, -18, -36, -24, -38, -8, -24, -10)
    love.graphics.setColor(0.65, 0.50, 0.22)
    love.graphics.line(-26, -16, -34, -20)
    love.graphics.line(-26, -12, -34, -12)

    -- Capa y vestido gótico morado oscuro ondeando al viento
    love.graphics.setColor(0.18, 0.08, 0.26)
    love.graphics.polygon("fill", -8, -34, 8, -34, 14, -14, -18 + math.sin(t * 3) * 4, -14)
    love.graphics.setColor(0.32, 0.14, 0.44)
    love.graphics.polygon("fill", -6, -34, 6, -34, 10, -14, -12, -14)

    -- Cabello cano plateado desmelenado por el viento
    love.graphics.setColor(0.75, 0.75, 0.80)
    love.graphics.polygon("fill", -4, -38, -14, -34 + math.sin(t * 3) * 2, -6, -30)
    love.graphics.circle("fill", 2, -38, 8)

    -- Rostro de bruja anciana con nariz ganchuda y barbilla curva
    love.graphics.setColor(0.76, 0.70, 0.62)
    love.graphics.circle("fill", 3, -38, 7.5)
    love.graphics.polygon("fill", 8, -39, 14, -37, 9, -35) -- Nariz aguileña
    love.graphics.circle("fill", 13.5, -37, 1) -- Verruga
    love.graphics.polygon("fill", 7, -33, 11, -32, 7, -31) -- Barbilla ganchuda
    -- Ojos amarillos brillantes pícaros
    love.graphics.setColor(1.0, 0.88, 0.20)
    love.graphics.circle("fill", 6, -39, 1.8)
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.circle("fill", 6.5, -39, 0.9)

    -- Sombrero clásico de bruja negro con lazo morado y hebilla dorada
    love.graphics.setColor(0.12, 0.08, 0.16)
    love.graphics.ellipse("fill", 3, -44, 18, 4.5) -- Ala ancha
    love.graphics.polygon("fill", -6, -44, 11, -44, 16, -62, 5, -44) -- Copa picuda torcida
    love.graphics.setColor(0.70, 0.25, 0.90)
    love.graphics.rectangle("fill", -3, -47, 13, 3) -- Cinta morada
    love.graphics.setColor(1.0, 0.85, 0.25)
    love.graphics.rectangle("line", 2, -47.5, 4, 4) -- Hebilla dorada

    -- Orbe de energía arcana mágica en la mano libre
    love.graphics.setColor(0.85, 0.35, 1.0, 0.35)
    love.graphics.circle("fill", 16, -26, 6)
    love.graphics.setColor(0.95, 0.60, 1.0, 0.95)
    love.graphics.circle("fill", 16, -26, 3)

    -- Constelaciones de estrellitas mágicas de 4 puntas girando en órbita
    for si = 1, 3 do
      local sAngle = t * 3 + si * 2.1
      local sx = math.cos(sAngle) * 18
      local sy = -28 + math.sin(sAngle) * 12
      love.graphics.setColor(0.92, 0.60, 1.0, 0.85)
      love.graphics.polygon("fill", sx, sy - 4, sx + 1.2, sy - 1, sx + 4, sy, sx + 1.2, sy + 1, sx, sy + 4, sx - 1.2, sy + 1, sx - 4, sy, sx - 1.2, sy - 1)
    end

    love.graphics.pop() -- fin de witchFloat
  end

  -- Flash blanco al recibir daño
  if enemy.hitFlash and enemy.hitFlash > 0 then
    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.circle("fill", 0, -26, 26)
  end

  love.graphics.pop() -- fin de scale lookDir

  -- Mini barra de vida sobre la cabeza del Boss
  if enemy.maxHp and enemy.maxHp > 1 then
    local hpPct = clamp(enemy.hp / enemy.maxHp, 0, 1)
    local bCol = enemy.color or { 1.0, 0.35, 0.40 }
    love.graphics.setColor(0.06, 0.08, 0.10, 0.88)
    love.graphics.rectangle("fill", -24, -66, 48, 6, 2, 2)
    love.graphics.setColor(bCol[1], bCol[2], bCol[3])
    love.graphics.rectangle("fill", -23, -65, 46 * hpPct, 4, 1, 1)
  end

  love.graphics.pop() -- fin de translate(x, y)
end

local function drawEnemy(enemy)
  if enemy.isBoss then
    drawVenezuelanBoss(enemy)
    return
  end

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

  -- Si es Boss, corona de cuernos espectrales y resplandor
  if enemy.isBoss then
    love.graphics.setColor(1.0, 0.20, 0.25, 0.75 + math.sin(t * 4) * 0.2)
    love.graphics.polygon("fill", -16, -34, -22, -48, -10, -38)
    love.graphics.polygon("fill", 16, -34, 22, -48, 10, -38)
    love.graphics.polygon("fill", -4, -36, 0, -50, 4, -36)
  end

  -- Flash blanco al recibir daño
  if enemy.hitFlash and enemy.hitFlash > 0 then
    love.graphics.setColor(1, 1, 1, 0.65)
    love.graphics.circle("fill", 0, -18, 16)
  end

  love.graphics.pop() -- fin de monsterBob

  -- Mini barra de vida sobre el enemigo si es Boss
  if enemy.isBoss and enemy.maxHp and enemy.maxHp > 1 then
    local hpPct = clamp(enemy.hp / enemy.maxHp, 0, 1)
    love.graphics.setColor(0.06, 0.08, 0.10, 0.85)
    love.graphics.rectangle("fill", -20, -48, 40, 5, 2, 2)
    love.graphics.setColor(0.95, 0.20, 0.25)
    love.graphics.rectangle("fill", -19, -47, 38 * hpPct, 3, 1, 1)
  end

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

  -- 1. Pastilla de tiempo central (o barra de jefe si está presente)
  local currentBoss
  for _, e in ipairs(game.enemies) do
    if e.isBoss then currentBoss = e; break end
  end

  if currentBoss then
    -- Gran Barra de Vida del Jefe en la parte superior
    local barW = math.min(360, width - 110)
    local barH = 15
    local barX = math.floor(width / 2 - barW / 2 + 18)
    local barY = 32
    local bCol = currentBoss.color or { 1.0, 0.35, 0.40 }

    -- Retrato miniatura del Boss (de la colección de arte)
    local portraitImg = game.bossAssets and game.bossAssets[(currentBoss.assetKey or "") .. "_face"]
    local pSize = 42
    local pX = barX - pSize - 10
    local pY = barY - 14

    love.graphics.setColor(0.04, 0.06, 0.08, 0.95)
    love.graphics.rectangle("fill", pX - 2, pY - 2, pSize + 4, pSize + 4, 6, 6)
    if portraitImg then
      love.graphics.setColor(1, 1, 1, 1)
      local sx = pSize / portraitImg:getWidth()
      local sy = pSize / portraitImg:getHeight()
      love.graphics.draw(portraitImg, pX, pY, 0, sx, sy)
    else
      love.graphics.setColor(bCol[1], bCol[2], bCol[3], 0.35)
      love.graphics.rectangle("fill", pX, pY, pSize, pSize, 4, 4)
      love.graphics.setFont(game.fonts.badge or game.fonts.small)
      love.graphics.setColor(1, 1, 1)
      love.graphics.printf("JEFE", pX, pY + 14, pSize, "center")
    end
    love.graphics.setColor(bCol[1], bCol[2], bCol[3], 0.95)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", pX - 2, pY - 2, pSize + 4, pSize + 4, 6, 6)

    -- Nombre y subtítulo del Boss
    love.graphics.setFont(game.fonts.button)
    love.graphics.setColor(bCol[1], bCol[2], bCol[3])
    love.graphics.print(currentBoss.name or "JEFE DE PESADILLA", barX, barY - 20)
    love.graphics.setFont(game.fonts.badge or game.fonts.small)
    love.graphics.setColor(0.85, 0.92, 0.90, 0.85)
    love.graphics.print(currentBoss.subtitle or "Leyenda Venezolana", barX + 175, barY - 17)

    -- Barra de salud
    love.graphics.setColor(0.06, 0.08, 0.10, 0.92)
    love.graphics.rectangle("fill", barX - 3, barY - 3, barW + 6, barH + 6, 6, 6)
    love.graphics.setColor(0.20, 0.04, 0.07)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 4, 4)
    local hpPct = clamp(currentBoss.hp / currentBoss.maxHp, 0, 1)
    love.graphics.setColor(bCol[1], bCol[2], bCol[3])
    love.graphics.rectangle("fill", barX, barY, barW * hpPct, barH, 4, 4)
    love.graphics.setColor(1.0, 1.0, 1.0, 0.35)
    love.graphics.rectangle("fill", barX, barY, barW * hpPct, barH * 0.42, 3, 3)
    love.graphics.setColor(0.85, 0.70, 0.30)
    love.graphics.rectangle("line", barX - 3, barY - 3, barW + 6, barH + 6, 6, 6)
  else
    love.graphics.setColor(0.06, 0.09, 0.11, 0.82)
    love.graphics.rectangle("fill", width / 2 - 82, 18, 164, 42, 16, 16)
    love.graphics.setColor(0.92, 0.96, 0.96)
    love.graphics.printf("Tiempo " .. timeText, width / 2 - 82, 29, 164, "center")
  end

  -- 2. Barra de Miedo
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

  -- 3. Información de Oleada y progreso de enemigos (esquina superior izquierda)
  local isBossWave = ((game.wave or 1) % 5 == 0)
  local enemiesLeft = math.max(0, (game.enemiesTotal or 0) - (game.enemiesDefeated or 0))
  love.graphics.setColor(0.05, 0.10, 0.08, 0.82)
  love.graphics.rectangle("fill", 16, 96, 136, 44, 8, 8)
  love.graphics.setColor(isBossWave and { 1.0, 0.35, 0.40, 0.55 } or { 0.48, 0.95, 0.65, 0.45 })
  love.graphics.rectangle("line", 16, 96, 136, 44, 8, 8)

  love.graphics.setFont(game.fonts.button)
  if isBossWave then
    love.graphics.setColor(1.0, 0.40, 0.45)
    love.graphics.print("JEFE " .. (game.wave or 1), 24, 100)
  else
    love.graphics.setColor(0.48, 0.95, 0.65)
    love.graphics.print("Oleada " .. (game.wave or 1), 24, 100)
  end

  love.graphics.setFont(game.fonts.small)
  love.graphics.setColor(0.85, 0.92, 0.90)
  love.graphics.print("Restan: " .. enemiesLeft .. " / " .. (game.enemiesTotal or 0), 24, 120)

  -- 4. Anuncio cinematográfico en pantalla de Oleada
  if (game.waveBannerTimer or 0) > 0 then
    local alpha = math.min(1.0, game.waveBannerTimer)
    local bannerY = height * 0.24
    local bData = game.currentBossData
    if isBossWave and bData then
      local bCol = bData.color or { 1.0, 0.35, 0.40 }
      local cardW = 460
      local cardH = 82
      local cardX = math.floor(width / 2 - cardW / 2)

      love.graphics.setColor(0.04, 0.08, 0.07, 0.92 * alpha)
      love.graphics.rectangle("fill", cardX, bannerY - 14, cardW, cardH, 14, 14)
      love.graphics.setColor(bCol[1], bCol[2], bCol[3], alpha)
      love.graphics.rectangle("line", cardX, bannerY - 14, cardW, cardH, 14, 14)

      -- Retrato si existe
      local portraitImg = game.bossAssets and game.bossAssets[bData.assetKey .. "_face"]
      if portraitImg then
        local pSize = 54
        love.graphics.setColor(1, 1, 1, alpha)
        local sx = pSize / portraitImg:getWidth()
        local sy = pSize / portraitImg:getHeight()
        love.graphics.draw(portraitImg, cardX + 16, bannerY, 0, sx, sy)
        love.graphics.setColor(bCol[1], bCol[2], bCol[3], alpha)
        love.graphics.rectangle("line", cardX + 16, bannerY, pSize, pSize, 4, 4)
      end

      local textLeft = portraitImg and (cardX + 80) or cardX
      local textW = portraitImg and (cardW - 90) or cardW
      love.graphics.setFont(game.fonts.hero or game.fonts.title)
      love.graphics.setColor(bCol[1], bCol[2], bCol[3], alpha)
      love.graphics.printf("¡" .. bData.name .. "!", textLeft, bannerY - 6, textW, "center")

      love.graphics.setFont(game.fonts.button)
      love.graphics.setColor(0.95, 0.96, 0.92, alpha)
      love.graphics.printf(bData.subtitle, textLeft, bannerY + 28, textW, "center")

      love.graphics.setFont(game.fonts.small)
      love.graphics.setColor(0.85, 0.90, 0.88, alpha * 0.9)
      love.graphics.printf("\"" .. bData.lore .. "\"", textLeft, bannerY + 50, textW, "center")
    else
      love.graphics.setColor(0.04, 0.08, 0.07, 0.88 * alpha)
      love.graphics.rectangle("fill", width / 2 - 210, bannerY - 14, 420, 68, 12, 12)
      love.graphics.setColor(0.48, 0.95, 0.65, alpha)
      love.graphics.rectangle("line", width / 2 - 210, bannerY - 14, 420, 68, 12, 12)

      love.graphics.setFont(game.fonts.hero or game.fonts.title)
      love.graphics.setColor(0.48, 0.95, 0.65, alpha)
      love.graphics.printf("OLEADA " .. game.wave, 0, bannerY - 4, width, "center")
      love.graphics.setFont(game.fonts.small)
      love.graphics.setColor(0.92, 0.96, 0.94, alpha)
      love.graphics.printf("¡Elimina a todos los monstruos de la pesadilla!", 0, bannerY + 30, width, "center")
    end
  end

  drawMinimap()

  local leftX, rightX, centerY, radius = joystickGeometry()
  drawJoystick(leftX, centerY, radius, game.moveInput.x, game.moveInput.y, { 0.35, 0.44, 0.50 })
  drawJoystick(rightX, centerY, radius, game.aimInput.x, game.aimInput.y, { 0.34, 0.42, 0.32 })
end

local function menuPlayButtonRect()
  local width, height = love.graphics.getDimensions()
  local btnW = 240
  local btnH = 46
  local btnX = math.floor(width / 2 - btnW / 2)
  local btnY = math.floor(height * 0.30)
  return btnX, btnY, btnW, btnH
end

local function isInsideRect(px, py, rx, ry, rw, rh)
  return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- Dibuja al niño sentado en la hierba contemplando la luna en el cielo
local function drawSittingPlayer(x, y, scale)
  local s = scale or 1.2
  love.graphics.push()
  love.graphics.translate(x, y)

  -- Sombra suave en la hierba
  love.graphics.setColor(0.02, 0.04, 0.03, 0.6)
  love.graphics.ellipse("fill", 2 * s, 0, 24 * s, 7 * s)

  -- Mochila aventurera apoyada en el suelo detrás de él (a la izquierda)
  love.graphics.setColor(0.38, 0.20, 0.10)
  love.graphics.rectangle("fill", -22 * s, -16 * s, 13 * s, 15 * s, 3 * s, 3 * s)
  love.graphics.setColor(0.50, 0.27, 0.14)
  love.graphics.rectangle("fill", -20 * s, -15 * s, 10 * s, 13 * s, 2 * s, 2 * s)
  love.graphics.setColor(0.70, 0.68, 0.60)
  love.graphics.line(-20 * s, -10 * s, -12 * s, -10 * s)
  love.graphics.setColor(0.28, 0.14, 0.08)
  love.graphics.line(-16 * s, -14 * s, -10 * s, -3 * s)

  -- Piernas sentadas hacia adelante (hacia la derecha)
  love.graphics.setColor(0.14, 0.20, 0.30)
  love.graphics.rectangle("fill", -6 * s, -12 * s, 17 * s, 8 * s, 3 * s, 3 * s)
  love.graphics.setColor(0.20, 0.30, 0.44)
  love.graphics.rectangle("fill", -5 * s, -11 * s, 15 * s, 6 * s, 2 * s, 2 * s)

  -- Pierna baja y rodillas dobladas en el pasto
  love.graphics.setColor(0.14, 0.20, 0.30)
  love.graphics.rectangle("fill", 6 * s, -9 * s, 12 * s, 7 * s, 2 * s, 2 * s)

  -- Botas de cuero marrón sobre la hierba
  love.graphics.setColor(0.38, 0.24, 0.16)
  love.graphics.rectangle("fill", 14 * s, -9 * s, 10 * s, 7 * s, 2 * s, 2 * s)
  love.graphics.setColor(0.78, 0.74, 0.65)
  love.graphics.rectangle("fill", 14 * s, -3 * s, 10 * s, 3 * s, 1 * s, 1 * s)
  love.graphics.setColor(0.92, 0.88, 0.80)
  love.graphics.line(16 * s, -6 * s, 20 * s, -5 * s)

  -- Torso inclinado descansando cómodamente
  love.graphics.setColor(0.18, 0.40, 0.26)
  love.graphics.rectangle("fill", -10 * s, -28 * s, 16 * s, 18 * s, 4 * s, 4 * s)
  love.graphics.setColor(0.26, 0.54, 0.36)
  love.graphics.rectangle("fill", -8 * s, -27 * s, 13 * s, 16 * s, 3 * s, 3 * s)

  -- Brazo izquierdo apoyado detrás en el suelo
  love.graphics.setColor(0.18, 0.40, 0.26)
  love.graphics.line(-7 * s, -23 * s, -13 * s, -4 * s)
  love.graphics.setColor(0.88, 0.65, 0.46)
  love.graphics.circle("fill", -13 * s, -3 * s, 2.8 * s)

  -- Brazo derecho apoyado sobre la rodilla
  love.graphics.setColor(0.18, 0.40, 0.26)
  love.graphics.line(1 * s, -23 * s, 7 * s, -11 * s)
  love.graphics.setColor(0.88, 0.65, 0.46)
  love.graphics.circle("fill", 7 * s, -11 * s, 2.8 * s)

  -- Pañuelo rojo en el cuello
  love.graphics.setColor(0.80, 0.22, 0.20)
  love.graphics.polygon("fill", -4 * s, -29 * s, 4 * s, -28 * s, 0 * s, -24 * s)

  -- Cuello
  love.graphics.setColor(0.78, 0.54, 0.38)
  love.graphics.rectangle("fill", -2 * s, -33 * s, 6 * s, 5 * s)

  -- Cabeza mirando hacia la luna (inclinada arriba-derecha)
  love.graphics.setColor(0.24, 0.15, 0.10)
  love.graphics.circle("fill", -2 * s, -41 * s, 11 * s)
  love.graphics.setColor(0.34, 0.20, 0.13)
  love.graphics.circle("fill", -2 * s, -42 * s, 10.5 * s)

  -- Rostro sereno mirando hacia la luna
  love.graphics.setColor(0.92, 0.68, 0.48)
  love.graphics.ellipse("fill", 2 * s, -40 * s, 9.5 * s, 10 * s)

  -- Oreja
  love.graphics.setColor(0.88, 0.62, 0.44)
  love.graphics.circle("fill", -6 * s, -39 * s, 2.6 * s)

  -- Mejilla sonrosada
  love.graphics.setColor(0.95, 0.45, 0.45, 0.45)
  love.graphics.ellipse("fill", 4 * s, -38 * s, 2.5 * s, 1.6 * s)

  -- Nariz apuntando hacia la luna (arriba-derecha)
  love.graphics.setColor(0.85, 0.58, 0.42)
  love.graphics.circle("fill", 8 * s, -41 * s, 1.4 * s)

  -- Sonrisa tranquila
  love.graphics.setColor(0.60, 0.28, 0.22)
  love.graphics.arc("line", 5 * s, -36.5 * s, 2.4 * s, 0.2, math.pi - 0.4)

  -- Ojo grande mirando directamente a la luna
  love.graphics.setColor(1, 1, 1, 0.98)
  love.graphics.ellipse("fill", 4.5 * s, -42.5 * s, 3.4 * s, 4.0 * s)
  love.graphics.setColor(0.36, 0.22, 0.14)
  love.graphics.circle("fill", 5.6 * s, -43.8 * s, 2.3 * s)
  love.graphics.setColor(0.08, 0.06, 0.06)
  love.graphics.circle("fill", 5.6 * s, -43.8 * s, 1.3 * s)
  -- Brillo blanco reflejando la luna llena
  love.graphics.setColor(1, 1, 1, 0.98)
  love.graphics.circle("fill", 6.3 * s, -44.8 * s, 1.1 * s)
  love.graphics.circle("fill", 4.8 * s, -43.2 * s, 0.6 * s)

  -- Ceja arqueada con curiosidad
  love.graphics.setColor(0.30, 0.18, 0.12)
  love.graphics.setLineWidth(1.2)
  love.graphics.line(2 * s, -46.5 * s, 7.5 * s, -47.8 * s)

  -- Flequillo y coronilla superior
  love.graphics.setColor(0.38, 0.22, 0.14)
  love.graphics.arc("fill", 0, -44 * s, 10.5 * s, math.pi * 0.95, math.pi * 1.95)
  love.graphics.circle("fill", -1 * s, -48 * s, 7 * s)
  love.graphics.polygon("fill", -9 * s, -44 * s, -4 * s, -45 * s, -7 * s, -50 * s)
  love.graphics.polygon("fill", -4 * s, -47 * s, 2 * s, -46 * s, -1 * s, -52 * s)
  love.graphics.polygon("fill", 2 * s, -46 * s, 7 * s, -44 * s, 4 * s, -50 * s)

  -- Reflejo plateado de la luna en su cabello
  love.graphics.setColor(0.65, 0.78, 0.88, 0.55)
  love.graphics.ellipse("fill", 2 * s, -47 * s, 4.5 * s, 1.8 * s)

  love.graphics.pop()
end

local function drawMenu()
  local width, height = love.graphics.getDimensions()
  local t = game.menuTime or 0
  local mx, my = love.mouse.getPosition()

  -- 1. Fondo degradado de noche profunda (cielo a bosque)
  for y = 0, height, 4 do
    local factor = y / height
    local r = 0.02 + factor * 0.025
    local g = 0.04 + factor * 0.045
    local b = 0.08 + factor * 0.015
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", 0, y, width, 4)
  end

  -- 2. Estrellas titilantes en el firmamento
  if not game.menuStars then
    game.menuStars = {}
    for _ = 1, 50 do
      table.insert(game.menuStars, {
        x = love.math.random(),
        y = love.math.random() * 0.65,
        speed = 1.5 + love.math.random() * 2.5,
        phase = love.math.random() * 10,
        size = love.math.random() < 0.25 and 1.8 or 1.1,
      })
    end
  end
  for _, star in ipairs(game.menuStars) do
    local alpha = 0.25 + 0.65 * (0.5 + 0.5 * math.sin(t * star.speed + star.phase))
    love.graphics.setColor(0.90, 0.95, 1.0, alpha)
    love.graphics.circle("fill", star.x * width, star.y * height, star.size)
  end

  -- 3. Luna llena brillante en la esquina superior derecha
  local moonX, moonY = width - 85, 75
  love.graphics.setColor(0.75, 0.88, 1.0, 0.06)
  love.graphics.circle("fill", moonX, moonY, 60)
  love.graphics.setColor(0.85, 0.94, 1.0, 0.12)
  love.graphics.circle("fill", moonX, moonY, 40)
  love.graphics.setColor(0.94, 0.96, 1.0, 0.95)
  love.graphics.circle("fill", moonX, moonY, 24)
  -- Cráteres lunares sutiles
  love.graphics.setColor(0.80, 0.85, 0.92, 0.8)
  love.graphics.circle("fill", moonX - 6, moonY - 5, 4.5)
  love.graphics.circle("fill", moonX + 7, moonY + 4, 3.2)
  love.graphics.circle("fill", moonX + 3, moonY - 8, 2.5)

  -- 4. Siluetas de árboles y colinas nocturnas
  local groundY = height * 0.74
  love.graphics.setColor(0.02, 0.045, 0.04)
  love.graphics.ellipse("fill", width * 0.25, groundY + 10, width * 0.45, 40)
  love.graphics.ellipse("fill", width * 0.75, groundY + 12, width * 0.45, 45)

  -- Pinos enmarcando el horizonte
  drawTree({ x = 45, y = groundY + 25, scale = 1.35 })
  drawTree({ x = width - 45, y = groundY + 25, scale = 1.35 })
  drawTree({ x = width - 120, y = groundY + 18, scale = 1.0 })

  -- Capa de suelo nocturno en primer plano
  love.graphics.setColor(0.035, 0.070, 0.055)
  love.graphics.rectangle("fill", 0, groundY, width, height - groundY)
  love.graphics.setColor(0.02, 0.04, 0.035)
  love.graphics.rectangle("fill", 0, groundY + 25, width, height - groundY - 25)

  -- Colina suave donde descansa el niño
  love.graphics.setColor(0.045, 0.085, 0.065)
  love.graphics.ellipse("fill", width * 0.16, groundY + 20, 110, 32)

  -- Briznas de hierba iluminadas
  love.graphics.setColor(0.10, 0.18, 0.14, 0.5)
  for gx = 20, width - 20, 28 do
    love.graphics.line(gx, groundY + 2, gx + 2, groundY - 5, gx + 5, groundY + 1)
  end

  -- 5. El niño sentado en la hierba mirando la luna
  drawSittingPlayer(width * 0.16, groundY + 14, 1.25)

  -- 6. Luciérnagas flotantes del menú
  if not game.menuFireflies then
    game.menuFireflies = {}
    for _ = 1, 26 do
      table.insert(game.menuFireflies, {
        x = love.math.random(),
        y = love.math.random() * 0.85,
        speed = 0.9 + love.math.random() * 1.5,
        seed = love.math.random() * 30,
        size = 1.2 + love.math.random() * 1.4,
      })
    end
  end
  for _, ff in ipairs(game.menuFireflies) do
    local fx = (ff.x * width + math.sin(t * ff.speed + ff.seed) * 22) % width
    local fy = (ff.y * height + math.cos(t * ff.speed * 0.8 + ff.seed) * 16) % height
    local glow = 0.5 + 0.5 * math.sin(t * 3.5 + ff.seed)
    love.graphics.setColor(0.85, 0.98, 0.40, 0.22 * glow)
    love.graphics.circle("fill", fx, fy, 6 * glow + 2)
    love.graphics.setColor(1.0, 1.0, 0.70, 0.85 * glow)
    love.graphics.circle("fill", fx, fy, ff.size)
  end

  -- 7. Título "SURVIVORS ARENA"
  local titleY = math.floor(height * 0.10)

  -- Insignia en forma de diamante esmeralda
  love.graphics.setColor(0.10, 0.25, 0.18, 0.8)
  love.graphics.polygon("fill", width / 2 - 24, titleY - 22, width / 2, titleY - 38, width / 2 + 24, titleY - 22, width / 2, titleY - 10)
  love.graphics.setColor(0.48, 0.95, 0.62)
  love.graphics.polygon("line", width / 2 - 24, titleY - 22, width / 2, titleY - 38, width / 2 + 24, titleY - 22, width / 2, titleY - 10)
  love.graphics.circle("fill", width / 2, titleY - 24, 4)

  -- Sombra proyectada del título
  love.graphics.setFont(game.fonts.hero or game.fonts.title)
  love.graphics.setColor(0.01, 0.02, 0.04, 0.95)
  love.graphics.printf("SURVIVORS ARENA", 0, titleY + 3, width, "center")
  love.graphics.printf("SURVIVORS ARENA", 2, titleY + 2, width, "center")

  -- Título en Verde Esmeralda resplandeciente
  love.graphics.setColor(0.48, 0.95, 0.62)
  love.graphics.printf("SURVIVORS ARENA", 0, titleY, width, "center")

  -- Cápsula del subtítulo
  local subW = 280
  local subH = 26
  local subX = width / 2 - subW / 2
  local subY = titleY + 44
  love.graphics.setColor(0.06, 0.12, 0.10, 0.75)
  love.graphics.rectangle("fill", subX, subY, subW, subH, 13, 13)
  love.graphics.setColor(0.35, 0.70, 0.48, 0.45)
  love.graphics.rectangle("line", subX, subY, subW, subH, 13, 13)

  -- Diamantes decorativos a los lados (dibujados vectorialmente para evitar caracteres rotos)
  love.graphics.setColor(0.48, 0.95, 0.62)
  love.graphics.polygon("fill", subX + 16, subY + 13, subX + 19, subY + 9, subX + 22, subY + 13, subX + 19, subY + 17)
  love.graphics.polygon("fill", subX + subW - 22, subY + 13, subX + subW - 19, subY + 9, subX + subW - 16, subY + 13, subX + subW - 19, subY + 17)

  love.graphics.setFont(game.fonts.badge or game.fonts.small)
  love.graphics.setColor(0.85, 0.94, 0.90)
  love.graphics.printf("NOCHE EN EL BOSQUE MALDITO", subX, subY + 6, subW, "center")

  -- 8. Botón Principal "JUGAR AHORA"
  local btnX, btnY, btnW, btnH = menuPlayButtonRect()
  local isHover = isInsideRect(mx, my, btnX, btnY, btnW, btnH)

  -- Sombra del botón
  love.graphics.setColor(0.01, 0.03, 0.02, 0.6)
  love.graphics.rectangle("fill", btnX, btnY + 4, btnW, btnH, 12, 12)

  if isHover then
    love.graphics.setColor(0.24, 0.62, 0.38)
    love.graphics.rectangle("fill", btnX - 1, btnY - 2, btnW + 2, btnH + 2, 12, 12)
    love.graphics.setColor(0.32, 0.80, 0.50)
    love.graphics.rectangle("fill", btnX, btnY - 1, btnW, btnH, 11, 11)
    love.graphics.setColor(0.85, 1.0, 0.90)
    love.graphics.rectangle("line", btnX - 1, btnY - 2, btnW + 2, btnH + 2, 12, 12)
  else
    love.graphics.setColor(0.12, 0.34, 0.20)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 12, 12)
    love.graphics.setColor(0.18, 0.48, 0.28)
    love.graphics.rectangle("fill", btnX + 1, btnY + 1, btnW - 2, btnH - 2, 11, 11)
    love.graphics.setColor(0.48, 0.89, 0.60, 0.70 + 0.25 * math.sin(t * 4))
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 12, 12)
  end

  -- Icono vector de Play ▶ dibujado limpiamente sin depender de fuentes
  local triColor = isHover and { 1, 1, 1 } or { 0.92, 0.98, 0.94 }
  love.graphics.setColor(triColor[1], triColor[2], triColor[3])
  love.graphics.polygon("fill", btnX + 44, btnY + 16, btnX + 44, btnY + 30, btnX + 57, btnY + 23)

  -- Texto del botón
  love.graphics.setFont(game.fonts.button)
  love.graphics.setColor(0.03, 0.08, 0.05, 0.85)
  love.graphics.printf("JUGAR AHORA  [Enter]", btnX + 8, btnY + 15, btnW, "center")
  love.graphics.setColor(0.96, 0.99, 0.96)
  love.graphics.printf("JUGAR AHORA  [Enter]", btnX + 8, btnY + 14, btnW, "center")

  -- 9. Tarjeta de Guía Rápida de Controles (Dispersada, amplia y sin colisiones)
  local cardW = math.min(520, width - 40)
  local cardH = 106
  local cardX = math.floor(width / 2 - cardW / 2)
  local cardY = math.floor(height * 0.44)

  -- Panel translúcido estilizado
  love.graphics.setColor(0.04, 0.08, 0.07, 0.88)
  love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 12, 12)
  love.graphics.setColor(0.28, 0.55, 0.40, 0.45)
  love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 12, 12)

  -- Título de la tarjeta
  love.graphics.setFont(game.fonts.body or game.fonts.button)
  love.graphics.setColor(0.48, 0.95, 0.65)
  love.graphics.printf("GUIA RAPIDA DE SUPERVIVENCIA", cardX, cardY + 9, cardW, "center")

  -- Línea divisoria sutil
  love.graphics.setColor(0.20, 0.40, 0.30, 0.35)
  love.graphics.line(cardX + 20, cardY + 29, cardX + cardW - 20, cardY + 29)

  -- 3 Filas perfectamente dispersadas sin encimarse
  love.graphics.setFont(game.fonts.small)

  -- Fila 1: Movimiento
  love.graphics.setColor(0.45, 0.88, 0.60)
  love.graphics.print("[ W, A, S, D  /  Joy Izq ]", cardX + 20, cardY + 36)
  love.graphics.setColor(0.88, 0.94, 0.92)
  love.graphics.print("Mover al personaje", cardX + 225, cardY + 36)

  -- Fila 2: Disparo
  love.graphics.setColor(0.45, 0.88, 0.60)
  love.graphics.print("[ Clic y apuntar  /  Joy Der ]", cardX + 20, cardY + 58)
  love.graphics.setColor(0.88, 0.94, 0.92)
  love.graphics.print("Lanzar piedras a los monstruos", cardX + 225, cardY + 58)

  -- Fila 3: Alerta
  love.graphics.setColor(1.0, 0.45, 0.45)
  love.graphics.print("[ Alerta de Miedo ]", cardX + 20, cardY + 80)
  love.graphics.setColor(1.0, 0.78, 0.78)
  love.graphics.print("¡No permitas que el miedo llegue al 100%!", cardX + 225, cardY + 80)
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

local function upgradeCardRect(index)
  local width, height = love.graphics.getDimensions()
  local cardW = math.min(224, math.floor((width - 70) / 3))
  local cardH = math.min(310, math.floor(height * 0.58))
  local gap = 16
  local totalW = 3 * cardW + 2 * gap
  local startX = math.floor((width - totalW) / 2)
  local x = startX + (index - 1) * (cardW + gap)
  local y = math.floor(height * 0.31)
  return x, y, cardW, cardH
end

local UPGRADE_COLORS = {
  OFENSIVA = { 0.95, 0.32, 0.30 },
  CADENCIA = { 0.30, 0.82, 0.95 },
  MOVILIDAD = { 0.40, 0.92, 0.55 },
  POTENCIA = { 1.00, 0.58, 0.18 },
  SUPERVIVENCIA = { 0.86, 0.46, 0.95 },
  ALCANCE = { 0.38, 0.72, 1.00 },
  TACTICA = { 0.98, 0.80, 0.28 },
}

local function drawUpgradeIcon(id, cx, cy, col)
  love.graphics.setColor(col[1], col[2], col[3])
  if id == "multi_stone" then
    -- 3 piedras en abanico
    love.graphics.circle("fill", cx - 11, cy + 2, 4.5)
    love.graphics.circle("fill", cx, cy - 8, 5)
    love.graphics.circle("fill", cx + 11, cy + 2, 4.5)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.circle("fill", cx, cy - 9, 2)
  elseif id == "rapid_fire" then
    -- Flechas dobles hacia la derecha >>
    love.graphics.polygon("fill", cx - 12, cy - 10, cx - 12, cy + 10, cx - 2, cy)
    love.graphics.polygon("fill", cx, cy - 10, cx, cy + 10, cx + 10, cy)
  elseif id == "swift_boots" then
    -- Alas / flechas ascendentes
    love.graphics.polygon("fill", cx, cy - 12, cx - 12, cy - 1, cx - 7, cy + 1, cx, cy - 5, cx + 7, cy + 1, cx + 12, cy - 1)
    love.graphics.polygon("fill", cx, cy - 2, cx - 10, cy + 8, cx - 6, cy + 10, cx, cy + 4, cx + 6, cy + 10, cx + 10, cy + 8)
  elseif id == "heavy_rocks" then
    -- Roca volcánica poligonal grande con núcleo brillante
    love.graphics.polygon("fill", cx - 12, cy - 4, cx - 6, cy - 12, cx + 6, cy - 11, cx + 12, cy - 3, cx + 9, cy + 10, cx - 7, cy + 11)
    love.graphics.setColor(1, 0.9, 0.4, 0.9)
    love.graphics.circle("fill", cx, cy, 3.5)
  elseif id == "fear_calm" then
    -- Escudo protector de paz
    love.graphics.circle("fill", cx, cy - 2, 9)
    love.graphics.polygon("fill", cx - 9, cy - 2, cx + 9, cy - 2, cx, cy + 11)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.circle("fill", cx, cy - 2, 3.5)
  elseif id == "stone_speed" then
    -- Proyectil con estela de viento
    love.graphics.circle("fill", cx + 7, cy - 4, 5.5)
    love.graphics.setLineWidth(2.2)
    love.graphics.line(cx - 12, cy + 6, cx + 2, cy - 2)
    love.graphics.line(cx - 8, cy + 10, cx - 1, cy + 4)
  elseif id == "ricochet" then
    -- Rebote en zigzag
    love.graphics.setLineWidth(2.5)
    love.graphics.line(cx - 11, cy + 8, cx - 1, cy - 9, cx + 11, cy + 5)
    love.graphics.circle("fill", cx - 11, cy + 8, 3.5)
    love.graphics.circle("fill", cx - 1, cy - 9, 4)
    love.graphics.circle("fill", cx + 11, cy + 5, 3.5)
  elseif id == "vital_relief" then
    -- Estrella de coraje heroico
    love.graphics.polygon("fill", cx, cy - 12, cx + 3, cy - 3, cx + 12, cy, cx + 3, cy + 3, cx, cy + 12, cx - 3, cy + 3, cx - 12, cy, cx - 3, cy - 3)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", cx, cy, 3)
  else
    love.graphics.circle("fill", cx, cy, 9)
  end
end

local function drawUpgradeMenu()
  local width, height = love.graphics.getDimensions()
  local mx, my = love.mouse.getPosition()

  -- 1. Capa de velo semitransparente sobre la batalla congelada
  love.graphics.setColor(0.01, 0.03, 0.04, 0.82)
  love.graphics.rectangle("fill", 0, 0, width, height)

  -- 2. Encabezado principal
  local wasBoss = ((game.wave or 1) % 5 == 0)
  local headerY = math.floor(height * 0.11)

  -- Decoración diamante / insignia
  local badgeCol = wasBoss and { 1.0, 0.35, 0.40 } or { 0.48, 0.95, 0.65 }
  love.graphics.setColor(badgeCol[1], badgeCol[2], badgeCol[3], 0.8)
  love.graphics.polygon("fill", width / 2 - 20, headerY - 18, width / 2, headerY - 32, width / 2 + 20, headerY - 18, width / 2, headerY - 8)
  love.graphics.circle("fill", width / 2, headerY - 20, 3.5)

  love.graphics.setFont(game.fonts.hero or game.fonts.title)
  if wasBoss then
    love.graphics.setColor(0.02, 0.04, 0.06, 0.9)
    love.graphics.printf("¡JEFE DE PESADILLA DERROTADO!", 0, headerY + 2, width, "center")
    love.graphics.setColor(1.0, 0.40, 0.45)
    love.graphics.printf("¡JEFE DE PESADILLA DERROTADO!", 0, headerY, width, "center")
  else
    love.graphics.setColor(0.02, 0.04, 0.06, 0.9)
    love.graphics.printf("¡OLEADA " .. (game.wave or 1) .. " SUPERADA!", 0, headerY + 2, width, "center")
    love.graphics.setColor(0.48, 0.95, 0.65)
    love.graphics.printf("¡OLEADA " .. (game.wave or 1) .. " SUPERADA!", 0, headerY, width, "center")
  end

  -- Subtítulo con instrucciones
  love.graphics.setFont(game.fonts.body or game.fonts.hud)
  love.graphics.setColor(0.85, 0.94, 0.92)
  local subText = wasBoss and "Has triunfado sobre el horror. Elige una bendición para continuar:"
                          or "Elige una bendición para fortalecerte y avanzar a la siguiente oleada:"
  love.graphics.printf(subText, 0, headerY + 44, width, "center")

  -- 3. Las 3 Tarjetas de Habilidad
  local options = game.upgradeOptions or {}
  for i = 1, 3 do
    local opt = options[i]
    if opt then
      local cx, cy, cw, ch = upgradeCardRect(i)
      local isHover = isInsideRect(mx, my, cx, cy, cw, ch)
      local catColor = UPGRADE_COLORS[opt.category] or { 0.48, 0.95, 0.65 }

      -- Sombra de la tarjeta
      love.graphics.setColor(0.0, 0.0, 0.0, 0.55)
      love.graphics.rectangle("fill", cx, cy + 6, cw, ch, 14, 14)

      -- Fondo de la tarjeta
      if isHover then
        love.graphics.setColor(0.06, 0.14, 0.12, 0.96)
        love.graphics.rectangle("fill", cx - 2, cy - 3, cw + 4, ch + 6, 14, 14)
        love.graphics.setColor(catColor[1], catColor[2], catColor[3], 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", cx - 2, cy - 3, cw + 4, ch + 6, 14, 14)
      else
        love.graphics.setColor(0.04, 0.08, 0.08, 0.92)
        love.graphics.rectangle("fill", cx, cy, cw, ch, 12, 12)
        love.graphics.setColor(catColor[1], catColor[2], catColor[3], 0.38)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", cx, cy, cw, ch, 12, 12)
      end

      -- Badge superior de Categoría
      local bW, bH = 100, 20
      local bX, bY = math.floor(cx + cw / 2 - bW / 2), cy + 14
      love.graphics.setColor(catColor[1], catColor[2], catColor[3], 0.22)
      love.graphics.rectangle("fill", bX, bY, bW, bH, 10, 10)
      love.graphics.setColor(catColor[1], catColor[2], catColor[3], 0.85)
      love.graphics.rectangle("line", bX, bY, bW, bH, 10, 10)

      love.graphics.setFont(game.fonts.badge or game.fonts.small)
      love.graphics.setColor(catColor[1], catColor[2], catColor[3], 0.98)
      love.graphics.printf(opt.category, bX, bY + 3, bW, "center")

      -- Emblema circular con el icono vectorial
      local emblemX, emblemY = math.floor(cx + cw / 2), cy + 72
      love.graphics.setColor(catColor[1], catColor[2], catColor[3], isHover and 0.25 or 0.12)
      love.graphics.circle("fill", emblemX, emblemY, 26)
      love.graphics.setColor(catColor[1], catColor[2], catColor[3], isHover and 0.85 or 0.45)
      love.graphics.circle("line", emblemX, emblemY, 26)

      drawUpgradeIcon(opt.id, emblemX, emblemY, catColor)

      -- Nombre de la habilidad
      love.graphics.setFont(game.fonts.button)
      love.graphics.setColor(0.96, 0.98, 0.96)
      love.graphics.printf(opt.name, cx + 8, cy + 112, cw - 16, "center")

      -- Línea divisoria suave
      love.graphics.setColor(0.3, 0.5, 0.4, 0.3)
      love.graphics.line(cx + 20, cy + 142, cx + cw - 20, cy + 142)

      -- Descripción
      love.graphics.setFont(game.fonts.small)
      love.graphics.setColor(0.84, 0.91, 0.88)
      love.graphics.printf(opt.desc, cx + 14, cy + 154, cw - 28, "center")

      -- Botón de selección inferior
      local btnW, btnH = cw - 32, 34
      local btnX, btnY = math.floor(cx + 16), math.floor(cy + ch - 46)

      if isHover then
        love.graphics.setColor(catColor[1], catColor[2], catColor[3], 0.95)
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 8, 8)
        love.graphics.setFont(game.fonts.button)
        love.graphics.setColor(0.04, 0.08, 0.06)
        love.graphics.printf("ELEGIR  [" .. i .. "]", btnX, btnY + 7, btnW, "center")
      else
        love.graphics.setColor(0.12, 0.26, 0.18, 0.9)
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 8, 8)
        love.graphics.setColor(catColor[1], catColor[2], catColor[3], 0.5)
        love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 8, 8)
        love.graphics.setFont(game.fonts.button)
        love.graphics.setColor(0.90, 0.96, 0.92)
        love.graphics.printf("ELEGIR  [" .. i .. "]", btnX, btnY + 7, btnW, "center")
      end
    end
  end

  -- Pie de página con atajos
  love.graphics.setFont(game.fonts.small)
  love.graphics.setColor(0.65, 0.78, 0.74, 0.85)
  love.graphics.printf("Pulsa [1], [2] o [3] en el teclado o haz clic sobre la tarjeta elegida", 0, height - 36, width, "center")
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.math.setRandomSeed(os.time())
  game.fonts = {
    hero = love.graphics.newFont(34),
    title = love.graphics.newFont(26),
    body = love.graphics.newFont(16),
    button = love.graphics.newFont(17),
    hud = love.graphics.newFont(15),
    small = love.graphics.newFont(13),
    badge = love.graphics.newFont(11),
  }

  game.bossAssets = {}
  local bossNames = { "el_silbon", "la_llorona", "el_cabron", "duendes", "las_animas", "brujas" }
  for _, name in ipairs(bossNames) do
    local cardPath = "assets/bosses/" .. name .. ".png"
    local facePath = "assets/bosses/" .. name .. "_face.png"
    local ok1, img1 = pcall(love.graphics.newImage, cardPath)
    if ok1 and img1 then game.bossAssets[name] = img1 end
    local ok2, img2 = pcall(love.graphics.newImage, facePath)
    if ok2 and img2 then game.bossAssets[name .. "_face"] = img2 end
  end
end

function love.update(dt)
  if game.state == "playing" then
    updateGame(dt)
  else
    game.menuTime = (game.menuTime or 0) + dt
  end
end

function love.draw()
  if game.state == "menu" then
    drawMenu()
    return
  end
  drawWorld()
  drawNightVignette()
  drawHud()
  if game.state == "upgrade" then
    drawUpgradeMenu()
  elseif game.state == "gameover" then
    drawGameOver()
  end
end

function love.keypressed(key)
  if game.state == "menu" and (key == "return" or key == "space") then
    resetGame()
  elseif game.state == "gameover" and (key == "r" or key == "return") then
    resetGame()
  elseif game.state == "upgrade" then
    if key == "1" or key == "kp1" then
      selectUpgrade(1)
    elseif key == "2" or key == "kp2" then
      selectUpgrade(2)
    elseif key == "3" or key == "kp3" then
      selectUpgrade(3)
    end
  elseif key == "escape" then
    if game.state == "playing" then game.state = "menu" else love.event.quit() end
  end
end

function love.mousepressed(x, y, button)
  if button ~= 1 and button ~= 2 then return end
  local width, height = love.graphics.getDimensions()
  if game.state == "menu" and button == 1 then
    local btnX, btnY, btnW, btnH = menuPlayButtonRect()
    if isInsideRect(x, y, btnX, btnY, btnW, btnH) then
      resetGame()
    end
    return
  elseif game.state == "gameover" and button == 1 then
    resetGame()
    return
  elseif game.state == "upgrade" and button == 1 then
    for i = 1, 3 do
      local cx, cy, cw, ch = upgradeCardRect(i)
      if isInsideRect(x, y, cx, cy, cw, ch) then
        selectUpgrade(i)
        return
      end
    end
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
    local btnX, btnY, btnW, btnH = menuPlayButtonRect()
    if isInsideRect(screenX, screenY, btnX, btnY, btnW, btnH) then
      resetGame()
    end
    return
  elseif game.state == "gameover" then
    resetGame()
    return
  elseif game.state == "upgrade" then
    for i = 1, 3 do
      local cx, cy, cw, ch = upgradeCardRect(i)
      if isInsideRect(screenX, screenY, cx, cy, cw, ch) then
        selectUpgrade(i)
        return
      end
    end
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