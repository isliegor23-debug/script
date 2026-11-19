-- CheatHub v8 — Winter Magic Edition
-- Run a Christmas Tree Lot
-- by dj

-- =====================================================================
-- 0. CONFIG
-- =====================================================================
local CONFIG = {
   TelegramUrl = "https://t.me/my_christmas_market",
   RequireSubscribe = true,  -- false = доступ открыт сразу (проверить подписку скрипт всё равно не может)
   LoopDelay = 0.6,          -- пауза главного цикла
   CacheTTL = 10,            -- сколько секунд помнить найденные ремоуты/модели
   Debug = false,            -- true = подробный вывод в консоль
}

-- Защита от двойного запуска
local env = (type(getgenv) == "function" and getgenv()) or _G
if env.CheatHubWinter and env.CheatHubWinter.Unload then
   pcall(env.CheatHubWinter.Unload)
end

-- =====================================================================
-- 1. SERVICES
-- =====================================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local VirtualUser = game:GetService("VirtualUser")
local Player = Players.LocalPlayer

local function dbg(...)
   if CONFIG.Debug then print("[CheatHub]", ...) end
end

local function playSound(id)
   pcall(function()
      local s = Instance.new("Sound")
      s.SoundId = "rbxassetid://" .. id
      s.Volume = 0.5
      s.Parent = SoundService
      s:Play()
      task.delay(5, function() s:Destroy() end)
   end)
end

-- =====================================================================
-- 2. EXECUTOR COMPATIBILITY
-- =====================================================================
local Executor = { Name = "Unknown", IsXeno = false }
if type(identifyexecutor) == "function" then
   local ok, n = pcall(identifyexecutor)
   if ok and n then Executor.Name = tostring(n) end
end
Executor.IsXeno = Executor.Name:lower():find("xeno", 1, true) ~= nil

local function holdPrompt(prompt)
   return pcall(function()
      prompt:InputHoldBegin()
      task.wait(math.max(prompt.HoldDuration, 0) + 0.1)
      prompt:InputHoldEnd()
   end)
end

local function firePrompt(prompt)
   if not prompt or not prompt.Enabled then return false end
   if type(fireproximityprompt) == "function" and not Executor.IsXeno then
      if pcall(fireproximityprompt, prompt) then return true end
   end
   return holdPrompt(prompt)
end

-- Клик по GUI-кнопке (у TextButton нет метода :Activate())
local function clickGui(button)
   if type(getconnections) == "function" then
      local fired = 0
      pcall(function()
         for _, signal in ipairs({ button.MouseButton1Click, button.Activated }) do
            for _, c in ipairs(getconnections(signal)) do
               c:Fire()
               fired += 1
            end
         end
      end)
      if fired > 0 then return true end
   end
   if type(firesignal) == "function" then
      return pcall(firesignal, button.MouseButton1Click)
   end
   return false
end

-- =====================================================================
-- 3. UI LIBRARY & THEME
-- =====================================================================
local okLoad, Rayfield = pcall(function()
   return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not okLoad or not Rayfield then
   warn("[CheatHub] Rayfield не загрузился: " .. tostring(Rayfield))
   return
end

-- Полная таблица ключей Rayfield (неполная тема ломает элементы)
local Theme = {
   TextColor = Color3.fromRGB(255, 255, 255),
   Background = Color3.fromRGB(20, 30, 40),
   Topbar = Color3.fromRGB(30, 45, 60),
   Shadow = Color3.fromRGB(10, 15, 20),

   NotificationBackground = Color3.fromRGB(20, 30, 40),
   NotificationActionsBackground = Color3.fromRGB(220, 40, 40),

   TabBackground = Color3.fromRGB(40, 55, 70),
   TabStroke = Color3.fromRGB(60, 80, 100),
   TabBackgroundSelected = Color3.fromRGB(220, 40, 40),
   TabTextColor = Color3.fromRGB(200, 220, 230),
   SelectedTabTextColor = Color3.fromRGB(255, 255, 255),

   ElementBackground = Color3.fromRGB(30, 45, 60),
   ElementBackgroundHover = Color3.fromRGB(40, 58, 76),
   SecondaryElementBackground = Color3.fromRGB(25, 38, 50),
   ElementStroke = Color3.fromRGB(60, 80, 100),
   SecondaryElementStroke = Color3.fromRGB(50, 70, 90),

   SliderBackground = Color3.fromRGB(150, 30, 30),
   SliderProgress = Color3.fromRGB(220, 40, 40),
   SliderStroke = Color3.fromRGB(240, 70, 70),

   ToggleBackground = Color3.fromRGB(25, 38, 50),
   ToggleEnabled = Color3.fromRGB(220, 40, 40),
   ToggleDisabled = Color3.fromRGB(100, 110, 120),
   ToggleEnabledStroke = Color3.fromRGB(240, 70, 70),
   ToggleDisabledStroke = Color3.fromRGB(125, 135, 145),
   ToggleEnabledOuterStroke = Color3.fromRGB(100, 120, 140),
   ToggleDisabledOuterStroke = Color3.fromRGB(65, 80, 95),

   DropdownSelected = Color3.fromRGB(40, 58, 76),
   DropdownUnselected = Color3.fromRGB(30, 45, 60),

   InputBackground = Color3.fromRGB(25, 38, 50),
   InputStroke = Color3.fromRGB(65, 85, 105),
   PlaceholderColor = Color3.fromRGB(178, 190, 200),
}

local Window = Rayfield:CreateWindow({
   Name = "❄️ CheatHub | Winter Magic",
   LoadingTitle = "Снежная буря загружается...",
   LoadingSubtitle = "v8",
   Theme = Theme,
   ConfigurationSaving = { Enabled = true, FolderName = "CheatHubWinter", FileName = "Config" },
   KeySystem = false,
})

-- =====================================================================
-- 4. STATE & UTILS
-- =====================================================================
local State = {
   Running = true,
   Subscribed = not CONFIG.RequireSubscribe,
   AutoFarm = false,
   AutoOrder = true, AutoServe = true, AutoHire = true, AutoUpgrade = true,
   AutoDecor = false,
   SelectedTree = "Pine",
   AntiAFK = true, SmoothTeleport = true,
   SpeedEnabled = false, SpeedValue = 50,
   Status = "Ожидание...",
   SessionStart = os.clock(),
   TotalActions = 0, DecorActions = 0,
}

local Connections = {}

local function getHRP()
   local c = Player.Character
   return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
   local c = Player.Character
   return c and c:FindFirstChildOfClass("Humanoid")
end

local function applySpeed()
   local hum = getHumanoid()
   if hum then hum.WalkSpeed = State.SpeedEnabled and State.SpeedValue or 16 end
end

local function teleportTo(pos)
   local hrp = getHRP()
   if not hrp or not pos then return false end
   local target = pos + Vector3.new(0, 3, 0)
   local dist = (hrp.Position - target).Magnitude
   if dist < 6 then return true end -- уже рядом
   if State.SmoothTeleport then
      local t = math.clamp(dist / 200, 0.1, 1.0)
      TweenService:Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(target) }):Play()
      task.wait(t + 0.05)
   else
      hrp.CFrame = CFrame.new(target)
   end
   return true
end

-- =====================================================================
-- 5. SEARCH ENGINE (с кэшем)
-- =====================================================================
local Cache = {}
local function cached(key, finder)
   local e = Cache[key]
   if e and (os.clock() - e.t) < CONFIG.CacheTTL and (e.v == nil or e.v.Parent) then
      return e.v
   end
   local v = finder()
   Cache[key] = { v = v, t = os.clock() }
   return v
end

local function findRemote(names)
   return cached("r:" .. table.concat(names, "|"), function()
      for _, parent in ipairs({ RS, WS }) do
         for _, name in ipairs(names) do
            local obj = parent:FindFirstChild(name, true)
            if obj and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then return obj end
         end
      end
      return nil
   end)
end

local function findModel(keywords)
   return cached("m:" .. table.concat(keywords, "|"), function()
      local best, bestScore
      for _, obj in ipairs(WS:GetDescendants()) do
         if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
            local n = obj.Name:lower()
            for _, kw in ipairs(keywords) do
               if n:find(kw, 1, true) then
                  local score = (n == kw) and 2 or 1
                  if obj:FindFirstChildWhichIsA("ProximityPrompt", true) or obj:FindFirstChildWhichIsA("ClickDetector", true) then
                     score += 3 -- модели с интерактивом в приоритете
                  end
                  if not bestScore or score > bestScore then best, bestScore = obj, score end
                  break
               end
            end
         end
      end
      return best
   end)
end

local function modelPosition(model)
   if not model then return nil end
   local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
   return part and part.Position
end

local function findButton(uiKeywords)
   for _, obj in ipairs(Player.PlayerGui:GetDescendants()) do
      if obj:IsA("TextButton") and obj.Visible and not obj:FindFirstAncestor("Rayfield") then
         local txt = obj.Text:lower()
         for _, kw in ipairs(uiKeywords) do
            if txt:find(kw, 1, true) then return obj end
         end
      end
   end
   return nil
end

-- =====================================================================
-- 6. FALLBACK ENGINE: Remote -> Prompt/ClickDetector -> UI
-- Возвращает true только при реально выполненной попытке
-- =====================================================================
local lastUiScan = {}

local function tryInteract(action, remoteNames, modelKeywords, uiKeywords)
   State.Status = "Действие: " .. action

   -- 1) Remote
   local r = remoteNames and findRemote(remoteNames)
   if r then
      local ok = pcall(function()
         if r:IsA("RemoteEvent") then r:FireServer() else r:InvokeServer() end
      end)
      if ok then
         dbg(action, "-> Remote:", r.Name)
         return true
      end
   end

   -- 2) ProximityPrompt / ClickDetector
   local model = modelKeywords and findModel(modelKeywords)
   if model then
      teleportTo(modelPosition(model))
      for _, d in ipairs(model:GetDescendants()) do
         if d:IsA("ProximityPrompt") then
            if firePrompt(d) then
               dbg(action, "-> Prompt:", d:GetFullName())
               return true
            end
         elseif d:IsA("ClickDetector") and type(fireclickdetector) == "function" then
            if pcall(fireclickdetector, d) then
               dbg(action, "-> ClickDetector:", d:GetFullName())
               return true
            end
         end
      end
   end

   -- 3) UI-кнопки (не чаще раза в 3 сек на действие — скан PlayerGui тяжёлый)
   if uiKeywords and (os.clock() - (lastUiScan[action] or 0)) > 3 then
      lastUiScan[action] = os.clock()
      local btn = findButton(uiKeywords)
      if btn and clickGui(btn) then
         dbg(action, "-> UI:", btn.Text)
         return true
      end
   end

   return false
end

-- =====================================================================
-- 7. GAME LOGIC
-- =====================================================================
local function doOrder()
   return tryInteract("Заказ: " .. State.SelectedTree,
      { "OrderTree", "BuyTree", "Order", "Supply" },
      { "truck", "supply", "delivery" },
      { "order", "buy", "purchase", State.SelectedTree:lower() })
end

local function doServe()
   local a = tryInteract("Обслуживание клиента", { "SellTree", "LoadTree", "Sell" }, { "customer", "buyer" }, { "sell", "load", "give" })
   task.wait(0.5)
   local b = tryInteract("Касса", { "Checkout", "CompleteSale", "Pay" }, { "cashier", "register" }, { "pay", "checkout", "confirm" })
   return a or b
end

local function doDecor()
   local shop = findModel({ "decor", "build", "shop", "materials", "crate" })
   if not shop then
      State.Status = "Декор: магазин не найден"
      return false
   end
   State.Status = "Покупка и установка декора..."
   teleportTo(modelPosition(shop))

   local bought = tryInteract("Покупка декора",
      { "BuyDecor", "PurchaseItem", "Buy" },
      { "decor", "build", "shop" },
      { "buy", "purchase", "snow", "light", "fence" })
   task.wait(1)
   local placed = tryInteract("Установка декора",
      { "PlaceDecor", "PlaceItem", "Build" },
      { "foundation", "plot", "base" },
      { "place", "build", "confirm" })

   if bought or placed then State.DecorActions += 1 end
   return bought or placed
end

-- =====================================================================
-- 8. UI
-- =====================================================================

-- ГЛАВНАЯ
local HomeTab = Window:CreateTab("🎄 Главная", "home")
HomeTab:CreateSection("Доступ к хабу")

local OkButton
local function unlock()
   State.Subscribed = true
   if OkButton then OkButton:Set("✅ Доступ открыт") end
end

HomeTab:CreateButton({
   Name = "📋 Скопировать ссылку и подписаться",
   Callback = function()
      if type(setclipboard) == "function" then pcall(setclipboard, CONFIG.TelegramUrl) end
      playSound("6895079853")
      Rayfield:Notify({ Title = "Ссылка скопирована", Content = "Открой Telegram. Доступ откроется через 5 секунд.", Duration = 5 })
      task.delay(5, function() if State.Running then unlock() end end)
   end,
})

OkButton = HomeTab:CreateButton({
   Name = State.Subscribed and "✅ Доступ открыт" or "⛔ Ожидание подписки...",
   Callback = function()
      if not State.Subscribed then
         Rayfield:Notify({ Title = "Закрыто", Content = "Сначала нажми кнопку выше.", Duration = 4 })
      end
   end,
})

HomeTab:CreateSection("Статистика")
local StatusLabel = HomeTab:CreateLabel("📊 Статус: Ожидание")
local StatsLabel = HomeTab:CreateLabel("⏱️ Сессия: 0 мин | 💰 Действий: 0")

-- АВТОФАРМ
local FarmTab = Window:CreateTab("🌲 Автофарм", "tree-pine")
FarmTab:CreateSection("Настройки деревьев")
FarmTab:CreateDropdown({
   Name = "Какое дерево заказывать?",
   Options = { "Pine", "Fir", "Spruce", "Noble", "Fraser", "Balsam" },
   CurrentOption = { "Pine" },
   MultipleOptions = false,
   Flag = "TreeType",
   Callback = function(opt)
      State.SelectedTree = (type(opt) == "table" and opt[1]) or opt or "Pine"
   end,
})

FarmTab:CreateSection("Модули (работают, когда включён главный цикл)")
FarmTab:CreateToggle({ Name = "Авто-заказ", CurrentValue = true, Flag = "AutoOrder", Callback = function(v) State.AutoOrder = v end })
FarmTab:CreateToggle({ Name = "Авто-обслуживание (клиенты + касса)", CurrentValue = true, Flag = "AutoServe", Callback = function(v) State.AutoServe = v end })
FarmTab:CreateToggle({ Name = "Авто-найм", CurrentValue = true, Flag = "AutoHire", Callback = function(v) State.AutoHire = v end })
FarmTab:CreateToggle({ Name = "Авто-апгрейды", CurrentValue = true, Flag = "AutoUpgrade", Callback = function(v) State.AutoUpgrade = v end })

FarmTab:CreateSection("Главный цикл")
FarmTab:CreateToggle({
   Name = "🚀 ЗАПУСТИТЬ АВТОФАРМ",
   CurrentValue = false,
   Callback = function(v)
      if v and not State.Subscribed then
         Rayfield:Notify({ Title = "Закрыто", Content = "Сначала открой доступ на вкладке «Главная».", Duration = 4 })
      end
      State.AutoFarm = v
      if v then
         playSound("9118823103")
         Rayfield:Notify({ Title = "Автофарм", Content = "Цикл запущен!", Duration = 4 })
      end
   end,
})

-- АВТО-БАЗА
local DecorTab = Window:CreateTab("🏠 Авто-База", "hammer")
DecorTab:CreateSection("Улучшение и украшение")
DecorTab:CreateParagraph({ Title = "Авто-декор", Content = "Скрипт покупает и расставляет декор, если на базе есть такая возможность." })
local DecorLabel = DecorTab:CreateLabel("Действий с декором: 0")
DecorTab:CreateToggle({
   Name = "🛠️ Авто-покупка и установка декора",
   CurrentValue = false,
   Callback = function(v)
      if v and not State.Subscribed then
         Rayfield:Notify({ Title = "Закрыто", Content = "Сначала открой доступ на вкладке «Главная».", Duration = 4 })
      end
      State.AutoDecor = v
      if v then
         playSound("9118823103")
         Rayfield:Notify({ Title = "Авто-База", Content = "Начинаю украшать базу!", Duration = 4 })
      end
   end,
})

-- ИГРОК
local PlayerTab = Window:CreateTab("🏃 Игрок", "user")
PlayerTab:CreateSection("Движение")
PlayerTab:CreateSlider({
   Name = "Скорость ходьбы",
   Range = { 16, 300 },
   Increment = 1,
   Suffix = "",
   CurrentValue = 50,
   Flag = "SpeedValue",
   Callback = function(v)
      State.SpeedValue = v
      if State.SpeedEnabled then applySpeed() end
   end,
})
PlayerTab:CreateToggle({
   Name = "Включить скорость",
   CurrentValue = false,
   Callback = function(v)
      State.SpeedEnabled = v
      applySpeed()
   end,
})

PlayerTab:CreateSection("Быстрые телепорты")
PlayerTab:CreateToggle({ Name = "Плавный телепорт (анимация)", CurrentValue = true, Flag = "SmoothTP", Callback = function(v) State.SmoothTeleport = v end })
PlayerTab:CreateButton({
   Name = "🚚 Телепорт к грузовику",
   Callback = function()
      local pos = modelPosition(findModel({ "truck", "supply" }))
      if pos then teleportTo(pos) else Rayfield:Notify({ Title = "Не найдено", Content = "Грузовик не найден.", Duration = 3 }) end
   end,
})
PlayerTab:CreateButton({
   Name = "💰 Телепорт к кассе",
   Callback = function()
      local pos = modelPosition(findModel({ "cashier", "register" }))
      if pos then teleportTo(pos) else Rayfield:Notify({ Title = "Не найдено", Content = "Касса не найдена.", Duration = 3 }) end
   end,
})

-- РАЗНОЕ
local MiscTab = Window:CreateTab("🎁 Разное", "gift")
MiscTab:CreateSection("Промокоды")
local ActiveCodes = { "BLITZ", "MISTLETOE", "SNOWBALL", "HOHOHO", "IMBROKE", "BUDDYTHEELF", "JINGLEBELLS", "NICELIST", "OGTICKET", "YETI" }
MiscTab:CreateButton({
   Name = "🚀 Ввести все коды",
   Callback = function()
      if not State.Subscribed then
         Rayfield:Notify({ Title = "Закрыто", Content = "Сначала открой доступ на вкладке «Главная».", Duration = 4 })
         return
      end
      playSound("6895079853")
      local r = findRemote({ "RedeemCode", "Redeem", "Code" })
      if r then
         for _, code in ipairs(ActiveCodes) do
            pcall(function()
               if r:IsA("RemoteEvent") then r:FireServer(code) else r:InvokeServer(code) end
            end)
            task.wait(0.4)
         end
         Rayfield:Notify({ Title = "Коды", Content = "Отправлены через Remote. Часть кодов могла устареть.", Duration = 4 })
      elseif type(setclipboard) == "function" then
         setclipboard(table.concat(ActiveCodes, "\n"))
         Rayfield:Notify({ Title = "Коды", Content = "Remote не найден — коды скопированы в буфер.", Duration = 5 })
      else
         Rayfield:Notify({ Title = "Коды", Content = "Remote не найден, буфер обмена недоступен.", Duration = 5 })
      end
   end,
})

MiscTab:CreateSection("Анти-АФК")
MiscTab:CreateToggle({ Name = "Защита от кика", CurrentValue = true, Flag = "AntiAFK", Callback = function(v) State.AntiAFK = v end })

MiscTab:CreateSection("Управление")
MiscTab:CreateButton({
   Name = "🗑️ Выгрузить скрипт",
   Callback = function()
      if env.CheatHubWinter and env.CheatHubWinter.Unload then env.CheatHubWinter.Unload() end
   end,
})

-- =====================================================================
-- 9. CONNECTIONS & UNLOAD
-- =====================================================================
table.insert(Connections, Player.Idled:Connect(function()
   if State.AntiAFK then
      pcall(function()
         VirtualUser:CaptureController()
         VirtualUser:ClickButton2(Vector2.new())
      end)
   end
end))

table.insert(Connections, Player.CharacterAdded:Connect(function()
   task.wait(0.5)
   if State.SpeedEnabled then applySpeed() end
end))

local function Unload()
   State.Running = false
   State.AutoFarm = false
   State.AutoDecor = false
   for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
   local hum = getHumanoid()
   if hum then hum.WalkSpeed = 16 end
   pcall(function() Rayfield:Destroy() end)
   env.CheatHubWinter = nil
end
env.CheatHubWinter = { Unload = Unload }

-- =====================================================================
-- 10. BACKGROUND LOOPS
-- =====================================================================

-- Обновление интерфейса
task.spawn(function()
   while State.Running do
      task.wait(1)
      pcall(function()
         StatusLabel:Set("📊 Статус: " .. State.Status)
         local mins = math.floor((os.clock() - State.SessionStart) / 60)
         StatsLabel:Set(("⏱️ Сессия: %d мин | 💰 Действий: %d"):format(mins, State.TotalActions))
         DecorLabel:Set("Действий с декором: " .. State.DecorActions)
         if State.SpeedEnabled then applySpeed() end -- некоторые игры сбрасывают скорость
      end)
   end
end)

-- Главный цикл (каждая итерация под pcall, чтобы одна ошибка не убила цикл)
task.spawn(function()
   while State.Running do
      task.wait(CONFIG.LoopDelay)
      if State.Subscribed then
         local ok, err = pcall(function()
            if State.AutoFarm then
               local did = false
               if State.AutoServe and doServe() then did = true end
               if State.AutoOrder and doOrder() then did = true end
               if State.AutoHire and tryInteract("Найм", { "Hire" }, { "worker", "employee" }, { "hire" }) then did = true end
               if State.AutoUpgrade and tryInteract("Апгрейд", { "Upgrade" }, { "upgrade" }, { "upgrade", "buy" }) then did = true end
               if did then State.TotalActions += 1 end
            end
            if State.AutoDecor then
               doDecor()
               task.wait(2)
            end
         end)
         if not ok then dbg("Ошибка цикла:", err) end
      end
   end
end)

-- =====================================================================
-- 11. START
-- =====================================================================
Rayfield:LoadConfiguration()
playSound("9118823103")
Rayfield:Notify({ Title = "❄️ Winter Magic", Content = "CheatHub v8 загружен!", Duration = 6 })
