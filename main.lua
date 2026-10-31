--[[
    ══════════════════════════════════════════════════════════════════
    ⚽ [🎃] Ферма синих замков (Blue Lock Tycoon) — Ultimate AutoFarm ⚽
    ══════════════════════════════════════════════════════════════════
    Разработано для максимальной эффективности, стабильности и скорости заработка.
    Интерфейс: Fluent Library (с поддержкой тем и сворачивания на RightControl)
]]

-- Проверка окружения
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

-- ══════════════════════════════════════════════════════════════════
-- 🛡️ Anti-AFK (Защита от 20-минутного кика Roblox)
-- ══════════════════════════════════════════════════════════════════
LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK and _G.BlueLockFarmRunning then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 💰 1. Авто-Сбор и Продажа (Мячи и Хэллоуинские конфеты)
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

        if tycoon then
            -- Сбор ящика с мячами
            local cp = tycoon:FindFirstChild("CollectPart")
            if cp and (cp:GetAttribute("PendingBallCount") or 0) > 0 then
                local prompt = cp:FindFirstChildOfClass("ProximityPrompt")
                if prompt then
                    fireproximityprompt(prompt)
                    task.wait(0.15)
                end
            end

            -- Продажа накопившихся ящиков
            local crate = LocalPlayer.Backpack:FindFirstChild("SellCrate") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("SellCrate"))
            if crate and LocalPlayer.Character then
                local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if humanoid and crate.Parent == LocalPlayer.Backpack then
                    humanoid:EquipTool(crate)
                    task.wait(0.15)
                end
                if sellPrompt then
                    fireproximityprompt(sellPrompt)
                    task.wait(0.15)
                end
            end

            -- Сбор хэллоуинских конфет
            local candyPart = tycoon:FindFirstChild("CandyPart")
            if candyPart then
                local candyPrompt = candyPart:FindFirstChildOfClass("ProximityPrompt")
                if candyPrompt then
                    fireproximityprompt(candyPrompt)
                    task.wait(0.1)
                end

                for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
                    if item:GetAttribute("InventoryType") == "CandyBag" then
                        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                        if humanoid then
                            humanoid:EquipTool(item)
                            task.wait(0.15)
                            if sellPrompt then
                                fireproximityprompt(sellPrompt)
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
-- 📦 2. Авто-Открытие готовых шкафчиков и Авто-Экипировка юнитов
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
-- 🎲 3. Авто-Крутка шкафчиков и Установка на свободные дропперы
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
    while _G.BlueLockFarmRunning do
        task.wait(1.5)

        local plot = getMyPlot()
        if not plot or not plot:FindFirstChild("Systems") then continue end

        -- Авто-Крутка
        if Config.AutoRollLockers and ConveyorRollClient then
            pcall(function()
                if ConveyorRollClient.CanRoll() then
                    Remotes.NewRequestConveyorRoll:FireServer()
                end

                local rollStation = plot.Systems:FindFirstChild("RollStation")
                local convPart = rollStation and rollStation:FindFirstChild("ConveyorPart")
                local boxModel = convPart and convPart:FindFirstChild("BoxModel")
                if boxModel then
                    local prompt = boxModel:FindFirstChildOfClass("ProximityPrompt")
                    if prompt then
                        fireproximityprompt(prompt)
                    end
                end
            end)
        end

        -- Авто-Установка из инвентаря
        if Config.AutoPlaceLockers and ClientDataManager then
            pcall(function()
                local data = ClientDataManager.GetData()
                local boxes = data and data.Inventory and data.Inventory.Boxes

                local foundBox, foundVariant = nil, nil
                if boxes then
                    for boxName, variantMap in pairs(boxes) do
                        if type(variantMap) == "table" then
                            for variant, count in pairs(variantMap) do
                                if count and count > 0 then
                                    foundBox = boxName
                                    foundVariant = variant
                                    break
                                end
                            end
                        end
                        if foundBox then break end
                    end
                end

                if foundBox then
                    local tycoon = plot.Systems:FindFirstChild("TycoonConveyor")
                    local conveyors = tycoon and tycoon:FindFirstChild("Conveyors")
                    local conv1 = conveyors and conveyors:FindFirstChild("Conveyor1")
                    local droppers = conv1 and conv1:FindFirstChild("Droppers")

                    if droppers then
                        for _, dropper in ipairs(droppers:GetChildren()) do
                            local dType = dropper:GetAttribute("Type")
                            if dType ~= "PlayerUnit" and dType ~= "Box" then
                                Remotes.PlaceBoxOnDropper:FireServer(dropper, foundBox, foundVariant)
                                task.wait(0.4)
                                break
                            end
                        end
                    end
                end
            end)
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
    SubTitle = "v1.0 • Antigravity",
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
    Content = "Забирает ящики с мячами и мешки с конфетами прямо с ленты и моментально продаёт у НПС-скупщика."
})

local ToggleCollect = Tabs.Main:AddToggle("ToggleCollect", {
    Title = "Авто-Сбор и Продажа (Crates & Bags)",
    Default = Config.AutoCollectAndSell
})
ToggleCollect:OnChanged(function(val)
    Config.AutoCollectAndSell = val
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
    Content = "Автоматическое открытие готовых шкафчиков, крутка новых на конвейере и установка на свободные слоты."
})

local ToggleOpen = Tabs.Lockers:AddToggle("ToggleOpen", {
    Title = "Авто-Открытие готовых шкафчиков",
    Default = Config.AutoOpenLockers
})
ToggleOpen:OnChanged(function(val)
    Config.AutoOpenLockers = val
end)

local ToggleRoll = Tabs.Lockers:AddToggle("ToggleRoll", {
    Title = "Авто-Крутка шкафчиков на конвейере",
    Default = Config.AutoRollLockers
})
ToggleRoll:OnChanged(function(val)
    Config.AutoRollLockers = val
end)

local TogglePlace = Tabs.Lockers:AddToggle("TogglePlace", {
    Title = "Авто-Установка шкафчиков на дропперы",
    Default = Config.AutoPlaceLockers
})
TogglePlace:OnChanged(function(val)
    Config.AutoPlaceLockers = val
end)

-- ─── Вкладка: Прокачка ───
Tabs.Upgrades:AddParagraph({
    Title = "Авто-Прокачка тайкуна",
    Content = "Автоматически прокачивает множитель денег, удачу и слоты базы, когда хватает наличных."
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
    Content = "Скрипт успешно запущен и работает!",
    Duration = 5
})
