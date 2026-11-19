-- CheatHub v2 — Run a Christmas Tree Lot
-- Delta + Xeno Compatibility Edition
-- by dj

local TELEGRAM_URL = "https://t.me/my_christmas_market"

-- =====================================================================
-- 0. EXECUTOR COMPATIBILITY LAYER
-- =====================================================================
local Executor = {
   Name = "Unknown",
   IsDelta = false,
   IsXeno = false,
   HasFirePrompt = false,
   HasFireClick = false,
   HasClipboard = false,
   RequestFn = nil,
}

local function detectExecutor()
   local name = "Unknown"
   if type(identifyexecutor) == "function" then
      local ok, n = pcall(identifyexecutor)
      if ok and n then name = tostring(n) end
   elseif type(getexecutorname) == "function" then
      local ok, n = pcall(getexecutorname)
      if ok and n then name = tostring(n) end
   end
   local l = name:lower()
   Executor.Name = name
   Executor.IsDelta = l:find("delta") ~= nil
   Executor.IsXeno = l:find("xeno") ~= nil
   print(("[CheatHub] Executor: %s | Delta=%s | Xeno=%s"):format(name, tostring(Executor.IsDelta), tostring(Executor.IsXeno)))
end
detectExecutor()

Executor.HasFirePrompt = type(fireproximityprompt) == "function"
Executor.HasFireClick = type(fireclickdetector) == "function"
Executor.HasClipboard = type(setclipboard) == "function"

local function resolveRequest()
   local candidates = {
      {name = "syn.request", fn = syn and syn.request},
      {name = "http_request", fn = http_request},
      {name = "request", fn = request},
      {name = "http.request", fn = http and http.request},
   }
   for _, c in ipairs(candidates) do
      if type(c.fn) == "function" then
         Executor.RequestFn = c.fn
         print("[CheatHub] HTTP: " .. c.name)
         return
      end
   end
   print("[CheatHub] HTTP request не найден.")
end
resolveRequest()

-- Универсальный вызов ProximityPrompt (Xeno fix)
local function firePrompt(prompt)
   if not prompt then return false end

   -- Xeno: fireproximityprompt сломан → InputHoldBegin/End
   if Executor.IsXeno or not Executor.HasFirePrompt then
      local ok = pcall(function()
         prompt:InputHoldBegin()
         task.wait(math.max(prompt.HoldDuration or 0.1, 0.1) + 0.05)
         prompt:InputHoldEnd()
      end)
      if ok then return true end
   end

   if Executor.HasFirePrompt then
      local ok = pcall(function() fireproximityprompt(prompt, 0) end)
      if ok then return true end
   end

   -- Последний fallback — всё равно пробуем InputHold
   return pcall(function()
      prompt:InputHoldBegin()
      task.wait(0.1)
      prompt:InputHoldEnd()
   end)
end

-- Универсальный ClickDetector
local function fireClick(cd)
   if not cd then return false end
   if Executor.HasFireClick then
      local ok = pcall(function() fireclickdetector(cd) end)
      if ok then return true end
   end
   return pcall(function() cd:FireClickDetector() end)
end

-- Универсальный setclipboard
local function copyToClipboard(text)
   if type(setclipboard) == "function" then
      local ok = pcall(setclipboard, text)
      if ok then return true end
   end
   if type(toclipboard) == "function" then
      local ok = pcall(toclipboard, text)
      if ok then return true end
   end
   -- Старые/урезанные исполнители — пишем в консоль
   print("[CheatHub] Clipboard недоступен. Текст:")
   print(text)
   return false
end

-- Универсальный HTTP
local function httpGet(url)
   if not Executor.RequestFn then return false end
   return pcall(function()
      Executor.RequestFn({Url = url, Method = "GET"})
   end)
end

-- =====================================================================
-- 1. UI LIBRARY
-- =====================================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "CheatHub",
   LoadingTitle = "CheatHub v2",
   LoadingSubtitle = "Delta + Xeno Edition",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "CheatHub",
      FileName = "ChristmasTreeLot_v2"
   },
   KeySystem = false
})

-- =====================================================================
-- 2. SERVICES & STATE
-- =====================================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local Player = Players.LocalPlayer

local State = {
   Subscribed = false,
   AutoFarm = false,
   AutoOrder = false,
   AutoPlace = false,
   AutoSell = false,
   AutoUpgrade = false,
   AutoHire = false,
   SpeedEnabled = false,
   FlyEnabled = false,
   NoclipEnabled = false,
   ESPEnabled = false,
   AntiAFK = true,
   PerfMode = "Medium",
   SpeedValue = 50,
   SellDelay = 1.0,
   OrderDelay = 2.0,
   PlaceDelay = 1.5,
   SelectedTreeTypes = {},
   TreeCache = {},
   CustomerCache = {},
   RemoteCache = {},
   SessionStart = os.clock(),
   TotalOrders = 0,
   TotalSales = 0,
   TotalPlaced = 0,
   LastError = "",
}

local function log(msg)
   print(("[CheatHub] %s"):format(tostring(msg)))
end

local function waitMode()
   local d = State.PerfMode == "Turbo" and 0.05
      or State.PerfMode == "Fast" and 0.1
      or 0.25
   task.wait(d)
end

-- =====================================================================
-- 3. GENERIC UTILS
-- =====================================================================
local function safeCall(fn, ...)
   local ok, err = pcall(fn, ...)
   if not ok then
      State.LastError = tostring(err)
      log("Error: " .. State.LastError)
   end
   return ok
end

local function getHRP()
   local char = Player.Character
   if not char then return nil end
   return char:FindFirstChild("HumanoidRootPart")
end

local function teleportTo(pos, offsetY)
   local hrp = getHRP()
   if not hrp then return false end
   local target = pos + Vector3.new(0, offsetY or 5, 0)
   local ok = safeCall(function() hrp.CFrame = CFrame.new(target) end)
   task.wait(0.1)
   return ok
end

local function tweenTo(pos, duration)
   local hrp = getHRP()
   if not hrp then return false end
   local ok = safeCall(function()
      local tween = TweenService:Create(
         hrp,
         TweenInfo.new(duration or 0.4, Enum.EasingStyle.Linear),
         {CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))}
      )
      tween:Play()
      tween.Completed:Wait()
   end)
   return ok
end

-- =====================================================================
-- 4. REMOTE DISCOVERY
-- =====================================================================
local function findRemoteDeep(purpose, candidates, extraParents)
   if State.RemoteCache[purpose] and State.RemoteCache[purpose].Parent then
      return State.RemoteCache[purpose]
   end

   local parents = {RS, WS}
   if extraParents then
      for _, p in ipairs(extraParents) do table.insert(parents, p) end
   end

   for _, parent in ipairs(parents) do
      for _, name in ipairs(candidates) do
         local obj = parent:FindFirstChild(name, true)
         if obj and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent")) then
            State.RemoteCache[purpose] = obj
            log("Remote [" .. purpose .. "] (exact): " .. obj:GetFullName())
            return obj
         end
      end
   end

   local sorted = {}
   for _, c in ipairs(candidates) do table.insert(sorted, c) end
   table.sort(sorted, function(a, b) return #a < #b end)

   for _, parent in ipairs(parents) do
      for _, obj in ipairs(parent:GetDescendants()) do
         if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local n = obj.Name:lower()
            for _, cand in ipairs(sorted) do
               if n:find(cand:lower(), 1, true) then
                  State.RemoteCache[purpose] = obj
                  log("Remote [" .. purpose .. "] (partial): " .. obj:GetFullName())
                  return obj
               end
            end
         end
      end
   end

   log("Remote [" .. purpose .. "] не найден.")
   return nil
end

local function fireRemote(remote, ...)
   if not remote then return false end
   return safeCall(function()
      if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
         remote:FireServer(...)
      elseif remote:IsA("RemoteFunction") then
         remote:InvokeServer(...)
      end
   end)
end

-- =====================================================================
-- 5. OBJECT DISCOVERY
-- =====================================================================
local function scanForKeyword(keywords, classFilter)
   local list = {}
   for _, obj in ipairs(WS:GetDescendants()) do
      if (not classFilter) or obj:IsA(classFilter) then
         local n = obj.Name:lower()
         for _, kw in ipairs(keywords) do
            if n:find(kw, 1, true) then
               table.insert(list, obj)
               break
            end
         end
      end
   end
   return list
end

local function refreshTreeCache()
   local keywords = {"tree", "fir", "pine", "sapin", "ель", "ёлка", "дерево", "noble", "spruce"}
   State.TreeCache = scanForKeyword(keywords, "Model")
   log("Деревья обновлены: " .. #State.TreeCache)
   return State.TreeCache
end

local function refreshCustomerCache()
   local keywords = {"customer", "buyer", "shopper", "client", "покупатель", "клиент", "npc"}
   State.CustomerCache = scanForKeyword(keywords, "Model")
   log("Покупатели обновлены: " .. #State.CustomerCache)
   return State.CustomerCache
end

local function getPrompts(root)
   local prompts = {}
   for _, d in ipairs(root:GetDescendants()) do
      if d:IsA("ProximityPrompt") then table.insert(prompts, d) end
   end
   return prompts
end

local function getClickDetectors(root)
   local cds = {}
   for _, d in ipairs(root:GetDescendants()) do
      if d:IsA("ClickDetector") then table.insert(cds, d) end
   end
   return cds
end

local function tryPrompt(prompt) return firePrompt(prompt) end
local function tryClick(cd) return fireClick(cd) end

-- =====================================================================
-- 6. UI: HOME TAB
-- =====================================================================
local HomeTab = Window:CreateTab("🏠 Главная", nil)

HomeTab:CreateSection("Подписка")

local OkButton

HomeTab:CreateButton({
   Name = "📋 Скопировать ссылку и подписаться",
   Callback = function()
      copyToClipboard(TELEGRAM_URL)
      httpGet(TELEGRAM_URL)
      Rayfield:Notify({Title = "Ссылка скопирована", Content = "Открой Telegram и подпишись на канал.", Duration = 5})
      task.wait(5)
      State.Subscribed = true
      if OkButton then OkButton:Set({Name = "✅ Ok — доступ открыт"}) end
   end
})

OkButton = HomeTab:CreateButton({
   Name = "⛔ Сначала подпишись!",
   Callback = function()
      if not State.Subscribed then
         Rayfield:Notify({Title = "Доступ закрыт", Content = "Сначала скопируй ссылку и подпишись.", Duration = 4})
      else
         Rayfield:Notify({Title = "Доступ открыт", Content = "CheatHub v2 готов к работе.", Duration = 3})
      end
   end
})

HomeTab:CreateSection("Информация")
HomeTab:CreateLabel("Executor: " .. Executor.Name)
HomeTab:CreateLabel("Xeno: " .. tostring(Executor.IsXeno) .. " | Delta: " .. tostring(Executor.IsDelta))

HomeTab:CreateSection("Статистика сессии")
local StatsLabel = HomeTab:CreateLabel("Сессия: 0 мин | Заказов: 0 | Продаж: 0 | Размещено: 0")

task.spawn(function()
   while true do
      task.wait(2)
      local mins = math.floor((os.clock() - State.SessionStart) / 60)
      StatsLabel:Set(("Сессия: %d мин | Заказов: %d | Продаж: %d | Размещено: %d"):format(
         mins, State.TotalOrders, State.TotalSales, State.TotalPlaced))
   end
end)

-- =====================================================================
-- 7. UI: FARM TAB
-- =====================================================================
local FarmTab = Window:CreateTab("🌲 Автофарм", nil)

FarmTab:CreateSection("Производительность")
FarmTab:CreateDropdown({
   Name = "Режим",
   Options = {"Turbo (макс. скорость)", "Fast (мощные устройства)", "Medium (обычные устройства)"},
   CurrentOption = {"Medium (обычные устройства)"},
   Flag = "PerfMode",
   Callback = function(opt)
      local s = opt[1]
      if s:find("Turbo") then State.PerfMode = "Turbo"
      elseif s:find("Fast") then State.PerfMode = "Fast"
      else State.PerfMode = "Medium" end
      Rayfield:Notify({Title = "Режим", Content = State.PerfMode, Duration = 3})
   end
})

FarmTab:CreateSection("Выбор деревьев для заказа")
local TreeTypes = {"Pine", "Fir", "Spruce", "Noble", "Douglas", "Fraser", "Balsam", "Giant"}
for _, tt in ipairs(TreeTypes) do
   FarmTab:CreateToggle({
      Name = "Заказывать: " .. tt,
      CurrentValue = false,
      Flag = "TreeType_" .. tt,
      Callback = function(v)
         if v then State.SelectedTreeTypes[tt] = true
         else State.SelectedTreeTypes[tt] = nil end
      end
   })
end

FarmTab:CreateSection("Авто-заказ")
FarmTab:CreateSlider({
   Name = "Задержка заказа (сек)", Range = {0.5, 10}, Increment = 0.5, Suffix = " с", CurrentValue = 2.0, Flag = "OrderDelay",
   Callback = function(v) State.OrderDelay = v end
})

FarmTab:CreateToggle({
   Name = "Авто-заказ (каскад)",
   CurrentValue = false,
   Flag = "AutoOrder",
   Callback = function(v)
      State.AutoOrder = v
      if not v then return end
      task.spawn(function()
         while State.AutoOrder do
            if State.Subscribed then
               local remote = findRemoteDeep("order", {
                  "OrderTree", "Order", "BuyTree", "PurchaseTree", "StockTree",
                  "Restock", "TreeOrder", "OrderStock", "BuyStock", "RequestTree",
                  "OrderRequest", "Purchase", "Buy"
               })
               if remote then
                  local types = {}
                  for tt, _ in pairs(State.SelectedTreeTypes) do table.insert(types, tt) end
                  if #types == 0 then types = {"Pine"} end
                  for _, tt in ipairs(types) do
                     fireRemote(remote, tt)
                     task.wait(0.1)
                  end
                  State.TotalOrders = State.TotalOrders + 1
               else
                  for _, obj in ipairs(Player.PlayerGui:GetDescendants()) do
                     if obj:IsA("TextButton") and (obj.Text:lower():find("order") or obj.Text:lower():find("buy")) then
                        safeCall(function() obj:Activate() end)
                        break
                     end
                  end
               end
            end
            task.wait(State.OrderDelay)
         end
      end)
   end
})

FarmTab:CreateSection("Авто-расстановка")
FarmTab:CreateSlider({
   Name = "Задержка расстановки (сек)", Range = {0.5, 10}, Increment = 0.5, Suffix = " с", CurrentValue = 1.5, Flag = "PlaceDelay",
   Callback = function(v) State.PlaceDelay = v end
})

FarmTab:CreateToggle({
   Name = "Авто-расстановка (каскад)",
   CurrentValue = false,
   Flag = "AutoPlace",
   Callback = function(v)
      State.AutoPlace = v
      if not v then return end
      task.spawn(function()
         while State.AutoPlace do
            if State.Subscribed then
               local remote = findRemoteDeep("place", {
                  "PlaceTree", "Place", "Stock", "SetTree", "PutTree",
                  "PlaceRequest", "StockRequest", "PlaceItem", "PlantTree",
                  "PositionTree", "SetPosition"
               })
               if remote then
                  fireRemote(remote)
                  State.TotalPlaced = State.TotalPlaced + 1
               else
                  local trees = refreshTreeCache()
                  local done = false
                  for _, tree in ipairs(trees) do
                     for _, p in ipairs(getPrompts(tree)) do
                        if tryPrompt(p) then
                           State.TotalPlaced = State.TotalPlaced + 1
                           done = true
                           break
                        end
                     end
                     if done then break end
                  end
               end
            end
            task.wait(State.PlaceDelay)
         end
      end)
   end
})

FarmTab:CreateSection("Авто-продажа")
FarmTab:CreateSlider({
   Name = "Задержка продажи (сек)", Range = {0.3, 5}, Increment = 0.1, Suffix = " с", CurrentValue = 1.0, Flag = "SellDelay",
   Callback = function(v) State.SellDelay = v end
})

FarmTab:CreateToggle({
   Name = "Авто-продажа (каскад)",
   CurrentValue = false,
   Flag = "AutoSell",
   Callback = function(v)
      State.AutoSell = v
      if not v then return end
      task.spawn(function()
         while State.AutoSell do
            if State.Subscribed then
               local remote = findRemoteDeep("sell", {
                  "SellTree", "Sell", "SellRequest", "CompleteSale", "Purchase",
                  "BuyFromPlayer", "Sale", "Checkout", "CompletePurchase",
                  "Transaction", "Pay"
               })
               if remote then
                  fireRemote(remote)
                  State.TotalSales = State.TotalSales + 1
               else
                  local customers = refreshCustomerCache()
                  for _, cust in ipairs(customers) do
                     local hrp = cust:FindFirstChild("HumanoidRootPart")
                     if hrp then
                        tweenTo(hrp.Position, 0.2)
                        local done = false
                        for _, p in ipairs(getPrompts(cust)) do
                           if tryPrompt(p) then done = true; break end
                        end
                        if not done then
                           for _, cd in ipairs(getClickDetectors(cust)) do
                              if tryClick(cd) then done = true; break end
                           end
                        end
                        if done then
                           State.TotalSales = State.TotalSales + 1
                           break
                        end
                     end
                  end
               end
            end
            task.wait(State.SellDelay)
         end
      end)
   end
})

FarmTab:CreateSection("Полный цикл")
FarmTab:CreateToggle({
   Name = "Автофарм (заказ → расстановка → продажа)",
   CurrentValue = false,
   Flag = "AutoFarm",
   Callback = function(v)
      State.AutoFarm = v
      State.AutoOrder = v
      State.AutoPlace = v
      State.AutoSell = v
      Rayfield:Notify({Title = "Автофарм", Content = v and "Включён" or "Выключен", Duration = 3})
   end
})

-- =====================================================================
-- 8. UI: PLAYER TAB
-- =====================================================================
local PlayerTab = Window:CreateTab("🏃 Игрок", nil)

PlayerTab:CreateSection("Движение")
PlayerTab:CreateSlider({
   Name = "Скорость", Range = {16, 500}, Increment = 1, Suffix = " studs/s", CurrentValue = 50, Flag = "SpeedValue",
   Callback = function(v)
      State.SpeedValue = v
      if State.SpeedEnabled and Player.Character then
         local hum = Player.Character:FindFirstChildOfClass("Humanoid")
         if hum then hum.WalkSpeed = v end
      end
   end
})

PlayerTab:CreateToggle({
   Name = "Включить скорость",
   CurrentValue = false,
   Flag = "SpeedToggle",
   Callback = function(v)
      State.SpeedEnabled = v
      if Player.Character then
         local hum = Player.Character:FindFirstChildOfClass("Humanoid")
         if hum then hum.WalkSpeed = v and State.SpeedValue or 16 end
      end
   end
})

PlayerTab:CreateSection("Полёт")
PlayerTab:CreateToggle({
   Name = "Fly (WASD + E/Q)",
   CurrentValue = false,
   Flag = "FlyToggle",
   Callback = function(v)
      State.FlyEnabled = v
      if not v then
         local hrp = getHRP()
         if hrp then
            local bv = hrp:FindFirstChild("CheatHubFly")
            if bv then bv:Destroy() end
         end
      end
   end
})

PlayerTab:CreateSection("Noclip")
PlayerTab:CreateToggle({
   Name = "Noclip",
   CurrentValue = false,
   Flag = "NoclipToggle",
   Callback = function(v)
      State.NoclipEnabled = v
      if not v and Player.Character then
         for _, part in ipairs(Player.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
         end
      end
   end
})

RunService.Heartbeat:Connect(function()
   if State.FlyEnabled then
      local hrp = getHRP()
      if hrp then
         local bv = hrp:FindFirstChild("CheatHubFly")
         if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "CheatHubFly"
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Velocity = Vector3.zero
            bv.Parent = hrp
         end
         local move = Vector3.zero
         if UserInputService:IsKeyDown(Enum.KeyCode.E) then move = move + Vector3.new(0, 1, 0) end
         if UserInputService:IsKeyDown(Enum.KeyCode.Q) then move = move - Vector3.new(0, 1, 0) end
         local cam = workspace.CurrentCamera
         local look = cam.CFrame.LookVector
         if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + look end
         if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - look end
         if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
         if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
         bv.Velocity = move * 50
      end
   end

   if State.NoclipEnabled and Player.Character then
      for _, part in ipairs(Player.Character:GetDescendants()) do
         if part:IsA("BasePart") then part.CanCollide = false end
      end
   end
end)

-- =====================================================================
-- 9. UI: MISC TAB
-- =====================================================================
local MiscTab = Window:CreateTab("⚙️ Разное", nil)

MiscTab:CreateSection("Промокоды (актуальные)")

-- ОБНОВЛЕННЫЙ СПИСОК КОДОВ С ВАШЕГО СКРИНШОТА
local ActiveCodes = {
   "MISTLETOE", "SNOWBALL", "HOHOHO", "IMBROKE", 
   "BUDDYTHEELF", "JINGLEBELLS", "NICELIST", "OGTICKET", 
   "YETI", "BLITZ"
}
local ExpiredCodes = {"CHRISTMAS", "SANTA250", "SANTASGIFT", "KRAMPUS!"}

MiscTab:CreateButton({
   Name = "🎁 Ввести активные промокоды (каскад)",
   Callback = function()
      if not State.Subscribed then
         Rayfield:Notify({Title = "Доступ закрыт", Content = "Сначала подпишись.", Duration = 4})
         return
      end
      task.spawn(function()
         local remote = findRemoteDeep("code", {
            "RedeemCode", "Code", "PromoCode", "Redeem", "Promocode",
            "CodeRequest", "RedeemRequest", "EnterCode", "ActivateCode",
            "ClaimCode", "UseCode"
         })
         if remote then
            for _, code in ipairs(ActiveCodes) do
               fireRemote(remote, code)
               task.wait(0.4)
            end
            Rayfield:Notify({Title = "Промокоды", Content = "Ввод через remote завершён.", Duration = 5})
            return
         end
         local textBox, btn
         for _, obj in ipairs(Player.PlayerGui:GetDescendants()) do
            if obj:IsA("TextBox") and (obj.Name:lower():find("code") or (obj.PlaceholderText and obj.PlaceholderText:lower():find("code"))) then
               textBox = obj
            end
            if obj:IsA("TextButton") and (obj.Text:lower():find("redeem") or obj.Text:lower():find("submit")) then
               btn = obj
            end
         end
         if textBox and btn then
            for _, code in ipairs(ActiveCodes) do
               safeCall(function()
                  textBox.Text = code
                  task.wait(0.1)
                  btn:Activate()
               end)
               task.wait(0.4)
            end
            Rayfield:Notify({Title = "Промокоды", Content = "Ввод через UI завершён.", Duration = 5})
            return
         end
         copyToClipboard(table.concat(ActiveCodes, "\n"))
         Rayfield:Notify({Title = "Коды скопированы", Content = "Авто-ввод не найден. Вставь коды вручную.", Duration = 8})
      end)
   end
})

MiscTab:CreateButton({
   Name = "Скопировать просроченные коды",
   Callback = function()
      copyToClipboard(table.concat(ExpiredCodes, "\n"))
      Rayfield:Notify({Title = "Просроченные коды", Content = "Скопированы в буфер.", Duration = 6})
   end
})

MiscTab:CreateSection("ESP")
MiscTab:CreateToggle({
   Name = "ESP покупателей",
   CurrentValue = false,
   Flag = "ESP",
   Callback = function(v)
      State.ESPEnabled = v
      if not v then
         local existing = Player.PlayerGui:FindFirstChild("CheatHubESP")
         if existing then existing:Destroy() end
         return
      end
      local espFolder = Player.PlayerGui:FindFirstChild("CheatHubESP")
      if not espFolder then
         espFolder = Instance.new("Folder")
         espFolder.Name = "CheatHubESP"
         espFolder.Parent = Player.PlayerGui
      end
      task.spawn(function()
         while State.ESPEnabled do
            for _, cust in ipairs(refreshCustomerCache()) do
               local hrp = cust:FindFirstChild("HumanoidRootPart")
               if hrp and not hrp:FindFirstChild("CheatHubBillboard") then
                  local bill = Instance.new("BillboardGui")
                  bill.Name = "CheatHubBillboard"
                  bill.Adornee = hrp
                  bill.Size = UDim2.new(0, 100, 0, 30)
                  bill.AlwaysOnTop = true
                  bill.Parent = espFolder
                  local text = Instance.new("TextLabel", bill)
                  text.Size = UDim2.new(1, 0, 1, 0)
                  text.BackgroundTransparency = 1
                  text.Text = "Customer"
                  text.TextColor3 = Color3.new(1, 0, 0)
                  text.TextScaled = true
               end
            end
            task.wait(1)
         end
      end)
   end
})

MiscTab:CreateSection("Анти-АФК")
MiscTab:CreateToggle({
   Name = "Анти-АФК",
   CurrentValue = true,
   Flag = "AntiAFK",
   Callback = function(v) State.AntiAFK = v end
})

Player.Idled:Connect(function()
   if State.AntiAFK then
      VirtualUser:CaptureController()
      VirtualUser:ClickButton2(Vector2.new())
   end
end)

-- =====================================================================
-- 10. UI: BUSINESS TAB
-- =====================================================================
local ExtraTab = Window:CreateTab("💼 Бизнес", nil)

ExtraTab:CreateSection("Авто-улучшения")
ExtraTab:CreateToggle({
   Name = "Авто-покупка улучшений (каскад)",
   CurrentValue = false,
   Flag = "AutoUpgrade",
   Callback = function(v)
      State.AutoUpgrade = v
      if not v then return end
      task.spawn(function()
         while State.AutoUpgrade do
            if State.Subscribed then
               local remote = findRemoteDeep("upgrade", {
                  "Upgrade", "UpgradeLot", "BuyUpgrade", "UpgradeRequest",
                  "Improve", "Enhance", "LevelUp"
               })
               if remote then
                  fireRemote(remote)
               else
                  for _, obj in ipairs(Player.PlayerGui:GetDescendants()) do
                     if obj:IsA("TextButton") and obj.Text:lower():find("upgrade") then
                        safeCall(function() obj:Activate() end)
                        break
                     end
                  end
               end
            end
            task.wait(5)
         end
      end)
   end
})

ExtraTab:CreateSection("Авто-найм")
ExtraTab:CreateToggle({
   Name = "Авто-найм работников (каскад)",
   CurrentValue = false,
   Flag = "AutoHire",
   Callback = function(v)
      State.AutoHire = v
      if not v then return end
      task.spawn(function()
         while State.AutoHire do
            if State.Subscribed then
               local remote = findRemoteDeep("hire", {
                  "Hire", "HireWorker", "Recruit", "HireEmployee",
                  "WorkerHire", "EmployeeHire", "RecruitWorker"
               })
               if remote then
                  fireRemote(remote)
               else
                  for _, obj in ipairs(Player.PlayerGui:GetDescendants()) do
                     if obj:IsA("TextButton") and obj.Text:lower():find("hire") then
                        safeCall(function() obj:Activate() end)
                        break
                     end
                  end
               end
            end
            task.wait(8)
         end
      end)
   end
})

-- =====================================================================
-- 11. STARTUP
-- =====================================================================
Rayfield:LoadConfiguration()

Rayfield:Notify({
   Title = "CheatHub v2 загружен",
   Content = "Кодов в базе: " .. #ActiveCodes .. ". Сначала подпишись, затем нажми Ok.",
   Duration = 8
})

log("CheatHub v2 инициализирован.")
log(("Совместимость: Prompt=%s, Click=%s, Clipboard=%s, HTTP=%s"):format(
   tostring(Executor.HasFirePrompt or Executor.IsXeno),
   tostring(Executor.HasFireClick),
   tostring(Executor.HasClipboard),
   tostring(Executor.RequestFn ~= nil)
))