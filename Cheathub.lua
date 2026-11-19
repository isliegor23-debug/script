-- CheatHub v4 — Run a Christmas Tree Lot
-- Premium UI & Animations Edition
-- by dj

local TELEGRAM_URL = "https://t.me/my_christmas_market"

-- =====================================================================
-- 0. EXECUTOR COMPATIBILITY LAYER (Delta / Xeno)
-- =====================================================================
local Executor = { Name = "Unknown", IsDelta = false, IsXeno = false, HasFirePrompt = false, HasFireClick = false, HasClipboard = false, RequestFn = nil }

local function detectExecutor()
   local name = "Unknown"
   if type(identifyexecutor) == "function" then
      local ok, n = pcall(identifyexecutor); if ok and n then name = tostring(n) end
   elseif type(getexecutorname) == "function" then
      local ok, n = pcall(getexecutorname); if ok and n then name = tostring(n) end
   end
   local l = name:lower()
   Executor.Name = name; Executor.IsDelta = l:find("delta") ~= nil; Executor.IsXeno = l:find("xeno") ~= nil
end
detectExecutor()

Executor.HasFirePrompt = type(fireproximityprompt) == "function"
Executor.HasFireClick = type(fireclickdetector) == "function"
Executor.HasClipboard = type(setclipboard) == "function"

local function resolveRequest()
   local candidates = { {name = "syn.request", fn = syn and syn.request}, {name = "http_request", fn = http_request}, {name = "request", fn = request}, {name = "http.request", fn = http and http.request} }
   for _, c in ipairs(candidates) do if type(c.fn) == "function" then Executor.RequestFn = c.fn; return end end
end
resolveRequest()

local function firePrompt(prompt)
   if not prompt then return false end
   if Executor.IsXeno or not Executor.HasFirePrompt then
      local ok = pcall(function() prompt:InputHoldBegin(); task.wait(math.max(prompt.HoldDuration or 0.1, 0.1) + 0.05); prompt:InputHoldEnd() end)
      if ok then return true end
   end
   if Executor.HasFirePrompt then
      local ok = pcall(function() fireproximityprompt(prompt, 0) end); if ok then return true end
   end
   return pcall(function() prompt:InputHoldBegin(); task.wait(0.1); prompt:InputHoldEnd() end)
end

local function fireClick(cd)
   if not cd then return false end
   if Executor.HasFireClick then local ok = pcall(function() fireclickdetector(cd) end); if ok then return true end end
   return pcall(function() cd:FireClickDetector() end)
end

local function copyToClipboard(text)
   if type(setclipboard) == "function" then local ok = pcall(setclipboard, text); if ok then return true end end
   if type(toclipboard) == "function" then local ok = pcall(toclipboard, text); if ok then return true end end
   return false
end

-- =====================================================================
-- 1. UI LIBRARY & THEME SETUP
-- =====================================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Настройка кастомной темы (Рождественский стиль)
local Theme = {
    TextColor = Color3.fromRGB(240, 240, 240),
    SubTextColor = Color3.fromRGB(180, 180, 180),
    Background = Color3.fromRGB(15, 15, 20),
    Topbar = Color3.fromRGB(25, 25, 35),
    Accent = Color3.fromRGB(255, 50, 50), -- Красный акцент
    Outline = Color3.fromRGB(40, 40, 50),
    Button = Color3.fromRGB(35, 35, 45),
    Element = Color3.fromRGB(25, 25, 35),
    Dropdown = Color3.fromRGB(30, 30, 40)
}

local Window = Rayfield:CreateWindow({
   Name = "🎄 CheatHub Premium",
   LoadingTitle = "CheatHub Loading...",
   LoadingSubtitle = "Preparing Winter Magic",
   Theme = Theme,
   ConfigurationSaving = { Enabled = true, FolderName = "CheatHub", FileName = "PremiumConfig" },
   KeySystem = false
})

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Player = Players.LocalPlayer

-- =====================================================================
-- 2. STATE
-- =====================================================================
local State = {
   Subscribed = false,
   AutoFarm = false, AutoOrder = false, AutoPlace = false, AutoSell = false,
   AutoCollect = false, AutoHire = false, AutoUpgrade = false,
   SpeedEnabled = false, FlyEnabled = false, NoclipEnabled = false,
   TreeESP = false, CustomerESP = false, AntiAFK = true,
   SmoothTeleport = true,
   PerfMode = "Medium", SpeedValue = 50, SellDelay = 1.0, OrderDelay = 2.0,
   SelectedTreeTypes = {}, TreeCache = {}, CustomerCache = {}, RemoteCache = {},
   SessionStart = os.clock(), TotalOrders = 0, TotalSales = 0, TotalPlaced = 0
}

local function waitMode()
   local d = State.PerfMode == "Turbo" and 0.05 or State.PerfMode == "Fast" and 0.1 or 0.25
   task.wait(d)
end

-- =====================================================================
-- 3. UTILS & DISCOVERY
-- =====================================================================
local function getHRP() return Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") end

-- Красивая функция телепорта
local function teleportTo(pos)
   local hrp = getHRP()
   if not hrp then return false end
   local targetPos = pos + Vector3.new(0, 5, 0)
   
   if State.SmoothTeleport then
      -- Плавный пролет (анимация)
      local distance = (hrp.Position - targetPos).Magnitude
      local speed = 150 -- studs per second
      local time = math.clamp(distance / speed, 0.1, 1.5) 
      
      local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
      local tween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(targetPos)})
      tween:Play()
      tween.Completed:Wait()
   else
      -- Мгновенный телепорт
      hrp.CFrame = CFrame.new(targetPos)
   end
   return true
end

local function findRemoteDeep(purpose, candidates)
   if State.RemoteCache[purpose] and State.RemoteCache[purpose].Parent then return State.RemoteCache[purpose] end
   for _, parent in ipairs({RS, WS}) do
      for _, name in ipairs(candidates) do
         local obj = parent:FindFirstChild(name, true)
         if obj and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent")) then
            State.RemoteCache[purpose] = obj; return obj
         end
      end
   end
   return nil
end

local function scanForKeyword(keywords, classFilter)
   local list = {}
   for _, obj in ipairs(WS:GetDescendants()) do
      if (not classFilter) or obj:IsA(classFilter) then
         local n = obj.Name:lower()
         for _, kw in ipairs(keywords) do if n:find(kw, 1, true) then table.insert(list, obj); break end end
      end
   end
   return list
end

local function refreshTreeCache() State.TreeCache = scanForKeyword({"tree", "fir", "pine", "ель", "ёлка", "дерево"}, "Model"); return State.TreeCache end
local function refreshCustomerCache() State.CustomerCache = scanForKeyword({"customer", "buyer", "shopper", "покупатель"}, "Model"); return State.CustomerCache end
local function getPrompts(root) local p = {}; for _, d in ipairs(root:GetDescendants()) do if d:IsA("ProximityPrompt") then table.insert(p, d) end end; return p end
local function getClickDetectors(root) local c = {}; for _, d in ipairs(root:GetDescendants()) do if d:IsA("ClickDetector") then table.insert(c, d) end end; return c end

-- =====================================================================
-- 4. UI: HOME TAB
-- =====================================================================
local HomeTab = Window:CreateTab("🏠 Главная", "home")
HomeTab:CreateSection("Доступ")
local OkButton

HomeTab:CreateButton({
   Name = "📋 Скопировать ссылку и подписаться",
   Callback = function()
      copyToClipboard(TELEGRAM_URL)
      Rayfield:Notify({Title = "Успех", Content = "Ссылка скопирована. Открой Telegram!", Duration = 5, Image = "check"})
      task.wait(5)
      State.Subscribed = true
      if OkButton then OkButton:Set({Name = "✅ Доступ открыт"}) end
      Rayfield:Notify({Title = "Добро пожаловать!", Content = "Все функции разблокированы.", Duration = 5, Image = "check"})
   end
})

OkButton = HomeTab:CreateButton({
   Name = "⛔ Ожидание подписки...",
   Callback = function()
      if not State.Subscribed then
         Rayfield:Notify({Title = "Внимание", Content = "Сначала скопируй ссылку и подпишись.", Duration = 4, Image = "alert-circle"})
      end
   end
})

HomeTab:CreateSection("Информация")
HomeTab:CreateLabel("👨‍💻 Исполнитель: " .. Executor.Name)
local StatsLabel = HomeTab:CreateLabel("⏱️ Сессия: 0 мин | 📦 Заказов: 0 | 💰 Продаж: 0")
task.spawn(function()
   while true do
      task.wait(2)
      StatsLabel:Set(("⏱️ Сессия: %d мин | 📦 Заказов: %d | 💰 Продаж: %d"):format(math.floor((os.clock() - State.SessionStart) / 60), State.TotalOrders, State.TotalSales))
   end
end)

-- =====================================================================
-- 5. UI: FARM TAB
-- =====================================================================
local FarmTab = Window:CreateTab("🌲 Автофарм", "tree-pine")
FarmTab:CreateSection("Настройки скорости")
FarmTab:CreateDropdown({
   Name = "Режим работы", Options = {"Turbo (Максимум)", "Fast (Быстро)", "Medium (Стабильно)"},
   CurrentOption = {"Medium (Стабильно)"},
   Callback = function(opt)
      local s = opt[1]
      if s:find("Turbo") then State.PerfMode = "Turbo" elseif s:find("Fast") then State.PerfMode = "Fast" else State.PerfMode = "Medium" end
      Rayfield:Notify({Title = "Режим", Content = "Установлен " .. State.PerfMode, Duration = 3, Image = "settings"})
   end
})

FarmTab:CreateSection("Ассортимент (что заказывать)")
local TreeTypes = {"Pine", "Fir", "Spruce", "Noble", "Douglas", "Fraser"}
for _, tt in ipairs(TreeTypes) do
   FarmTab:CreateToggle({ Name = "🌲 " .. tt, CurrentValue = false, Callback = function(v) if v then State.SelectedTreeTypes[tt] = true else State.SelectedTreeTypes[tt] = nil end end })
end

FarmTab:CreateSection("Тайминги (Задержки)")
FarmTab:CreateSlider({ Name = "Задержка заказа", Range = {0.5, 10}, CurrentValue = 2.0, Suffix = " сек", Callback = function(v) State.OrderDelay = v end })
FarmTab:CreateSlider({ Name = "Задержка продажи", Range = {0.3, 5}, CurrentValue = 1.0, Suffix = " сек", Callback = function(v) State.SellDelay = v end })

FarmTab:CreateSection("Управление")
FarmTab:CreateToggle({
   Name = "🚀 ПОЛНЫЙ АВТОФАРМ (Всё сразу)",
   CurrentValue = false,
   Callback = function(v)
      State.AutoFarm = v; State.AutoOrder = v; State.AutoPlace = v; State.AutoSell = v; State.AutoCollect = v; State.AutoHire = v; State.AutoUpgrade = v
      if v then Rayfield:Notify({Title = "Автофарм", Content = "Полный цикл запущен!", Duration = 4, Image = "play"}) end
   end
})

FarmTab:CreateSection("Отдельные действия")
FarmTab:CreateToggle({Name = "Заказ деревьев", CurrentValue = false, Callback = function(v) State.AutoOrder = v; if v then task.spawn(function() while State.AutoOrder do if State.Subscribed then local r = findRemoteDeep("order", {"OrderTree", "Order", "BuyTree", "StockTree"}); if r then local types = {}; for tt, _ in pairs(State.SelectedTreeTypes) do table.insert(types, tt) end; if #types == 0 then types = {"Pine"} end; for _, tt in ipairs(types) do r:FireServer(tt) task.wait(0.1) end; State.TotalOrders += 1 end end task.wait(State.OrderDelay) end end) end end})
FarmTab:CreateToggle({Name = "Продажа покупателям", CurrentValue = false, Callback = function(v) State.AutoSell = v; if v then task.spawn(function() while State.AutoSell do if State.Subscribed then local r = findRemoteDeep("sell", {"SellTree", "Sell", "CompleteSale"}); if r then r:FireServer() State.TotalSales += 1 else local custs = refreshCustomerCache(); for _, c in ipairs(custs) do local hrp = c:FindFirstChild("HumanoidRootPart"); if hrp then teleportTo(hrp.Position); local done = false; for _, p in ipairs(getPrompts(c)) do if firePrompt(p) then done = true; break end end; if done then State.TotalSales += 1; break end end end end end task.wait(State.SellDelay) end end) end end})
FarmTab:CreateToggle({Name = "Сбор денег", CurrentValue = false, Callback = function(v) State.AutoCollect = v; if v then task.spawn(function() while State.AutoCollect do if State.Subscribed then local r = findRemoteDeep("collect", {"CollectCash", "ClaimCash", "CollectMoney", "Cash"}); if r then r:FireServer() end end task.wait(1) end end) end end})

-- =====================================================================
-- 6. UI: VISUALS TAB (ESP)
-- =====================================================================
local VisualTab = Window:CreateTab("👁️ Визуал (ESP)", "eye")
VisualTab:CreateSection("Подсветка объектов")
VisualTab:CreateToggle({Name = "Подсвечивать покупателей", CurrentValue = false, Callback = function(v) State.CustomerESP = v; if not v then local e = Player.PlayerGui:FindFirstChild("CheatHubCustomerESP"); if e then e:Destroy() end; return end; local folder = Player.PlayerGui:FindFirstChild("CheatHubCustomerESP") or Instance.new("Folder", Player.PlayerGui); folder.Name = "CheatHubCustomerESP"; task.spawn(function() while State.CustomerESP do for _, c in ipairs(refreshCustomerCache()) do local hrp = c:FindFirstChild("HumanoidRootPart"); if hrp and not hrp:FindFirstChild("CH_CustBill") then local bill = Instance.new("BillboardGui"); bill.Name = "CH_CustBill"; bill.Adornee = hrp; bill.Size = UDim2.new(0, 80, 0, 30); bill.AlwaysOnTop = true; bill.Parent = folder; local txt = Instance.new("TextLabel", bill); txt.Size = UDim2.new(1, 0, 1, 0); txt.BackgroundTransparency = 1; txt.Text = "👤 Клиент"; txt.TextColor3 = Color3.fromRGB(255, 100, 100); txt.TextStrokeTransparency = 0; txt.TextScaled = true end end; task.wait(1) end end) end})

VisualTab:CreateToggle({Name = "Подсвечивать деревья", CurrentValue = false, Callback = function(v) State.TreeESP = v; if not v then local e = Player.PlayerGui:FindFirstChild("CheatHubTreeESP"); if e then e:Destroy() end; return end; local folder = Player.PlayerGui:FindFirstChild("CheatHubTreeESP") or Instance.new("Folder", Player.PlayerGui); folder.Name = "CheatHubTreeESP"; task.spawn(function() while State.TreeESP do for _, t in ipairs(refreshTreeCache()) do local hrp = t:FindFirstChild("HumanoidRootPart") or t.PrimaryPart; if hrp and not hrp:FindFirstChild("CH_TreeBill") then local bill = Instance.new("BillboardGui"); bill.Name = "CH_TreeBill"; bill.Adornee = hrp; bill.Size = UDim2.new(0, 80, 0, 30); bill.AlwaysOnTop = true; bill.Parent = folder; local txt = Instance.new("TextLabel", bill); txt.Size = UDim2.new(1, 0, 1, 0); txt.BackgroundTransparency = 1; txt.Text = "🌲 Дерево"; txt.TextColor3 = Color3.fromRGB(100, 255, 100); txt.TextStrokeTransparency = 0; txt.TextScaled = true end end; task.wait(1) end end) end})

-- =====================================================================
-- 7. UI: PLAYER TAB
-- =====================================================================
local PlayerTab = Window:CreateTab("🏃 Игрок", "user")
PlayerTab:CreateSection("Движение")
PlayerTab:CreateSlider({Name = "Скорость ходьбы", Range = {16, 300}, CurrentValue = 50, Callback = function(v) State.SpeedValue = v; if State.SpeedEnabled and Player.Character then local hum = Player.Character:FindFirstChildOfClass("Humanoid"); if hum then hum.WalkSpeed = v end end end})
PlayerTab:CreateToggle({Name = "Включить высокую скорость", CurrentValue = false, Callback = function(v) State.SpeedEnabled = v; if Player.Character then local hum = Player.Character:FindFirstChildOfClass("Humanoid"); if hum then hum.WalkSpeed = v and State.SpeedValue or 16 end end end})

PlayerTab:CreateSection("Телепорт")
PlayerTab:CreateToggle({Name = "Плавный телепорт (Анимация)", CurrentValue = true, Callback = function(v) State.SmoothTeleport = v end})
PlayerTab:CreateButton({Name = "📍 Телепорт к ближайшему клиенту", Callback = function() local custs = refreshCustomerCache(); if #custs > 0 then local hrp = custs[1]:FindFirstChild("HumanoidRootPart"); if hrp then teleportTo(hrp.Position) end else Rayfield:Notify({Title = "Ошибка", Content = "Клиенты не найдены", Duration = 3, Image = "alert-circle"}) end end})

PlayerTab:CreateSection("Noclip & Fly")
PlayerTab:CreateToggle({Name = "Режим Noclip (сквозь стены)", CurrentValue = false, Callback = function(v) State.NoclipEnabled = v end})
PlayerTab:CreateToggle({Name = "Полет (WASD + E/Q)", CurrentValue = false, Callback = function(v) State.FlyEnabled = v; if not v then local hrp = getHRP(); if hrp then local bv = hrp:FindFirstChild("CH_Fly"); if bv then bv:Destroy() end end end end})

RunService.Heartbeat:Connect(function()
   if State.FlyEnabled then local hrp = getHRP(); if hrp then local bv = hrp:FindFirstChild("CH_Fly"); if not bv then bv = Instance.new("BodyVelocity"); bv.Name = "CH_Fly"; bv.MaxForce = Vector3.new(1e5, 1e5, 1e5); bv.Velocity = Vector3.zero; bv.Parent = hrp end; local move = Vector3.zero; if UserInputService:IsKeyDown(Enum.KeyCode.E) then move += Vector3.new(0, 1, 0) end; if UserInputService:IsKeyDown(Enum.KeyCode.Q) then move -= Vector3.new(0, 1, 0) end; local cam = workspace.CurrentCamera; local look = cam.CFrame.LookVector; if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += look end; if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= look end; if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= cam.CFrame.RightVector end; if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += cam.CFrame.RightVector end; bv.Velocity = move * 50 end end
   if State.NoclipEnabled and Player.Character then for _, p in ipairs(Player.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
end)

-- =====================================================================
-- 8. UI: MISC TAB (Codes)
-- =====================================================================
local MiscTab = Window:CreateTab("🎁 Промокоды", "gift")
MiscTab:CreateSection("Активные коды")
local ActiveCodes = {"MISTLETOE", "SNOWBALL", "HOHOHO", "IMBROKE", "BUDDYTHEELF", "JINGLEBELLS", "NICELIST", "OGTICKET", "YETI", "BLITZ"}

MiscTab:CreateButton({
   Name = "🚀 Ввести все коды автоматически",
   Callback = function()
      if not State.Subscribed then Rayfield:Notify({Title = "Закрыто", Content = "Подпишись сначала!", Duration = 4, Image = "lock"}); return end
      Rayfield:Notify({Title = "Запуск", Content = "Пытаемся ввести коды...", Duration = 3, Image = "loader"})
      task.spawn(function()
         local r = findRemoteDeep("code", {"RedeemCode", "Code", "PromoCode", "Redeem"})
         if r then
            for _, code in ipairs(ActiveCodes) do
               r:FireServer(code)
               task.wait(0.5)
            end
            Rayfield:Notify({Title = "Готово", Content = "Все коды отправлены на сервер!", Duration = 5, Image = "check-circle"})
         else
            copyToClipboard(table.concat(ActiveCodes, "\n"))
            Rayfield:Notify({Title = "Скопировано", Content = "Кнопка не найдена. Коды в буфере обмена.", Duration = 6, Image = "clipboard"})
         end
      end)
   end
})

MiscTab:CreateSection("Анти-АФК")
MiscTab:CreateToggle({Name = "Защита от кика за неактивность", CurrentValue = true, Callback = function(v) State.AntiAFK = v end})
Player.Idled:Connect(function() if State.AntiAFK then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end end)

-- =====================================================================
-- 9. STARTUP
-- =====================================================================
Rayfield:LoadConfiguration()
task.wait(0.5)
Rayfield:Notify({Title = "CheatHub Premium", Content = "Успешно загружен. Приятной игры!", Duration = 7, Image = "star"})