--[[
    ══════════════════════════════════════════════════════════════════
    ⚽ [🎃] Ферма синих замков (Blue Lock Tycoon) — Ultimate AutoFarm ⚽
    ══════════════════════════════════════════════════════════════════
    Обновление: Персонаж физически подходит к шкафчикам, берет их в руки,
    доходит до свободных дропперов и устанавливает их на место.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

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

-- Ремоуты и сервисы игры
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
    warn("[AutoFarm] Папка Remotes не найдена!")
    return
end

local BoxService = nil
pcall(function()
    BoxService = require(ReplicatedStorage.Shared.Services.BoxService)
end)

local UpgradesLibrary = nil
pcall(function()
    UpgradesLibrary = require(ReplicatedStorage.Shared.Core.Storage.Game.UpgradesLibrary)
end)

local UpgradesService = nil
pcall(function()
    UpgradesService = require(ReplicatedStorage.Shared.Services.UpgradesService)
end)

local ClientDataManager = nil
pcall(function()
    ClientDataManager = require(ReplicatedStorage.Client.Data.ClientDataManager)
end)

local ConveyorRollClient = nil
pcall(function()
    ConveyorRollClient = require(ReplicatedStorage.Client.Core.ConveyorRollClient)
end)

-- Конфигурация по умолчанию
local Config = {
    AutoCollectAndSell = true,
    AutoOpenLockers = true,
    AutoRollLockers = true,
    AutoPlaceLockers = true,
    PhysicalWalking = true,      -- Персонаж ножками подходит к объектам
    AutoBuyUpgrades = false,
    AutoClaimRewards = true,
    AntiAFK = true,
    UpgradeConveyorLuck = true,
    UpgradePlayerUnits = true,
    UpgradeCrateCash = true,
    UpgradeLuck = true,
    UpgradeSpeed = true,
    UpgradeOpenTime = true
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

-- 🚶 Функция передвижения персонажа к точке
local function walkTo(targetPos, maxWait)
    if not Config.PhysicalWalking or not targetPos then return end
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp or humanoid.Health <= 0 then return end

    maxWait = maxWait or 4
    local start = os.clock()
    local moveTarget = Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)

    while (hrp.Position - moveTarget).Magnitude > 4.5 do
        if not _G.BlueLockFarmRunning or os.clock() - start > maxWait then
            -- Если застрял или вышло время, аккуратно смещаем ближе
            hrp.CFrame = CFrame.new(moveTarget + Vector3.new(0, 1.5, 0))
            break
        end
        humanoid:MoveTo(moveTarget)
        task.wait(0.1)
    end
end

-- 🛡️ Anti-AFK (Защита от 20-минутного кика Roblox)
LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK and _G.BlueLockFarmRunning then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 📦 1. Авто-Крутка, Надевание и Установка шкафчиков на дропперы
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
    while _G.BlueLockFarmRunning do
        task.wait(1.2)

        local plot = getMyPlot()
        if not plot or not plot:FindFirstChild("Systems") then continue end

        -- 1.1 Авто-Крутка на конвейере
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
                        -- Подходим к станции крутки и берем шкафчик
                        walkTo(rollPos, 3)
                        fireproximityprompt(prompt)
                    end
                end
            end)
        end

        -- 1.2 Дойти, взять шкафчик в руки и надеть/установить на свободный дроппер
        if Config.AutoPlaceLockers then
            pcall(function()
                local tycoon = plot.Systems:FindFirstChild("TycoonConveyor")
                local conveyors = tycoon and tycoon:FindFirstChild("Conveyors")
                local conv1 = conveyors and conveyors:FindFirstChild("Conveyor1")
                local droppers = conv1 and conv1:FindFirstChild("Droppers")
                if not droppers then return end

                -- Ищем свободный дроппер
                local emptyDropper = nil
                for _, dropper in ipairs(droppers:GetChildren()) do
                    local dType = dropper:GetAttribute("Type")
                    if dType ~= "PlayerUnit" and dType ~= "Box" then
                        emptyDropper = dropper
                        break
                    end
                end

                if not emptyDropper then return end

                -- Проверяем, есть ли шкафчик в инвентаре или в руках
                local char = LocalPlayer.Character
                local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                local heldBox = char and char:FindFirstChildWhichIsA("Tool")
                local isHoldingBox = heldBox and (heldBox:GetAttribute("InventoryType") == "Box" or heldBox:GetAttribute("Group") == "Box")

                local boxTool = nil
                if not isHoldingBox then
                    for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
                        if t:IsA("Tool") and (t:GetAttribute("InventoryType") == "Box" or t:GetAttribute("Group") == "Box") then
                            boxTool = t
                            break
                        end
                    end

                    -- Берем шкафчик в руки (надеваем)
                    if boxTool and humanoid then
                        humanoid:EquipTool(boxTool)
                        task.wait(0.2)
                        heldBox = boxTool
                        isHoldingBox = true
                    end
                end

                -- Если шкафчик в руках или есть данные о коробках в инвентаре
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
                    -- Доходим персонажем прямо до пустого дроппера
                    local dropperPos = getTargetPosition(emptyDropper)
                    walkTo(dropperPos, 3)
                    task.wait(0.2)

                    -- Взаимодействуем с дроппером (активируем промпт "Place" и ремоут)
                    local placePrompt = emptyDropper:FindFirstChildOfClass("ProximityPrompt", true)
                    if placePrompt then
                        fireproximityprompt(placePrompt)
                    end

                    Remotes.PlaceBoxOnDropper:FireServer(emptyDropper, foundBox, foundVariant)
                    task.wait(0.3)
                end
            end)
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 🔓 2. Авто-Открытие готовых шкафчиков (Подходит и открывает)
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
    while _G.BlueLockFarmRunning do
        task.wait(2)
        if not Config.AutoOpenLockers then continue end

        local plot = getMyPlot()
        if not plot or not plot:FindFirstChild("Systems") then continue end

        local tycoon = plot.Systems:FindFirstChild("TycoonConveyor")
        local conveyors = tycoon and tycoon:FindFirstChild("Conveyors")
        local conv1 = conveyors and conveyors:FindFirstChild("Conveyor1")
        local droppers = conv1 and conv1:FindFirstChild("Droppers")

        if droppers and BoxService then
            local openedAny = false
            for _, dropper in ipairs(droppers:GetChildren()) do
                if not _G.BlueLockFarmRunning or not Config.AutoOpenLockers then break end
                local dType = dropper:GetAttribute("Type")
                local bName = dropper:GetAttribute("BoxName")
                local placedAt = dropper:GetAttribute("PlacedAt")
                local variant = dropper:GetAttribute("Variant")

                if dType == "Box" and bName and placedAt then
                    local isReady = false
                    pcall(function()
                        isReady = BoxService.IsBoxReady(bName, placedAt, variant)
                    end)

                    if isReady then
                        -- Доходим до готового шкафчика
                        local dropperPos = getTargetPosition(dropper)
                        walkTo(dropperPos, 3)
                        task.wait(0.2)

                        local prompt = dropper:FindFirstChildOfClass("ProximityPrompt", true)
                        if prompt then
                            fireproximityprompt(prompt)
                        end

                        pcall(function()
                            Remotes.OpenBoxOnDropper:InvokeServer(dropper)
                            openedAny = true
                        end)
                        task.wait(0.3)
                    end
                end
            end

            if openedAny then
                task.wait(0.5)
                pcall(function()
                    Remotes.EquipBestPlayerUnits:FireServer()
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
        task.wait(1)
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
                walkTo(cpPos, 3)

                local prompt = cp:FindFirstChildOfClass("ProximityPrompt")
                if prompt then
                    fireproximityprompt(prompt)
                    task.wait(0.2)
                end
            end

            -- Продажа накопившихся ящиков у скупщика
            local crate = LocalPlayer.Backpack:FindFirstChild("SellCrate") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("SellCrate"))
            if crate and LocalPlayer.Character then
                local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if humanoid and crate.Parent == LocalPlayer.Backpack then
                    humanoid:EquipTool(crate)
                    task.wait(0.15)
                end

                walkTo(sellPos, 3)
                if sellPrompt then
                    fireproximityprompt(sellPrompt)
                    task.wait(0.2)
                end
            end

            -- Сбор хэллоуинских конфет
            local candyPart = tycoon:FindFirstChild("CandyPart")
            if candyPart then
                local candyPrompt = candyPart:FindFirstChildOfClass("ProximityPrompt")
                if candyPrompt then
                    local candyPos = getTargetPosition(candyPart)
                    walkTo(candyPos, 3)
                    fireproximityprompt(candyPrompt)
                    task.wait(0.15)
                end

                for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
                    if item:GetAttribute("InventoryType") == "CandyBag" then
                        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                        if humanoid then
                            humanoid:EquipTool(item)
                            task.wait(0.15)
                            walkTo(sellPos, 3)
                            if sellPrompt then
                                fireproximityprompt(sellPrompt)
                                task.wait(0.2)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 📈 4. Авто-Покупка улучшений (Upgrades)
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
            {name = "PlayerUnitExpansion", enabled = Config.UpgradePlayerUnits}
        }

        local cash = getCash()

        for _, item in ipairs(upgradesOrder) do
            if not _G.BlueLockFarmRunning or not Config.AutoBuyUpgrades then break end
            if not item.enabled then continue end

            local upgData = UpgradesLibrary[item.name]
            if upgData and upgData.GetPrice then
                local currentLevel = 0
                pcall(function()
                    currentLevel = UpgradesService.GetTimesPurchased(LocalPlayer, item.name)
                end)

                if not upgData.MaxPurchases or currentLevel < upgData.MaxPurchases then
                    local price = nil
                    pcall(function()
                        price = upgData.GetPrice(currentLevel)
                    end)

                    if price and cash >= price then
                        pcall(function()
                            Remotes.PurchaseUpgrade:FireServer(item.name)
                            cash = cash - price
                        end)
                        task.wait(0.4)
                    end
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 🎁 5. Авто-Забор всех наград
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
    while _G.BlueLockFarmRunning do
        task.wait(12)
        if not Config.AutoClaimRewards then continue end

        pcall(function()
            -- Ежедневный вход
            Remotes.ClaimDailyReward:FireServer()

            -- Награды за время игры (1..12)
            for i = 1, 12 do
                Remotes.ClaimPlaytimeReward:FireServer(i)
                task.wait(0.04)
            end

            -- Индекс
            Remotes.ClaimAllIndexRewards:FireServer()

            -- Оффлайн прибыль
            Remotes.ClaimOfflineEarnings:FireServer()

            -- Бонусы за победу в Обби (Easy, Medium, Hard)
            local obby = workspace:FindFirstChild("Systems") and workspace.Systems:FindFirstChild("Obby")
            local vic = obby and obby:FindFirstChild("VictoryParts")
            if vic then
                for _, part in ipairs(vic:GetChildren()) do
                    Remotes.ClaimObbyBonus:FireServer(part)
                    task.wait(0.04)
                end
            end
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 🖥️ Инициализация Fluent GUI
-- ══════════════════════════════════════════════════════════════════
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Ферма синих замков | AutoFarm",
    SubTitle = "v1.1 • Antigravity",
    TabWidth = 160,
    Size = UDim2.fromOffset(560, 440),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

_G.BlueLockFarmWindow = Window

local Tabs = {
    Main = Window:AddTab({ Title = "Фарм / Main", Icon = "sparkles" }),
    Lockers = Window:AddTab({ Title = "Шкафчики / Lockers", Icon = "box" }),
    Upgrades = Window:AddTab({ Title = "Прокачка / Upgrades", Icon = "trending-up" }),
    Rewards = Window:AddTab({ Title = "Награды / Rewards", Icon = "gift" }),
    Settings = Window:AddTab({ Title = "Настройки", Icon = "settings" })
}

-- ─── Вкладка: Главная ───
Tabs.Main:AddParagraph({
    Title = "Авто-сбор и продажа",
    Content = "Персонаж подходит к ленте, забирает ящики/конфеты и относит их к НПС-скупщику."
})

local ToggleCollect = Tabs.Main:AddToggle("ToggleCollect", {
    Title = "Авто-Сбор и Продажа (Crates & Bags)",
    Default = Config.AutoCollectAndSell
})
ToggleCollect:OnChanged(function(val)
    Config.AutoCollectAndSell = val
end)

local ToggleWalk = Tabs.Main:AddToggle("ToggleWalk", {
    Title = "Физическое передвижение (WalkTo)",
    Description = "Персонаж ножками ходит ко всем дропперам, скупщику и ленте",
    Default = Config.PhysicalWalking
})
ToggleWalk:OnChanged(function(val)
    Config.PhysicalWalking = val
end)

Tabs.Main:AddButton({
    Title = "Экипировать лучших юнитов сейчас",
    Description = "Ставит сильнейших юнитов на активные дропперы",
    Callback = function()
        Remotes.EquipBestPlayerUnits:FireServer()
        Fluent:Notify({
            Title = "Успешно",
            Content = "Лучшие юниты экипированы!",
            Duration = 3
        })
    end
})

-- ─── Вкладка: Шкафчики ───
Tabs.Lockers:AddParagraph({
    Title = "Управление шкафчиками",
    Content = "Персонаж подходит к конвейеру, берет шкафчик в руки, доходит до свободного дроппера и надевает/устанавливает его."
})

local TogglePlace = Tabs.Lockers:AddToggle("TogglePlace", {
    Title = "Авто-Дойти и надеть шкафчик (Place Box)",
    Description = "Берет шкафчик в руки, подходит к пустому дропперу и ставит",
    Default = Config.AutoPlaceLockers
})
TogglePlace:OnChanged(function(val)
    Config.AutoPlaceLockers = val
end)

local ToggleOpen = Tabs.Lockers:AddToggle("ToggleOpen", {
    Title = "Авто-Открытие готовых шкафчиков",
    Description = "Подходит к готовым шкафчикам и открывает их",
    Default = Config.AutoOpenLockers
})
ToggleOpen:OnChanged(function(val)
    Config.AutoOpenLockers = val
end)

local ToggleRoll = Tabs.Lockers:AddToggle("ToggleRoll", {
    Title = "Авто-Крутка шкафчиков на конвейере",
    Description = "Подходит к станции крутки и крутит новые шкафчики",
    Default = Config.AutoRollLockers
})
ToggleRoll:OnChanged(function(val)
    Config.AutoRollLockers = val
end)

-- ─── Вкладка: Прокачка ───
Tabs.Upgrades:AddParagraph({
    Title = "Авто-Прокачка тайкуна",
    Content = "При наличии денег автоматически покупает улучшения базы, удачи и множителей."
})

local ToggleBuyUpgrades = Tabs.Upgrades:AddToggle("ToggleBuyUpgrades", {
    Title = "Включить авто-покупку улучшений",
    Default = Config.AutoBuyUpgrades
})
ToggleBuyUpgrades:OnChanged(function(val)
    Config.AutoBuyUpgrades = val
end)

Tabs.Upgrades:AddToggle("UpgCash", {
    Title = "Множитель денег (Crate Cash Boost)",
    Default = Config.UpgradeCrateCash
}):OnChanged(function(v) Config.UpgradeCrateCash = v end)

Tabs.Upgrades:AddToggle("UpgLuck", {
    Title = "Удача (Luck Boost)",
    Default = Config.UpgradeLuck
}):OnChanged(function(v) Config.UpgradeLuck = v end)

Tabs.Upgrades:AddToggle("UpgConveyor", {
    Title = "Удача конвейера (Conveyor Luck Tier)",
    Default = Config.UpgradeConveyorLuck
}):OnChanged(function(v) Config.UpgradeConveyorLuck = v end)

Tabs.Upgrades:AddToggle("UpgOpenTime", {
    Title = "Ускорение открытия (Open Time Boost)",
    Default = Config.UpgradeOpenTime
}):OnChanged(function(v) Config.UpgradeOpenTime = v end)

Tabs.Upgrades:AddToggle("UpgUnits", {
    Title = "Слоты базы (Base Expansion)",
    Default = Config.UpgradePlayerUnits
}):OnChanged(function(v) Config.UpgradePlayerUnits = v end)

Tabs.Upgrades:AddToggle("UpgSpeed", {
    Title = "Скорость бега (Walk Speed)",
    Default = Config.UpgradeSpeed
}):OnChanged(function(v) Config.UpgradeSpeed = v end)

-- ─── Вкладка: Награды ───
Tabs.Rewards:AddParagraph({
    Title = "Автоматические награды",
    Content = "Забирает ежедневные награды, награды за время онлайна, бонусы обби и индекс."
})

local ToggleRewards = Tabs.Rewards:AddToggle("ToggleRewards", {
    Title = "Авто-Забор всех наград",
    Default = Config.AutoClaimRewards
})
ToggleRewards:OnChanged(function(val)
    Config.AutoClaimRewards = val
end)

Tabs.Rewards:AddButton({
    Title = "Забрать все награды прямо сейчас",
    Callback = function()
        Remotes.ClaimDailyReward:FireServer()
        for i = 1, 12 do Remotes.ClaimPlaytimeReward:FireServer(i) end
        Remotes.ClaimAllIndexRewards:FireServer()
        Remotes.ClaimOfflineEarnings:FireServer()
        local vic = workspace:FindFirstChild("Systems") and workspace.Systems:FindFirstChild("Obby") and workspace.Systems.Obby:FindFirstChild("VictoryParts")
        if vic then
            for _, p in ipairs(vic:GetChildren()) do Remotes.ClaimObbyBonus:FireServer(p) end
        end
        Fluent:Notify({
            Title = "Успешно",
            Content = "Все доступные награды запрошены!",
            Duration = 3
        })
    end
})

-- ─── Вкладка: Настройки ───
Tabs.Settings:AddToggle("ToggleAFK", {
    Title = "Anti-AFK (защита от вылета 20 мин)",
    Default = Config.AntiAFK
}):OnChanged(function(v) Config.AntiAFK = v end)

Tabs.Settings:AddButton({
    Title = "Закрыть меню и остановить фарм",
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
    Title = "Ферма синих замков",
    Content = "Скрипт обновлен: включено передвижение персонажа!",
    Duration = 5
})
