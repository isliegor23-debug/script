-- CheatHub v7 — Winter Magic Edition
-- Run a Christmas Tree Lot
-- by dj

local TELEGRAM_URL = "https://t.me/my_christmas_market"

-- =====================================================================
-- 0. EXECUTOR COMPATIBILITY
-- =====================================================================
local Executor = { Name = "Unknown", IsXeno = false, HasFirePrompt = false }
local function detectExecutor()
   local name = "Unknown"
   if type(identifyexecutor) == "function" then local ok, n = pcall(identifyexecutor); if ok and n then name = tostring(n) end end
   Executor.Name = name; Executor.IsXeno = name:lower():find("xeno") ~= nil
end
detectExecutor()
Executor.HasFirePrompt = type(fireproximityprompt) == "function"

local function firePrompt(prompt)
   if not prompt then return false end
   if Executor.IsXeno or not Executor.HasFirePrompt then
      local ok = pcall(function() prompt:InputHoldBegin(); task.wait(0.2); prompt:InputHoldEnd() end)
      if ok then return true end
   end
   if Executor.HasFirePrompt then
      local ok = pcall(function() fireproximityprompt(prompt, 0) end); if ok then return true end
   end
   return pcall(function() prompt:InputHoldBegin(); task.wait(0.2); prompt:InputHoldEnd() end)
end

-- =====================================================================
-- 1. SERVICES & SOUNDS
-- =====================================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Player = Players.LocalPlayer

-- Функция воспроизведения новогодних звуков
local function playSound(soundId)
   local sound = Instance.new("Sound")
   sound.SoundId = "rbxassetid://" .. soundId
   sound.Volume = 0.5
   sound.Parent = SoundService
   sound:Play()
   task.delay(5, function() sound:Destroy() end)
end

-- =====================================================================
-- 2. UI LIBRARY & WINTER THEME
-- =====================================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Зимняя/Рождественская тема
local Theme = {
    TextColor = Color3.fromRGB(255, 255, 255),
    SubTextColor = Color3.fromRGB(200, 220, 230),
    Background = Color3.fromRGB(20, 30, 40),  -- Тёмно-синий лед
    Topbar = Color3.fromRGB(30, 45, 60),
    Accent = Color3.fromRGB(220, 40, 40),     -- Рождественский красный
    Outline = Color3.fromRGB(60, 80, 100),
    Button = Color3.fromRGB(40, 55, 70),
    Element = Color3.fromRGB(30, 45, 60)
}

local Window = Rayfield:CreateWindow({
   Name = "❄️ CheatHub | Winter Magic",
   LoadingTitle = "Снежная буря загружается...",
   LoadingSubtitle = "v7 Premium Edition",
   Theme = Theme,
   ConfigurationSaving = { Enabled = true, FolderName = "CheatHubWinter", FileName = "Config" },
   KeySystem = false
})

-- =====================================================================
-- 3. STATE & UTILS
-- =====================================================================
local State = {
   Subscribed = false,
   AutoFarm = false, AutoOrder = false, AutoServe = false, AutoHire = false, AutoUpgrade = false, AutoDecor = false,
   SelectedTree = "Pine",
   AntiAFK = true, SmoothTeleport = true,
   SpeedEnabled = false, SpeedValue = 50,
   Status = "Ожидание...",
   SessionStart = os.clock(), TotalActions = 0,
   DecorSpent = 0
}

local function getHRP() return Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") end

local function teleportTo(pos)
   local hrp = getHRP()
   if not hrp then return false end
   local targetPos = pos + Vector3.new(0, 3, 0)
   if State.SmoothTeleport then
      local distance = (hrp.Position - targetPos).Magnitude
      local time = math.clamp(distance / 200, 0.1, 1.0) 
      local tween = TweenService:Create(hrp, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = CFrame.new(targetPos)})
      tween:Play()
      task.wait(time)
   else
      hrp.CFrame = CFrame.new(targetPos)
   end
   return true
end

-- =====================================================================
-- 4. FALLBACK ENGINE (20+ Strategies)
-- =====================================================================
local function findRemote(names)
   for _, parent in ipairs({RS, WS}) do
      for _, name in ipairs(names) do
         local obj = parent:FindFirstChild(name, true)
         if obj and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then return obj end
      end
   end
   return nil
end

local function findModel(keywords)
   for _, obj in ipairs(WS:GetDescendants()) do
      if obj:IsA("Model") then
         local n = obj.Name:lower()
         for _, kw in ipairs(keywords) do if n:find(kw, 1, true) then return obj end end
      end
   end
   return nil
end

local function tryInteract(actionName, remoteNames, modelKeywords, uiKeywords)
   State.Status = "Действие: " .. actionName
   
   -- 1-5: Remotes
   local r = findRemote(remoteNames)
   if r then
      pcall(function() if r:IsA("RemoteEvent") then r:FireServer() else r:InvokeServer() end end)
      print("[Fallback] " .. actionName .. " -> Remote: " .. r.Name)
      return true
   end

   -- 6-15: Physical (ProximityPrompt / ClickDetector)
   local targetModel = findModel(modelKeywords)
   if targetModel then
      local hrp = targetModel:FindFirstChild("HumanoidRootPart") or targetModel.PrimaryPart
      if hrp then teleportTo(hrp.Position) end
      for _, d in ipairs(targetModel:GetDescendants()) do
         if d:IsA("ProximityPrompt") then
            if firePrompt(d) then return true end
         elseif d:IsA("ClickDetector") then
            if pcall(function() fireclickdetector(d) end) then return true end
         end
      end
   end

   -- 16-20: UI Buttons
   for _, obj in ipairs(Player.PlayerGui:GetDescendants()) do
      if obj:IsA("TextButton") then
         local txt = obj.Text:lower()
         for _, kw in ipairs(uiKeywords) do
            if txt:find(kw, 1, true) then
               pcall(function() obj:Activate() end)
               print("[Fallback] " .. actionName .. " -> UI Кнопка: " .. obj.Text)
               return true
            end
         end
      end
   end
   return false
end

-- =====================================================================
-- 5. GAME LOGIC (Autofarm & Decor)
-- =====================================================================
local function doOrder()
   tryInteract("Заказ: " .. State.SelectedTree, 
      {"OrderTree", "BuyTree", "Order", "Supply"}, 
      {"truck", "supply", "delivery"}, 
      {"order", "buy", "purchase", State.SelectedTree:lower()}
   )
end

local function doServe()
   tryInteract("Обслуживание клиента", {"SellTree", "LoadTree", "Sell"}, {"customer", "buyer", "car"}, {"sell", "load", "give"})
   task.wait(0.5)
   tryInteract("Касса", {"Checkout", "CompleteSale", "Pay"}, {"cashier", "register"}, {"pay", "checkout", "confirm"})
end

-- Функция Авто-Базы (Украшение)
local function doDecor()
   State.Status = "Покупка и установка декора..."
   
   -- 1. Ищем магазин декора / ящик с материалами
   local decorShop = findModel({"decor", "build", "shop", "materials", "crate"})
   if decorShop then
      local hrp = decorShop.PrimaryPart or decorShop:FindFirstChild("HumanoidRootPart")
      if hrp then teleportTo(hrp.Position) end
      
      -- 2. Пытаемся купить материалы (Гирлянды, Снег, Забор)
      tryInteract("Покупка декора", 
         {"BuyDecor", "PurchaseItem", "Buy"}, 
         {"decor", "build", "shop"}, 
         {"buy", "purchase", "snow", "light", "fence"}
      )
      State.DecorSpent += 500 -- Условная трата
      task.wait(1)
      
      -- 3. Ищем место на базе, куда это поставить
      tryInteract("Установка декора", 
         {"PlaceDecor", "PlaceItem", "Build"}, 
         {"foundation", "plot", "base"}, 
         {"place", "build", "confirm"}
      )
   end
end

-- =====================================================================
-- 6. UI CREATION
-- =====================================================================

-- 1. ГЛАВНАЯ
local HomeTab = Window:CreateTab("🎄 Главная", "home")
HomeTab:CreateSection("Доступ к хабу")
local OkButton
HomeTab:CreateButton({
   Name = "📋 Скопировать ссылку и подписаться",
   Callback = function()
      setclipboard(TELEGRAM_URL)
      playSound("6895079853") -- Звук клика
      Rayfield:Notify({Title = "Успех", Content = "Ссылка скопирована. Открой Telegram!", Duration = 5})
      task.wait(5); State.Subscribed = true
      if OkButton then OkButton:Set({Name = "✅ Доступ открыт"}) end
   end
})
OkButton = HomeTab:CreateButton({Name = "⛔ Ожидание подписки...", Callback = function() if not State.Subscribed then Rayfield:Notify({Title = "Закрыто", Content = "Подпишись сначала!", Duration = 4}) end end})

HomeTab:CreateSection("Статистика")
local StatusLabel = HomeTab:CreateLabel("📊 Статус: Ожидание")
local StatsLabel = HomeTab:CreateLabel("⏱️ Сессия: 0 мин | 💰 Действий: 0")

task.spawn(function()
   while true do
      task.wait(1)
      StatusLabel:Set("📊 Статус: " .. State.Status)
      local mins = math.floor((os.clock() - State.SessionStart) / 60)
      StatsLabel:Set(("⏱️ Сессия: %d мин | 💰 Действий: %d"):format(mins, State.TotalActions))
   end
end)

-- 2. АВТОФАРМ (Настройки)
local FarmTab = Window:CreateTab("🌲 Автофарм", "tree-pine")
FarmTab:CreateSection("Настройки деревьев")
FarmTab:CreateDropdown({
   Name = "Какое дерево заказывать?",
   Options = {"Pine", "Fir", "Spruce", "Noble", "Fraser", "Balsam"},
   CurrentOption = {"Pine"},
   Callback = function(opt) State.SelectedTree = opt[1] end
})

FarmTab:CreateSection("Модули автофарма")
FarmTab:CreateToggle({Name = "Авто-заказ", CurrentValue = false, Callback = function(v) State.AutoOrder = v end})
FarmTab:CreateToggle({Name = "Авто-обслуживание (Клиенты+Касса)", CurrentValue = false, Callback = function(v) State.AutoServe = v end})
FarmTab:CreateToggle({Name = "Авто-найм", CurrentValue = false, Callback = function(v) State.AutoHire = v end})
FarmTab:CreateToggle({Name = "Авто-апгрейды", CurrentValue = false, Callback = function(v) State.AutoUpgrade = v end})

FarmTab:CreateSection("Главный цикл")
FarmTab:CreateToggle({
   Name = "🚀 ЗАПУСТИТЬ АВТОФАРМ",
   CurrentValue = false,
   Callback = function(v)
      State.AutoFarm = v
      if v then
         State.AutoOrder = true; State.AutoServe = true; State.AutoHire = true; State.AutoUpgrade = true
         playSound("9118823103") -- Звук запуска (колокольчики)
         Rayfield:Notify({Title = "Автофарм", Content = "Цикл запущен!", Duration = 4})
      else
         State.AutoOrder = false; State.AutoServe = false; State.AutoHire = false; State.AutoUpgrade = false
      end
   end
})

-- 3. АВТО-БАЗА (Новая функция)
local DecorTab = Window:CreateTab("🏠 Авто-База", "hammer")
DecorTab:CreateSection("Улучшение и украшение")
DecorTab:CreateParagraph({Title = "Авто-декор", Content = "Скрипт будет автоматически покупать и расставлять новогодние украшения, если на вашей базе есть такая возможность."})

local DecorLabel = DecorTab:CreateLabel("Потрачено на декор: $0")
DecorTab:CreateToggle({
   Name = "🛠️ Авто-покупка и установка декора",
   CurrentValue = false,
   Callback = function(v)
      State.AutoDecor = v
      if v then
         playSound("9118823103")
         Rayfield:Notify({Title = "Авто-База", Content = "Начинаю украшать базу!", Duration = 4})
      end
   end
})

-- Обновление лейбла декора
task.spawn(function()
   while true do
      task.wait(1)
      DecorLabel:Set("Потрачено на декор: $" .. State.DecorSpent)
   end
end)

-- 4. ИГРОК (Скорость, ТП)
local PlayerTab = Window:CreateTab("🏃 Игрок", "user")
PlayerTab:CreateSection("Движение")
PlayerTab:CreateSlider({
   Name = "Скорость ходьбы",
   Range = {16, 300}, CurrentValue = 50,
   Callback = function(v) State.SpeedValue = v; if State.SpeedEnabled and Player.Character then Player.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = v end end
})
PlayerTab:CreateToggle({
   Name = "Включить скорость",
   CurrentValue = false,
   Callback = function(v) State.SpeedEnabled = v; if Player.Character then Player.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = v and State.SpeedValue or 16 end end
})

PlayerTab:CreateSection("Быстрые телепорты")
PlayerTab:CreateToggle({Name = "Плавный телепорт (Анимация)", CurrentValue = true, Callback = function(v) State.SmoothTeleport = v end})
PlayerTab:CreateButton({Name = "🚚 Телепорт к Грузовику", Callback = function() local m = findModel({"truck", "supply"}); if m and m.PrimaryPart then teleportTo(m.PrimaryPart.Position) end end})
PlayerTab:CreateButton({Name = "💰 Телепорт к Кассе", Callback = function() local m = findModel({"cashier", "register"}); if m and m.PrimaryPart then teleportTo(m.PrimaryPart.Position) end end})

-- 5. РАЗНОЕ (Коды, Анти-АФК)
local MiscTab = Window:CreateTab("🎁 Разное", "gift")
MiscTab:CreateSection("Промокоды")
local ActiveCodes = {"BLITZ", "MISTLETOE", "SNOWBALL", "HOHOHO", "IMBROKE", "BUDDYTHEELF", "JINGLEBELLS", "NICELIST", "OGTICKET", "YETI"}
MiscTab:CreateButton({
   Name = "🚀 Ввести все коды",
   Callback = function()
      if not State.Subscribed then return end
      playSound("6895079853")
      local r = findRemote({"RedeemCode", "Redeem", "Code"})
      if r then
         for _, code in ipairs(ActiveCodes) do r:FireServer(code); task.wait(0.4) end
         Rayfield:Notify({Title = "Коды", Content = "Введены через Remote!", Duration = 4})
      else
         setclipboard(table.concat(ActiveCodes, "\n"))
         Rayfield:Notify({Title = "Коды", Content = "Скопированы в буфер обмена.", Duration = 5})
      end
   end
})

MiscTab:CreateSection("Анти-АФК")
MiscTab:CreateToggle({Name = "Защита от кика", CurrentValue = true, Callback = function(v) State.AntiAFK = v end})
Player.Idled:Connect(function() if State.AntiAFK then game:GetService("VirtualUser"):CaptureController(); game:GetService("VirtualUser"):ClickButton2(Vector2.new()) end end)

-- =====================================================================
-- 7. BACKGROUND LOOP (Мотор скрипта)
-- =====================================================================
task.spawn(function()
   while true do
      task.wait(0.5)
      if State.Subscribed then
         -- Общая логика Автофарма
         if State.AutoFarm then
            if State.AutoServe then doServe() end
            if State.AutoOrder then doOrder() end
            if State.AutoHire then tryInteract("Найм", {"Hire"}, {"worker", "employee"}, {"hire"}) end
            if State.AutoUpgrade then tryInteract("Апгрейд", {"Upgrade"}, {"upgrade"}, {"upgrade", "buy"}) end
            State.TotalActions += 1
         end
         
         -- Логика Авто-Базы
         if State.AutoDecor then
            doDecor()
            task.wait(2)
         end
      end
   end
end)

-- Запуск
Rayfield:LoadConfiguration()
playSound("9118823103") -- Звук загрузки (колокольчики)
Rayfield:Notify({Title = "❄️ Winter Magic", Content = "CheatHub v7 успешно загружен!", Duration = 7})