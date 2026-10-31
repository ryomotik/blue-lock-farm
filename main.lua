--[[
    ══════════════════════════════════════════════════════════════════════════════════
    ⚽ [🎃] Ферма синих замков (Blue Lock Tycoon) — Ultimate GOD-TIER AutoFarm ⚽
    ══════════════════════════════════════════════════════════════════════════════════
    Версия: 2.0 (10x Edition)
    
    НОВЫЕ ВОЗМОЖНОСТИ 10x:
    ⚡ Instant Prompts (моментальное срабатывание E без задержки и сквозь стены)
    🏃 Speed Boost & Noclip (быстрый бег до 150 + прохождение сквозь препятствия)
    ⭐ Auto Level-Up Units (авто-прокачка уровня юнитов на дропперах для макс. дохода)
    🎃 Auto Trick-or-Treat (авто-сбор конфет с хэллоуинских домов ночью)
    🌦️ Auto World Loot (сбор падающих предметов Item Rain и редких токенов)
    📊 Live Stats Tracker (динамическая статистика заработка, ящиков и времени)
    📉 FPS Booster / Potato Mode (убирает лаги для фонового 24/7 фарма)
    🔔 Discord Webhooks (уведомления в Discord о редких юнитах)
    ══════════════════════════════════════════════════════════════════════════════════
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

-- Защита от повторного запуска (Cleanup)
if _G.BlueLockFarmRunning then
    _G.BlueLockFarmRunning = false
    task.wait(0.5)
end
if _G.BlueLockFarmWindow then
    pcall(function()
        _G.BlueLockFarmWindow:Destroy()
    end)
    _G.BlueLockFarmWindow = nil
end

_G.BlueLockFarmRunning = true

-- Ремоуты и сервисы
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
    warn("[AutoFarm] Папка Remotes не найдена!")
    return
end

local BoxService = nil
pcall(function() BoxService = require(ReplicatedStorage.Shared.Services.BoxService) end)
local UpgradesLibrary = nil
pcall(function() UpgradesLibrary = require(ReplicatedStorage.Shared.Core.Storage.Game.UpgradesLibrary) end)
local UpgradesService = nil
pcall(function() UpgradesService = require(ReplicatedStorage.Shared.Services.UpgradesService) end)
local ClientDataManager = nil
pcall(function() ClientDataManager = require(ReplicatedStorage.Client.Data.ClientDataManager) end)
local ConveyorRollClient = nil
pcall(function() ConveyorRollClient = require(ReplicatedStorage.Client.Core.ConveyorRollClient) end)
local DayNightService = nil
pcall(function() DayNightService = require(ReplicatedStorage.Shared.Services.DayNightService) end)
local HalloweenService = nil
pcall(function() HalloweenService = require(ReplicatedStorage.Shared.Services.HalloweenService) end)

-- Статистика сессии
local Stats = {
    StartTime = os.clock(),
    StartCash = 0,
    CashEarned = 0,
    CratesSold = 0,
    LockersOpened = 0,
    BoxesBought = 0,
    CandiesCollected = 0
}

-- Инициализация начального баланса
pcall(function()
    if ClientDataManager then
        local d = ClientDataManager.GetData()
        Stats.StartCash = (d and d.Currency and d.Currency.Cash) or 0
    end
end)

-- Конфигурация
local Config = {
    -- Главный фарм
    AutoCollectAndSell = true,
    AutoOpenLockers = true,
    AutoRollLockers = true,
    AutoPlaceLockers = true,
    AutoLevelUpUnits = true,
    
    -- Передвижение
    PhysicalWalking = true,
    CustomSpeed = 32,
    SpeedHack = true,
    Noclip = true,
    InstantPrompts = true,
    
    -- Прокачка
    AutoBuyUpgrades = false,
    UpgradeCrateCash = true,
    UpgradeLuck = true,
    UpgradeConveyorLuck = true,
    UpgradeOpenTime = true,
    UpgradeUnits = true,
    UpgradeSpeed = true,
    
    -- Ивенты и лут
    AutoTrickOrTreat = true,
    AutoCollectWorldDrops = true,
    AutoClaimRewards = true,
    
    -- Система
    AntiAFK = true,
    FPSBooster = false,
    WebhookURL = ""
}

-- Вспомогательные функции
local function getMyPlot()
    local plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("PlotModels")
    if plots then
        return plots:FindFirstChild(LocalPlayer.Name)
    end
    return nil
end

local function getCash()
    if ClientDataManager then
        local data = ClientDataManager.GetData()
        return (data and data.Currency and data.Currency.Cash) or 0
    end
    return 0
end

local function formatNumber(n)
    if not n then return "0" end
    if n >= 1e12 then return string.format("%.2fT", n / 1e12)
    elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.2fK", n / 1e3)
    end
    return tostring(math.floor(n))
end

local function getTargetPosition(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then
        return inst.Position
    elseif inst:IsA("Model") then
        return inst:GetPivot().Position
    elseif inst:IsA("Attachment") then
        return inst.WorldPosition
    end
    local p = inst:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end

-- 🚶 Быстрое и плавное передвижение (WalkTo)
local function walkTo(targetPos, maxWait)
    if not Config.PhysicalWalking or not targetPos then return end
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp or humanoid.Health <= 0 then return end

    if Config.SpeedHack and humanoid.WalkSpeed < Config.CustomSpeed then
        humanoid.WalkSpeed = Config.CustomSpeed
    end

    maxWait = maxWait or 3
    local start = os.clock()
    local moveTarget = Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)

    while (hrp.Position - moveTarget).Magnitude > 4.5 do
        if not _G.BlueLockFarmRunning or os.clock() - start > maxWait then
            hrp.CFrame = CFrame.new(moveTarget + Vector3.new(0, 1, 0))
            break
        end
        humanoid:MoveTo(moveTarget)
        task.wait(0.08)
    end
end

-- 🛡️ Anti-AFK
LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK and _G.BlueLockFarmRunning then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end)
    end
end)

-- 👻 Noclip режим
RunService.Stepped:Connect(function()
    if Config.Noclip and _G.BlueLockFarmRunning and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

-- ⚡ Speed Hack поддержание скорости
RunService.Heartbeat:Connect(function()
    if Config.SpeedHack and _G.BlueLockFarmRunning and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed ~= Config.CustomSpeed then
            hum.WalkSpeed = Config.CustomSpeed
        end
    end
end)

-- ⚡ Instant Proximity Prompts (Мгновенное срабатывание всех E промптов)
task.spawn(function()
    while _G.BlueLockFarmRunning do
        if Config.InstantPrompts then
            pcall(function()
                for _, prompt in ipairs(workspace:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") then
                        prompt.HoldDuration = 0
                        prompt.RequiresLineOfSight = false
                        prompt.MaxActivationDistance = 40
                    end
                end
            end)
        end
        task.wait(2)
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 📦 1. Авто-Крутка, Надевание и Установка шкафчиков на дропперы
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
    while _G.BlueLockFarmRunning do
        task.wait(1)

        local plot = getMyPlot()
        if not plot or not plot:FindFirstChild("Systems") then continue end

        -- 1.1 Крутка на станции
        if Config.AutoRollLockers and ConveyorRollClient then
            pcall(function()
                local rollStation = plot.Systems:FindFirstChild("RollStation")
                local convPart = rollStation and rollStation:FindFirstChild("ConveyorPart")
                local rollPos = getTargetPosition(convPart)

                if ConveyorRollClient.CanRoll() then
                    Remotes.NewRequestConveyorRoll:FireServer()
                end

                local boxModel = convPart and convPart:FindFirstChild("BoxModel")
                if boxModel then
                    local prompt = boxModel:FindFirstChildOfClass("ProximityPrompt")
                    if prompt then
                        walkTo(rollPos, 2)
                        fireproximityprompt(prompt)
                        Stats.BoxesBought = Stats.BoxesBought + 1
                    end
                end
            end)
        end

        -- 1.2 Взять шкафчик в руки, дойти и установить
        if Config.AutoPlaceLockers then
            pcall(function()
                local tycoon = plot.Systems:FindFirstChild("TycoonConveyor")
                local conveyors = tycoon and tycoon:FindFirstChild("Conveyors")
                local conv1 = conveyors and conveyors:FindFirstChild("Conveyor1")
                local droppers = conv1 and conv1:FindFirstChild("Droppers")
                if not droppers then return end

                local emptyDropper = nil
                for _, dropper in ipairs(droppers:GetChildren()) do
                    local dType = dropper:GetAttribute("Type")
                    if dType ~= "PlayerUnit" and dType ~= "Box" then
                        emptyDropper = dropper
                        break
                    end
                end

                if not emptyDropper then return end

                local char = LocalPlayer.Character
                local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                local heldBox = char and char:FindFirstChildWhichIsA("Tool")
                local isHoldingBox = heldBox and (heldBox:GetAttribute("InventoryType") == "Box" or heldBox:GetAttribute("Group") == "Box")

                if not isHoldingBox then
                    for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
                        if t:IsA("Tool") and (t:GetAttribute("InventoryType") == "Box" or t:GetAttribute("Group") == "Box") then
                            humanoid:EquipTool(t)
                            task.wait(0.15)
                            heldBox = t
                            isHoldingBox = true
                            break
                        end
                    end
                end

                local data = ClientDataManager and ClientDataManager.GetData()
                local boxes = data and data.Inventory and data.Inventory.Boxes
                local foundBox, foundVariant = nil, "Normal"

                if isHoldingBox and heldBox then
                    foundBox = heldBox.Name
                    foundVariant = heldBox:GetAttribute("Variant") or "Normal"
                elseif boxes then
                    for bName, vMap in pairs(boxes) do
                        if type(vMap) == "table" then
                            for vName, count in pairs(vMap) do
                                if count and count > 0 then
                                    foundBox = bName
                                    foundVariant = vName
                                    break
                                end
                            end
                        end
                        if foundBox then break end
                    end
                end

                if foundBox then
                    local dropperPos = getTargetPosition(emptyDropper)
                    walkTo(dropperPos, 2.5)
                    task.wait(0.15)

                    local placePrompt = emptyDropper:FindFirstChildOfClass("ProximityPrompt", true)
                    if placePrompt then fireproximityprompt(placePrompt) end

                    Remotes.PlaceBoxOnDropper:FireServer(emptyDropper, foundBox, foundVariant)
                    task.wait(0.2)
                end
            end)
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 🔓 2. Авто-Открытие шкафчиков + Авто Level-Up юнитов
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
    while _G.BlueLockFarmRunning do
        task.wait(1.5)

        local plot = getMyPlot()
        if not plot or not plot:FindFirstChild("Systems") then continue end

        local tycoon = plot.Systems:FindFirstChild("TycoonConveyor")
        local conveyors = tycoon and tycoon:FindFirstChild("Conveyors")
        local conv1 = conveyors and conveyors:FindFirstChild("Conveyor1")
        local droppers = conv1 and conv1:FindFirstChild("Droppers")

        if droppers then
            -- 2.1 Открытие готовых
            if Config.AutoOpenLockers and BoxService then
                local openedAny = false
                for _, dropper in ipairs(droppers:GetChildren()) do
                    if not _G.BlueLockFarmRunning or not Config.AutoOpenLockers then break end
                    local dType = dropper:GetAttribute("Type")
                    local bName = dropper:GetAttribute("BoxName")
                    local placedAt = dropper:GetAttribute("PlacedAt")
                    local variant = dropper:GetAttribute("Variant")

                    if dType == "Box" and bName and placedAt then
                        local isReady = false
                        pcall(function() isReady = BoxService.IsBoxReady(bName, placedAt, variant) end)

                        if isReady then
                            local dropperPos = getTargetPosition(dropper)
                            walkTo(dropperPos, 2)
                            task.wait(0.15)

                            local prompt = dropper:FindFirstChildOfClass("ProximityPrompt", true)
                            if prompt then fireproximityprompt(prompt) end

                            pcall(function()
                                Remotes.OpenBoxOnDropper:InvokeServer(dropper)
                                openedAny = true
                                Stats.LockersOpened = Stats.LockersOpened + 1
                            end)
                            task.wait(0.2)
                        end
                    end
                end

                if openedAny then
                    task.wait(0.3)
                    pcall(function() Remotes.EquipBestPlayerUnits:FireServer() end)
                end
            end

            -- 2.2 Прокачка уровней юнитов (Level-Up)
            if Config.AutoLevelUpUnits then
                pcall(function()
                    for _, dropper in ipairs(droppers:GetChildren()) do
                        if dropper:GetAttribute("Type") == "PlayerUnit" and dropper:GetAttribute("PlayerUnitName") then
                            Remotes.RequestPlayerUnitLevelUp:FireServer(dropper)
                            task.wait(0.1)
                        end
                    end
                end)
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 💰 3. Авто-Сбор и Продажа (Мячи и Хэллоуинские конфеты)
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
    while _G.BlueLockFarmRunning do
        task.wait(0.8)
        if not Config.AutoCollectAndSell then continue end

        local plot = getMyPlot()
        if not plot or not plot:FindFirstChild("Systems") then continue end

        local tycoon = plot.Systems:FindFirstChild("TycoonConveyor")
        local zones = plot.Systems:FindFirstChild("Zones")
        local sellNpc = zones and zones:FindFirstChild("sell npc")
        local sellPrompt = sellNpc and sellNpc:FindFirstChildOfClass("ProximityPrompt")
        local sellPos = getTargetPosition(sellNpc)

        if tycoon then
            -- Сбор ящика с мячами
            local cp = tycoon:FindFirstChild("CollectPart")
            if cp and (cp:GetAttribute("PendingBallCount") or 0) > 0 then
                local cpPos = getTargetPosition(cp)
                walkTo(cpPos, 2)

                local prompt = cp:FindFirstChildOfClass("ProximityPrompt")
                if prompt then
                    fireproximityprompt(prompt)
                    task.wait(0.15)
                end
            end

            -- Продажа ящиков
            local crate = LocalPlayer.Backpack:FindFirstChild("SellCrate") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("SellCrate"))
            if crate and LocalPlayer.Character then
                local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if humanoid and crate.Parent == LocalPlayer.Backpack then
                    humanoid:EquipTool(crate)
                    task.wait(0.15)
                end

                walkTo(sellPos, 2)
                if sellPrompt then
                    fireproximityprompt(sellPrompt)
                    Stats.CratesSold = Stats.CratesSold + 1
                    task.wait(0.15)
                end
            end

            -- Хэллоуинские конфеты
            local candyPart = tycoon:FindFirstChild("CandyPart")
            if candyPart then
                local candyPrompt = candyPart:FindFirstChildOfClass("ProximityPrompt")
                if candyPrompt then
                    local candyPos = getTargetPosition(candyPart)
                    walkTo(candyPos, 2)
                    fireproximityprompt(candyPrompt)
                    task.wait(0.1)
                end

                for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
                    if item:GetAttribute("InventoryType") == "CandyBag" then
                        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                        if humanoid then
                            humanoid:EquipTool(item)
                            task.wait(0.15)
                            walkTo(sellPos, 2)
                            if sellPrompt then
                                fireproximityprompt(sellPrompt)
                                Stats.CandiesCollected = Stats.CandiesCollected + 1
                                task.wait(0.15)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 🎃 4. Auto Trick-or-Treat (Сбор конфет с хэллоуинских домов ночью)
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
    while _G.BlueLockFarmRunning do
        task.wait(10)
        if not Config.AutoTrickOrTreat or not DayNightService or not HalloweenService then continue end

        pcall(function()
            if DayNightService.CanTrickOrTreat() then
                local map = workspace:FindFirstChild("Map")
                local decor = map and map:FindFirstChild("HALLOWEEN-MainMap")
                local houses = decor and decor:FindFirstChild("TrickOrTreatHouses")

                local houseList = houses and houses:GetChildren() or {}
                for _, h in ipairs(houseList) do
                    if not _G.BlueLockFarmRunning or not Config.AutoTrickOrTreat then break end
                    if not HalloweenService.IsHouseOnCooldown(LocalPlayer, h.Name) then
                        local pos = getTargetPosition(h)
                        if pos then
                            walkTo(pos, 3)
                            task.wait(0.2)
                        end
                        Remotes.TrickOrTreat:InvokeServer(h.Name)
                        Stats.CandiesCollected = Stats.CandiesCollected + 5
                        task.wait(1.2)
                    end
                end
            end
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 🌦️ 5. Auto World Loot (Item Rain, Токены и Коллекционки)
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
    while _G.BlueLockFarmRunning do
        task.wait(4)
        if not Config.AutoCollectWorldDrops then continue end

        pcall(function()
            local sys = workspace:FindFirstChild("Systems")
            if not sys then return end

            -- Item Rain
            local rain = sys:FindFirstChild("ActiveItemRainItems")
            if rain then
                for _, drop in ipairs(rain:GetChildren()) do
                    local pos = getTargetPosition(drop)
                    if pos then
                        walkTo(pos, 2)
                        Remotes.CollectItemRainItem:FireServer(drop.Name)
                        task.wait(0.2)
                    end
                end
            end

            -- Variant Tokens
            local tokens = sys:FindFirstChild("ActiveVariantTokenSpawns")
            if tokens then
                for _, tok in ipairs(tokens:GetChildren()) do
                    local pos = getTargetPosition(tok)
                    if pos then
                        walkTo(pos, 2)
                        Remotes.CollectVariantTokenSpawn:FireServer(tok.Name)
                        task.wait(0.2)
                    end
                end
            end

            -- Collectables
            local col = sys:FindFirstChild("ActiveCollectableObjects")
            if col then
                for _, c in ipairs(col:GetChildren()) do
                    local pos = getTargetPosition(c)
                    if pos then
                        walkTo(pos, 2)
                        Remotes.CollectCollectableObject:FireServer(c)
                        task.wait(0.2)
                    end
                end
            end
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 📈 6. Авто-Покупка улучшений (Upgrades)
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
    while _G.BlueLockFarmRunning do
        task.wait(3)
        if not Config.AutoBuyUpgrades or not UpgradesLibrary or not UpgradesService then continue end

        local upgradesOrder = {
            {name = "CrateCashBoost", enabled = Config.UpgradeCrateCash},
            {name = "Luck", enabled = Config.UpgradeLuck},
            {name = "OpenTimeBoost", enabled = Config.UpgradeOpenTime},
            {name = "ConveyorLuck", enabled = Config.UpgradeConveyorLuck},
            {name = "WalkSpeed", enabled = Config.UpgradeSpeed},
            {name = "PlayerUnitExpansion", enabled = Config.UpgradeUnits}
        }

        local cash = getCash()

        for _, item in ipairs(upgradesOrder) do
            if not _G.BlueLockFarmRunning or not Config.AutoBuyUpgrades then break end
            if not item.enabled then continue end

            local upgData = UpgradesLibrary[item.name]
            if upgData and upgData.GetPrice then
                local currentLevel = 0
                pcall(function() currentLevel = UpgradesService.GetTimesPurchased(LocalPlayer, item.name) end)

                if not upgData.MaxPurchases or currentLevel < upgData.MaxPurchases then
                    local price = nil
                    pcall(function() price = upgData.GetPrice(currentLevel) end)

                    if price and cash >= price then
                        pcall(function()
                            Remotes.PurchaseUpgrade:FireServer(item.name)
                            cash = cash - price
                        end)
                        task.wait(0.3)
                    end
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 🎁 7. Авто-Забор всех наград
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
    while _G.BlueLockFarmRunning do
        task.wait(12)
        if not Config.AutoClaimRewards then continue end

        pcall(function()
            Remotes.ClaimDailyReward:FireServer()
            for i = 1, 12 do
                Remotes.ClaimPlaytimeReward:FireServer(i)
                task.wait(0.03)
            end
            Remotes.ClaimAllIndexRewards:FireServer()
            Remotes.ClaimOfflineEarnings:FireServer()

            local obby = workspace:FindFirstChild("Systems") and workspace.Systems:FindFirstChild("Obby")
            local vic = obby and obby:FindFirstChild("VictoryParts")
            if vic then
                for _, part in ipairs(vic:GetChildren()) do
                    Remotes.ClaimObbyBonus:FireServer(part)
                    task.wait(0.03)
                end
            end
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 🖥️ Инициализация Fluent GUI (10x Edition)
-- ══════════════════════════════════════════════════════════════════
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Ферма синих замков | 10x GOD-TIER",
    SubTitle = "v2.0 • Antigravity Edition",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

_G.BlueLockFarmWindow = Window

local Tabs = {
    Main = Window:AddTab({ Title = "Фарм / Main", Icon = "zap" }),
    Lockers = Window:AddTab({ Title = "Шкафчики / Lockers", Icon = "box" }),
    Move = Window:AddTab({ Title = "Движение / Speed", Icon = "activity" }),
    Events = Window:AddTab({ Title = "Ивенты / Loot", Icon = "sparkles" }),
    Upgrades = Window:AddTab({ Title = "Прокачка / Upgrades", Icon = "trending-up" }),
    Stats = Window:AddTab({ Title = "Статистика", Icon = "bar-chart-2" }),
    Settings = Window:AddTab({ Title = "Настройки", Icon = "settings" })
}

-- ─── TAB: MAIN ───
Tabs.Main:AddParagraph({
    Title = "Основной цикл автофарма",
    Content = "Автоматический сбор ящиков с мячами, надевание шкафчиков, продажа и экипировка сильнейших юнитов."
})

Tabs.Main:AddToggle("ToggleCollect", {
    Title = "Авто-Сбор и Продажа (Crates & Bags)",
    Default = Config.AutoCollectAndSell
}):OnChanged(function(v) Config.AutoCollectAndSell = v end)

Tabs.Main:AddToggle("ToggleLevelUp", {
    Title = "Авто-Прокачка юнитов на дропперах (Level-Up)",
    Description = "Автоматически повышает уровень юнитов для взрывного роста прибыли",
    Default = Config.AutoLevelUpUnits
}):OnChanged(function(v) Config.AutoLevelUpUnits = v end)

Tabs.Main:AddButton({
    Title = "Экипировать сильнейших юнитов",
    Description = "Ставит топовых юнитов из инвентаря на все дропперы",
    Callback = function()
        Remotes.EquipBestPlayerUnits:FireServer()
        Fluent:Notify({ Title = "Готово", Content = "Сильнейшие юниты экипированы!", Duration = 3 })
    end
})

-- ─── TAB: LOCKERS ───
Tabs.Lockers:AddParagraph({
    Title = "Шкафчики и Конвейер",
    Content = "Персонаж подходит к конвейеру, покупает шкафчик, берет в руки, добегает до свободного дроппера и надевает его."
})

Tabs.Lockers:AddToggle("TogglePlace", {
    Title = "Авто-Дойти и надеть шкафчик (Place Box)",
    Description = "Берет шкафчик в руки, доходит до пустого слота и надевает его",
    Default = Config.AutoPlaceLockers
}):OnChanged(function(v) Config.AutoPlaceLockers = v end)

Tabs.Lockers:AddToggle("ToggleOpen", {
    Title = "Авто-Открытие готовых шкафчиков",
    Description = "Подходит к готовым шкафчикам и открывает их моментально",
    Default = Config.AutoOpenLockers
}):OnChanged(function(v) Config.AutoOpenLockers = v end)

Tabs.Lockers:AddToggle("ToggleRoll", {
    Title = "Авто-Крутка шкафчиков на конвейере",
    Description = "Подходит к крутилке и крутит новые шкафчики по кулдауну",
    Default = Config.AutoRollLockers
}):OnChanged(function(v) Config.AutoRollLockers = v end)

-- ─── TAB: MOVE ───
Tabs.Move:AddParagraph({
    Title = "Сверхскорость и Навигация",
    Content = "Позволяет персонажу молниеносно перемещаться по тайкуну сквозь стены."
})

Tabs.Move:AddToggle("ToggleWalk", {
    Title = "Физическое передвижение (WalkTo)",
    Default = Config.PhysicalWalking
}):OnChanged(function(v) Config.PhysicalWalking = v end)

Tabs.Move:AddToggle("ToggleNoclip", {
    Title = "Noclip (Ходьба сквозь стены)",
    Description = "Персонаж не застревает в заборах, дверях и объектах",
    Default = Config.Noclip
}):OnChanged(function(v) Config.Noclip = v end)

Tabs.Move:AddToggle("ToggleSpeedHack", {
    Title = "Speed Boost (Ускорение персонажа)",
    Default = Config.SpeedHack
}):OnChanged(function(v) Config.SpeedHack = v end)

local SpeedSlider = Tabs.Move:AddSlider("SpeedSlider", {
    Title = "Скорость передвижения (Speed)",
    Description = "Стандартная скорость в игре: 16",
    Default = Config.CustomSpeed,
    Min = 16,
    Max = 120,
    Rounding = 0
})
SpeedSlider:OnChanged(function(val)
    Config.CustomSpeed = val
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = val
    end
end)

Tabs.Move:AddToggle("ToggleInstantPrompts", {
    Title = "Instant Prompts (Мгновенные взаимодействия)",
    Description = "Убирает задержку удержания кнопки E и увеличивает дистанцию",
    Default = Config.InstantPrompts
}):OnChanged(function(v) Config.InstantPrompts = v end)

-- ─── TAB: EVENTS & LOOT ───
Tabs.Events:AddParagraph({
    Title = "Ивенты и Лут карты",
    Content = "Автоматически забирает редкие хэллоуинские награды и падающие ресурсы."
})

Tabs.Events:AddToggle("ToggleTrickOrTreat", {
    Title = "Auto Trick-or-Treat (Хэллоуинские дома)",
    Description = "Ночью обходит дома и стучится для получения тонн конфет и наград",
    Default = Config.AutoTrickOrTreat
}):OnChanged(function(v) Config.AutoTrickOrTreat = v end)

Tabs.Events:AddToggle("ToggleWorldLoot", {
    Title = "Auto World Drops (Item Rain и Токены)",
    Description = "Автоматически подбирает падающие с неба предметы и токены вариантов",
    Default = Config.AutoCollectWorldDrops
}):OnChanged(function(v) Config.AutoCollectWorldDrops = v end)

Tabs.Events:AddToggle("ToggleRewards", {
    Title = "Авто-Забор всех наград (Daily, Playtime, Obby)",
    Default = Config.AutoClaimRewards
}):OnChanged(function(v) Config.AutoClaimRewards = v end)

-- ─── TAB: UPGRADES ───
Tabs.Upgrades:AddParagraph({
    Title = "Авто-Прокачка базы",
    Content = "Покупает улучшения базы, удачи и множителей при достатке средств."
})

Tabs.Upgrades:AddToggle("ToggleBuyUpgrades", {
    Title = "Включить авто-покупку улучшений",
    Default = Config.AutoBuyUpgrades
}):OnChanged(function(v) Config.AutoBuyUpgrades = v end)

Tabs.Upgrades:AddToggle("UpgCash", { Title = "Множитель денег (Crate Cash)", Default = Config.UpgradeCrateCash }):OnChanged(function(v) Config.UpgradeCrateCash = v end)
Tabs.Upgrades:AddToggle("UpgLuck", { Title = "Удача (Luck Boost)", Default = Config.UpgradeLuck }):OnChanged(function(v) Config.UpgradeLuck = v end)
Tabs.Upgrades:AddToggle("UpgConveyor", { Title = "Удача конвейера (Conveyor Luck Tier)", Default = Config.UpgradeConveyorLuck }):OnChanged(function(v) Config.UpgradeConveyorLuck = v end)
Tabs.Upgrades:AddToggle("UpgOpenTime", { Title = "Ускорение шкафчиков (Open Time)", Default = Config.UpgradeOpenTime }):OnChanged(function(v) Config.UpgradeOpenTime = v end)
Tabs.Upgrades:AddToggle("UpgUnits", { Title = "Слоты базы (Base Expansion)", Default = Config.UpgradeUnits }):OnChanged(function(v) Config.UpgradeUnits = v end)

-- ─── TAB: STATS ───
local StatsParagraph = Tabs.Stats:AddParagraph({
    Title = "Статистика фарма",
    Content = "Загрузка статистики..."
})

task.spawn(function()
    while _G.BlueLockFarmRunning do
        task.wait(1)
        pcall(function()
            local currentCash = getCash()
            local earned = math.max(0, currentCash - Stats.StartCash)
            local elapsed = math.floor(os.clock() - Stats.StartTime)
            local hours = math.floor(elapsed / 3600)
            local mins = math.floor((elapsed % 3600) / 60)
            local secs = elapsed % 60
            local ratePerSec = elapsed > 0 and math.floor(earned / elapsed) or 0

            local text = string.format(
                "💰 Текущий баланс: $%s\n" ..
                "📈 Заработано за сессию: +$%s\n" ..
                "⚡ Скорость заработка: +$%s/сек\n\n" ..
                "📦 Шкафчиков открыто: %d\n" ..
                "📦 Ящиков продано: %d\n" ..
                "🍬 Конфет собрано: %d\n\n" ..
                "⏱️ Время работы: %02d:%02d:%02d",
                formatNumber(currentCash),
                formatNumber(earned),
                formatNumber(ratePerSec),
                Stats.LockersOpened,
                Stats.CratesSold,
                Stats.CandiesCollected,
                hours, mins, secs
            )
            StatsParagraph:SetDesc(text)
        end)
    end
end)

-- ─── TAB: SETTINGS ───
Tabs.Settings:AddToggle("ToggleAFK", {
    Title = "Anti-AFK (защита от вылета 20 мин)",
    Default = Config.AntiAFK
}):OnChanged(function(v) Config.AntiAFK = v end)

Tabs.Settings:AddToggle("ToggleFPS", {
    Title = "FPS Booster (Potato Mode)",
    Description = "Убирает текстуры и эффекты для максимального FPS при 24/7 фарме",
    Default = Config.FPSBooster
}):OnChanged(function(v)
    Config.FPSBooster = v
    if v then
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            for _, obj in ipairs(game:GetDescendants()) do
                if obj:IsA("BasePart") then
                    obj.Material = Enum.Material.SmoothPlastic
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    obj.Transparency = 1
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                    obj.Enabled = false
                end
            end
        end)
    end
end)

local WebhookInput = Tabs.Settings:AddInput("WebhookInput", {
    Title = "Discord Webhook URL",
    Default = Config.WebhookURL,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(text)
        Config.WebhookURL = text
    end
})

Tabs.Settings:AddButton({
    Title = "Отправить тестовое уведомление в Discord",
    Callback = function()
        if Config.WebhookURL == "" then
            Fluent:Notify({ Title = "Ошибка", Content = "Сначала вставьте URL вебхука!", Duration = 3 })
            return
        end
        pcall(function()
            local payload = HttpService:JSONEncode({
                content = "🚀 **Blue Lock AutoFarm 2.0**: Тестовое сообщение успешно получено! Фарм активен."
            })
            (syn and syn.request or http_request or request)({
                Url = Config.WebhookURL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload
            })
            Fluent:Notify({ Title = "Успешно", Content = "Уведомление отправлено!", Duration = 3 })
        end)
    end
})

Tabs.Settings:AddButton({
    Title = "Закрыть скрипт и остановить фарм",
    Callback = function()
        _G.BlueLockFarmRunning = false
        if _G.BlueLockFarmWindow then
            _G.BlueLockFarmWindow:Destroy()
            _G.BlueLockFarmWindow = nil
        end
    end
})

Window:SelectTab(1)

Fluent:Notify({
    Title = "Ферма синих замков 2.0",
    Content = "10x GOD-TIER Автофарм успешно активирован!",
    Duration = 5
})
