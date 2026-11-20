-- CheatHub v9 — Winter Magic Edition
-- Run a Christmas Tree Lot
-- by dj

-- =====================================================================
-- 0. CONFIG (правь здесь)
-- =====================================================================
local CONFIG = {
   TelegramUrl = "https://t.me/my_christmas_market",
   ReloadUrl = "",      -- ссылка на этот скрипт (для loadstring): после рейджойна он запустится сам
   Debug = false,       -- true = подробный вывод в консоль
   CacheTTL = 10,       -- сколько секунд помнить результаты поиска

   -- Окно «Подпишитесь на канал»
   Popup = {
      Enabled = true,
      FirstDelay = 90,            -- через сколько секунд после запуска появится впервые
      IntervalAfterClose = 600,   -- повтор после нажатия ✕ (сек)
      IntervalAfterOk = 1800,     -- повтор после нажатия OK (сек)
      Title = "📢 Подпишитесь на канал",
      Text = "Новые скрипты, обновления и свежие коды — в нашем Telegram-канале.",
   },
}

-- Защита от двойного запуска
local env = (type(getgenv) == "function" and getgenv()) or _G
if env.CheatHubWinter and env.CheatHubWinter.Unload then
   pcall(env.CheatHubWinter.Unload)
end

-- =====================================================================
-- 1. SERVICES & UTILS
-- =====================================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Player = Players.LocalPlayer

local Connections = {}

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

local function fmtNum(n)
   n = tonumber(n)
   if not n then return "—" end
   local a = math.abs(n)
   if a >= 1e12 then return ("%.2fT"):format(n / 1e12) end
   if a >= 1e9 then return ("%.2fB"):format(n / 1e9) end
   if a >= 1e6 then return ("%.2fM"):format(n / 1e6) end
   if a >= 1e3 then return ("%.1fK"):format(n / 1e3) end
   return tostring(math.floor(n))
end

local function fmtTime(sec)
   sec = math.max(0, math.floor(sec))
   return ("%02d:%02d:%02d"):format(math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60)
end

local function new(class, props, parent)
   local o = Instance.new(class)
   for k, v in pairs(props) do o[k] = v end
   if parent then o.Parent = parent end
   return o
end

local function makeScreenGui(name, order)
   local gui = Instance.new("ScreenGui")
   gui.Name = name
   gui.ResetOnSpawn = false
   gui.IgnoreGuiInset = true
   gui.DisplayOrder = order or 100
   gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
   local placed = false
   if type(gethui) == "function" then
      placed = pcall(function() gui.Parent = gethui() end)
   end
   if not placed or not gui.Parent then
      placed = pcall(function() gui.Parent = game:GetService("CoreGui") end)
   end
   if not placed or not gui.Parent then
      gui.Parent = Player:WaitForChild("PlayerGui")
   end
   return gui
end

local function getHRP()
   local c = Player.Character
   return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
   local c = Player.Character
   return c and c:FindFirstChildOfClass("Humanoid")
end

-- Кэш поиска (важно: GetDescendants() по всему миру — дорогая операция)
local Cache = {}
local function cached(key, finder, ttl)
   local e = Cache[key]
   if e and (os.clock() - e.t) < (ttl or CONFIG.CacheTTL) then
      local v = e.v
      if v == nil or typeof(v) ~= "Instance" or v.Parent then return v end
   end
   local v = finder()
   Cache[key] = { v = v, t = os.clock() }
   return v
end

local function invalidateCache()
   Cache = {}
end

-- =====================================================================
-- 2. COLORS, THEME, STATE
-- =====================================================================
local ACCENT = Color3.fromRGB(220, 40, 40)
local GREEN = Color3.fromRGB(70, 190, 110)
local YELLOW = Color3.fromRGB(240, 190, 60)
local RED = Color3.fromRGB(230, 70, 70)
local GRAY = Color3.fromRGB(120, 130, 140)

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

local TreeNames = { "Pine", "Fir", "Spruce", "Noble", "Fraser", "Balsam" }

local State = {
   Running = true,
   AutoFarm = false,
   AutoOrder = true, AutoServe = true, AutoHire = true, AutoUpgrade = true,
   AutoCollect = true, AutoReward = true, AutoDecor = false,
   SelectedTree = "Pine",
   CycleDelay = 1.0, SlowInterval = 15, Humanize = true,
   CollectKW = { "money", "coin", "gift", "snowflake" },
   CollectRadius = 150,
   CashName = "", RepName = "",
   AntiAFK = true, AutoRejoin = false, VoidGuard = true, SmoothTeleport = true,
   SpeedEnabled = false, SpeedValue = 50,
   AfkSaver = false,
   ThemeName = "Winter",
   Status = "Ожидание",
   SessionStart = os.clock(),
   FarmStart = nil, FarmStartCash = nil,
   WatchCash = nil, WatchAt = 0,
   TotalActions = 0, FarmActions = 0, DecorActions = 0, LastSuccess = 0,
   SafePos = nil,
   BindTarget = "order", TestTarget = "order", SpyPick = "",
}

-- Действия: remote-имена / модели / тексты кнопок (имена угаданы — проверяй во вкладке «Диагностика»)
local ActionOrder = { "order", "sell", "checkout", "hire", "upgrade", "buyDecor", "placeDecor", "reward" }
local Actions = {
   order = { label = "Заказ деревьев", remotes = { "OrderTree", "BuyTree", "Order", "Supply" }, models = { "truck", "supply", "delivery" }, ui = { "order", "buy", "purchase" } },
   sell = { label = "Продажа клиенту", remotes = { "SellTree", "LoadTree", "Sell" }, models = { "customer", "buyer" }, ui = { "sell", "load", "give" } },
   checkout = { label = "Касса", remotes = { "Checkout", "CompleteSale", "Pay" }, models = { "cashier", "register" }, ui = { "pay", "checkout", "confirm" } },
   hire = { label = "Найм работников", remotes = { "Hire" }, models = { "worker", "employee" }, ui = { "hire" } },
   upgrade = { label = "Апгрейд лота", remotes = { "Upgrade" }, models = { "upgrade" }, ui = { "upgrade" } },
   buyDecor = { label = "Покупка декора", remotes = { "BuyDecor", "PurchaseItem", "Buy" }, models = { "decor", "build", "shop" }, ui = { "buy", "purchase", "snow", "light", "fence" } },
   placeDecor = { label = "Установка декора", remotes = { "PlaceDecor", "PlaceItem", "Build" }, models = { "foundation", "plot", "base" }, ui = { "place", "build", "confirm" } },
   reward = { label = "Награды", remotes = { "ClaimReward", "ClaimDaily", "Daily", "ClaimGift", "Claim" }, models = { "reward", "gift" }, ui = { "claim", "collect" } },
}
local ActionLabels, LabelToKey = {}, {}
for _, k in ipairs(ActionOrder) do
   ActionLabels[#ActionLabels + 1] = Actions[k].label
   LabelToKey[Actions[k].label] = k
end

-- Ручные привязки: Binds[ключ] = { remote = "Имя или Путь", args = "a, b, {tree}" }
local Binds = {}
for _, k in ipairs(ActionOrder) do Binds[k] = { remote = "", args = "" } end

-- Промокоды (регистр важен!). Часть могла устареть.
local ActiveCodes = {
   "CHRISTMAS", "SANTA250", "KRAMPUS!", "OGTICKET", "BLITZ", "MISTLETOE", "SNOWBALL",
   "HOHOHO", "IMBROKE", "BUDDYTHEELF", "JINGLEBELLS", "NICELIST", "YETI",
}

-- =====================================================================
-- 3. EXECUTOR COMPATIBILITY
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
               fired = fired + 1
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

local function fireTouch(part)
   local hrp = getHRP()
   if not hrp or type(firetouchinterest) ~= "function" then return false end
   return pcall(function()
      firetouchinterest(hrp, part, 0)
      task.wait()
      firetouchinterest(hrp, part, 1)
   end)
end

-- =====================================================================
-- 4. RAYFIELD, NOTIFY, WINDOW
-- =====================================================================
local okLoad, Rayfield = pcall(function()
   return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not okLoad or not Rayfield then
   warn("[CheatHub] Rayfield не загрузился: " .. tostring(Rayfield))
   return
end

local lastNotify = {}
local function notify(title, content, duration, key, cooldown)
   key = key or title
   local now = os.clock()
   if lastNotify[key] and now - lastNotify[key] < (cooldown or 2) then return end
   lastNotify[key] = now
   pcall(function()
      Rayfield:Notify({ Title = title, Content = content, Duration = duration or 4 })
   end)
end

local function copyLink()
   if type(setclipboard) ~= "function" then return false end
   local ok = pcall(setclipboard, CONFIG.TelegramUrl)
   playSound("6895079853")
   return ok
end

local Window = Rayfield:CreateWindow({
   Name = "❄️ CheatHub | Winter Magic",
   LoadingTitle = "Снежная буря загружается...",
   LoadingSubtitle = "v9",
   Theme = Theme,
   ToggleUIKeybind = "K",
   DisableRayfieldPrompts = true,
   DisableBuildWarnings = true,
   ConfigurationSaving = { Enabled = true, FolderName = "CheatHubWinter", FileName = "Config" },
   KeySystem = false,
})

-- =====================================================================
-- 5. SEARCH ENGINE
-- =====================================================================
local function parseBinding(text)
   text = tostring(text or "")
   local remote, args = text:match("^%s*([^|]-)%s*|%s*(.-)%s*$")
   if not remote then
      remote = text:match("^%s*(.-)%s*$")
      args = ""
   end
   return remote or "", args or ""
end

-- Аргументы: "Pine, 1, true, {tree}, {player}"
local function parseArgs(text)
   local out = { n = 0 }
   text = tostring(text or "")
   if text:match("^%s*$") then return out end
   for token in (text .. ","):gmatch("%s*(.-)%s*,") do
      local v
      local low = token:lower()
      if token == "{tree}" then
         v = State.SelectedTree
      elseif token == "{player}" then
         v = Player
      elseif low == "true" then
         v = true
      elseif low == "false" then
         v = false
      elseif low == "nil" then
         v = nil
      elseif tonumber(token) then
         v = tonumber(token)
      else
         v = token:match('^"(.*)"$') or token:match("^'(.*)'$") or token
      end
      out.n = out.n + 1
      out[out.n] = v
   end
   return out
end

local function isRemote(o)
   return o ~= nil and (o.ClassName == "RemoteEvent" or o.ClassName == "RemoteFunction")
end

local function resolvePath(path)
   local cur = game
   for part in path:gmatch("[^%.]+") do
      cur = cur and cur:FindFirstChild(part)
      if not cur then return nil end
   end
   return cur
end

-- Индекс всех remote (имя в нижнем регистре -> объект)
local function remoteIndex()
   return cached("remoteIndex", function()
      local idx = {}
      for _, root in ipairs({ RS, WS }) do
         for _, o in ipairs(root:GetDescendants()) do
            if isRemote(o) then
               local k = o.Name:lower()
               if not idx[k] then idx[k] = o end
            end
         end
      end
      return idx
   end)
end

local function findRemote(names)
   for _, name in ipairs(names) do
      if name ~= "" then
         if name:find(".", 1, true) then
            local o = resolvePath(name)
            if isRemote(o) then return o end
         end
         local leaf = name:match("([^%.]+)$") or name
         local o = remoteIndex()[leaf:lower()]
         if o and o.Parent then return o end
      end
   end
   return nil
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
                     score = score + 3 -- модели с интерактивом в приоритете
                  end
                  if not bestScore or score > bestScore then
                     best, bestScore = obj, score
                  end
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

local function isOwnGui(obj)
   local sg = obj:FindFirstAncestorWhichIsA("ScreenGui")
   return sg ~= nil and (sg.Name == "Rayfield" or sg.Name:sub(1, 8) == "CheatHub")
end

local function findButton(keywords)
   for _, obj in ipairs(Player.PlayerGui:GetDescendants()) do
      if obj:IsA("TextButton") and obj.Visible and not isOwnGui(obj) then
         local txt = obj.Text:lower()
         for _, kw in ipairs(keywords) do
            if txt:find(kw, 1, true) then return obj end
         end
      end
   end
   return nil
end

local function teleportTo(pos)
   local hrp = getHRP()
   if not hrp or not pos then return false end
   local target = pos + Vector3.new(0, 3, 0)
   local dist = (hrp.Position - target).Magnitude
   if dist < 6 then return true end
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
-- 6. ACTION ENGINE: привязка -> Remote -> Prompt/Click -> UI
-- =====================================================================
local lastUiScan = {}

local function markSuccess()
   State.LastSuccess = os.clock()
   State.TotalActions = State.TotalActions + 1
   if State.AutoFarm then State.FarmActions = State.FarmActions + 1 end
end

local function callRemote(r, args)
   args = args or { n = 0 }
   return pcall(function()
      if r.ClassName == "RemoteEvent" then
         r:FireServer(table.unpack(args, 1, args.n))
      else
         r:InvokeServer(table.unpack(args, 1, args.n))
      end
   end)
end

-- Возвращает (успех, как_сработало)
local function runAction(key)
   local spec = Actions[key]
   if not spec then return false, "неизвестное действие" end
   State.Status = spec.label .. ((key == "order") and (": " .. State.SelectedTree) or "")

   local function success(how)
      markSuccess()
      dbg(spec.label, "->", how)
      return true, how
   end

   -- 0) ручная привязка из вкладки «Диагностика»
   local bind = Binds[key]
   if bind and bind.remote ~= "" then
      local br = findRemote({ bind.remote })
      if br and callRemote(br, parseArgs(bind.args)) then
         return success("привязка: " .. br.Name)
      end
   end

   -- 1) Remote по именам
   local r = findRemote(spec.remotes)
   if r then
      local args = { n = 0 }
      if key == "order" then args = { n = 1, State.SelectedTree } end
      if callRemote(r, args) then return success("remote: " .. r.Name) end
   end

   -- 2) ProximityPrompt / ClickDetector
   local model = findModel(spec.models)
   if model then
      teleportTo(modelPosition(model))
      for _, d in ipairs(model:GetDescendants()) do
         if d:IsA("ProximityPrompt") then
            if firePrompt(d) then return success("prompt: " .. d.Parent.Name) end
         elseif d:IsA("ClickDetector") and type(fireclickdetector) == "function" then
            if pcall(fireclickdetector, d) then return success("click: " .. d.Parent.Name) end
         end
      end
   end

   -- 3) UI-кнопки (не чаще раза в 3 сек на действие)
   if (os.clock() - (lastUiScan[key] or 0)) > 3 then
      lastUiScan[key] = os.clock()
      local kws = { table.unpack(spec.ui) }
      if key == "order" then kws[#kws + 1] = State.SelectedTree:lower() end
      local btn = findButton(kws)
      if btn and clickGui(btn) then return success("ui: " .. btn.Text) end
   end

   return false, "не найдено"
end

-- Планировщик: у каждого модуля свой интервал + «человеческий» разброс
local Schedule = {}
local function jitter()
   if State.Humanize then return 0.85 + math.random() * 0.5 end
   return 1
end
local function due(key, interval)
   local now = os.clock()
   if now >= (Schedule[key] or 0) then
      Schedule[key] = now + interval * jitter()
      return true
   end
   return false
end

-- Сбор предметов (деньги / подарки / снежинки) по ключевым словам
local function parseKeywords(text)
   local list = {}
   for w in tostring(text or ""):gmatch("[^,%s]+") do
      list[#list + 1] = w:lower()
   end
   return list
end

local function nameMatches(name, kws)
   local n = name:lower()
   for _, kw in ipairs(kws) do
      if n:find(kw, 1, true) then return true end
   end
   return false
end

local function getCollectibles()
   return cached("collectibles", function()
      local found = {}
      local kws = State.CollectKW
      if #kws == 0 then return found end
      for _, obj in ipairs(WS:GetDescendants()) do
         local kind, part
         if obj:IsA("ProximityPrompt") then
            kind, part = "prompt", obj.Parent
         elseif obj:IsA("ClickDetector") then
            kind, part = "click", obj.Parent
         elseif obj:IsA("BasePart") and obj:FindFirstChild("TouchInterest") then
            kind, part = "touch", obj
         end
         if part and part:IsA("Attachment") then part = part.Parent end
         if kind and part and part:IsA("BasePart") then
            local label = part.Name .. " " .. (part.Parent and part.Parent.Name or "")
            if kind == "prompt" then label = label .. " " .. obj.ObjectText .. " " .. obj.ActionText end
            if nameMatches(label, kws) then
               local model = part:FindFirstAncestorOfClass("Model")
               if not (model and Players:GetPlayerFromCharacter(model)) then
                  found[#found + 1] = { kind = kind, obj = obj, part = part }
               end
            end
         end
      end
      return found
   end, 4)
end

local function doCollect()
   local hrp = getHRP()
   if not hrp then return false end
   local items = getCollectibles()
   if #items == 0 then return false end
   local origin = hrp.Position
   local nearby = {}
   for _, it in ipairs(items) do
      if it.part.Parent then
         local d = (it.part.Position - origin).Magnitude
         if d <= State.CollectRadius then
            nearby[#nearby + 1] = { it = it, d = d }
         end
      end
   end
   table.sort(nearby, function(a, b) return a.d < b.d end)
   if #nearby > 0 then State.Status = "Сбор предметов" end
   local did = false
   for i = 1, math.min(#nearby, 5) do
      local it = nearby[i].it
      if nearby[i].d > 25 then teleportTo(it.part.Position) end
      local ok = false
      if it.kind == "touch" then
         ok = fireTouch(it.part)
      elseif it.kind == "prompt" then
         ok = firePrompt(it.obj)
      elseif type(fireclickdetector) == "function" then
         ok = pcall(fireclickdetector, it.obj)
      end
      if ok then did = true end
   end
   if did then markSuccess() end
   return did
end

local function doDecor()
   local a = runAction("buyDecor")
   task.wait(1)
   local b = runAction("placeDecor")
   if a or b then State.DecorActions = State.DecorActions + 1 end
   return a or b
end

local function farmStep()
   if State.AutoServe and due("serve", State.CycleDelay) then
      runAction("sell")
      task.wait(0.4)
      runAction("checkout")
   end
   if State.AutoOrder and due("order", State.CycleDelay) then runAction("order") end
   if State.AutoCollect and due("collect", 2) then doCollect() end
   if State.AutoHire and due("hire", State.SlowInterval) then runAction("hire") end
   if State.AutoUpgrade and due("upgrade", State.SlowInterval) then runAction("upgrade") end
   if State.AutoReward and due("reward", 60) then runAction("reward") end
end

-- =====================================================================
-- 7. STATS (деньги / репутация)
-- =====================================================================
local STAT_KW = {
   cash = { "cash", "money", "coin", "dollar", "buck", "balance" },
   rep = { "reputation" },
}

local function statMatches(kind, name, override)
   local n = name:lower()
   if override and override ~= "" then return n == override:lower() end
   for _, kw in ipairs(STAT_KW[kind]) do
      if n:find(kw, 1, true) then return true end
   end
   return false
end

local function readStat(kind, override)
   local ref = cached("stat:" .. kind .. ":" .. tostring(override or ""), function()
      for _, root in ipairs({ Player:FindFirstChild("leaderstats"), Player }) do
         if root then
            for _, v in ipairs(root:GetDescendants()) do
               if (v:IsA("IntValue") or v:IsA("NumberValue")) and statMatches(kind, v.Name, override) then
                  return v
               end
            end
         end
      end
      return nil
   end)
   if ref then return ref.Value end
   for name, val in pairs(Player:GetAttributes()) do
      if type(val) == "number" and statMatches(kind, name, override) then return val end
   end
   return nil
end

local function setFarm(v)
   if State.AutoFarm == v then return end
   State.AutoFarm = v
   if v then
      State.FarmStart = os.clock()
      State.FarmStartCash = readStat("cash", State.CashName)
      State.FarmActions = 0
      State.LastSuccess = os.clock()
      State.WatchCash = nil
      playSound("9118823103")
      notify("Автофарм", "Цикл запущен!", 3, "farm")
   else
      State.Status = "Остановлено"
      notify("Автофарм", "Остановлен.", 3, "farm")
   end
end

-- =====================================================================
-- 8. HUD (мини-панель, перетаскивается) и окно «Подпишитесь на канал»
-- =====================================================================
local FarmToggle

local HUD = {}
do
   local gui = makeScreenGui("CheatHubHUD", 50)
   local card = new("Frame", {
      Name = "Card", Size = UDim2.fromOffset(220, 134), Position = UDim2.new(0, 12, 0, 90),
      BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.1, BorderSizePixel = 0,
   }, gui)
   new("UICorner", { CornerRadius = UDim.new(0, 10) }, card)
   new("UIStroke", { Color = ACCENT, Thickness = 1.5, Transparency = 0.2 }, card)

   local bar = new("Frame", { Name = "Bar", Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Theme.Topbar, BorderSizePixel = 0 }, card)
   new("UICorner", { CornerRadius = UDim.new(0, 10) }, bar)
   local dot = new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 10, 0.5, -5), BackgroundColor3 = GRAY, BorderSizePixel = 0 }, bar)
   new("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
   new("TextLabel", {
      Size = UDim2.new(1, -30, 1, 0), Position = UDim2.new(0, 28, 0, 0), BackgroundTransparency = 1,
      Text = "❄️ CheatHub  •  тяни за заголовок", Font = Enum.Font.GothamBold, TextSize = 12,
      TextColor3 = Theme.TextColor, TextXAlignment = Enum.TextXAlignment.Left,
   }, bar)

   local function line(y)
      return new("TextLabel", {
         Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 0, y), BackgroundTransparency = 1,
         Text = "", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Theme.TextColor,
         TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
      }, card)
   end
   local l1, l2, l3, l4 = line(34), line(52), line(70), line(88)

   local btn = new("TextButton", {
      Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 1, -32), BackgroundColor3 = ACCENT,
      Text = "▶ Старт", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
   }, card)
   new("UICorner", { CornerRadius = UDim.new(0, 8) }, btn)

   btn.Activated:Connect(function()
      if FarmToggle then FarmToggle:Set(not State.AutoFarm) else setFarm(not State.AutoFarm) end
   end)

   -- перетаскивание (мышь и тач)
   local dragging, dragStart, startPos
   bar.InputBegan:Connect(function(input)
      if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
         dragging, dragStart, startPos = true, input.Position, card.Position
         input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
         end)
      end
   end)
   table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
      if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
         local delta = input.Position - dragStart
         card.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
      end
   end))

   function HUD.Update(status, cashLine, incomeLine, extraLine, color, running)
      l1.Text, l2.Text, l3.Text, l4.Text = status, cashLine, incomeLine, extraLine
      dot.BackgroundColor3 = color
      btn.Text = running and "⏹ Стоп" or "▶ Старт"
      btn.BackgroundColor3 = running and Color3.fromRGB(90, 100, 110) or ACCENT
   end
   HUD.Visible = true
   function HUD.SetVisible(v)
      HUD.Visible = v
      gui.Enabled = v
   end
   function HUD.Destroy() gui:Destroy() end
end

local Popup = { Open = false, LastAction = "x", Busy = false }
do
   local gui = makeScreenGui("CheatHubPopup", 1000)
   gui.Enabled = false
   local card = new("Frame", {
      Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
      Size = UDim2.fromOffset(320, 176), BackgroundColor3 = Theme.Background, BorderSizePixel = 0,
   }, gui)
   new("UICorner", { CornerRadius = UDim.new(0, 14) }, card)
   new("UIStroke", { Color = ACCENT, Thickness = 2 }, card)
   local scale = new("UIScale", { Scale = 1 }, card)

   new("TextLabel", {
      Name = "Title", Size = UDim2.new(1, -60, 0, 30), Position = UDim2.new(0, 16, 0, 12), BackgroundTransparency = 1,
      Text = CONFIG.Popup.Title, Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Theme.TextColor,
      TextXAlignment = Enum.TextXAlignment.Left,
   }, card)

   local closeBtn = new("TextButton", {
      Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(30, 30),
      BackgroundColor3 = Theme.ElementBackground, Text = "✕", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.TextColor,
   }, card)
   new("UICorner", { CornerRadius = UDim.new(0, 8) }, closeBtn)

   new("TextLabel", {
      Name = "Body", Size = UDim2.new(1, -32, 0, 56), Position = UDim2.new(0, 16, 0, 50), BackgroundTransparency = 1,
      Text = CONFIG.Popup.Text, Font = Enum.Font.Gotham, TextSize = 14, TextWrapped = true,
      TextColor3 = Color3.fromRGB(200, 220, 230), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
   }, card)

   local okBtn = new("TextButton", {
      Name = "Ok", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(1, -32, 0, 40),
      BackgroundColor3 = ACCENT, Text = "OK", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Color3.new(1, 1, 1),
   }, card)
   new("UICorner", { CornerRadius = UDim.new(0, 10) }, okBtn)

   function Popup.Show()
      if Popup.Open then return end
      Popup.Open, Popup.Busy = true, false
      okBtn.Text, okBtn.BackgroundColor3 = "OK", ACCENT
      scale.Scale = 0.85
      gui.Enabled = true
      TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
   end

   function Popup.Hide()
      if not Popup.Open then return end
      Popup.Open = false
      TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 0.9 }):Play()
      task.delay(0.12, function()
         if not Popup.Open then gui.Enabled = false end
      end)
   end

   function Popup.Destroy() gui:Destroy() end

   closeBtn.Activated:Connect(function()
      Popup.LastAction = "x"
      Popup.Hide()
   end)

   okBtn.Activated:Connect(function()
      if Popup.Busy then return end
      Popup.Busy = true
      Popup.LastAction = "ok"
      local copied = copyLink()
      okBtn.BackgroundColor3 = GREEN
      okBtn.Text = copied and "✅ Ссылка скопирована" or CONFIG.TelegramUrl
      task.delay(2.5, Popup.Hide)
   end)
end

-- =====================================================================
-- 9. REMOTE SPY, SCANNER, SERVER TOOLS
-- =====================================================================
local Spy = env.CheatHubSpy
if not Spy then
   Spy = {
      Hooked = false, Enabled = false, Log = {}, LastTime = {},
      Ignore = { "position", "camera", "mouse", "ping", "heartbeat", "cframe" },
   }
   env.CheatHubSpy = Spy
end

local function installSpy()
   if Spy.Hooked then return true end
   if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then return false end
   local wrap = (type(newcclosure) == "function") and newcclosure or function(f) return f end
   local ok = pcall(function()
      local old
      old = hookmetamethod(game, "__namecall", wrap(function(self, ...)
         local method = getnamecallmethod()
         if Spy.Enabled and (method == "FireServer" or method == "InvokeServer") then
            local packed = table.pack(...)
            pcall(function()
               if type(checkcaller) == "function" and checkcaller() then return end
               if typeof(self) ~= "Instance" then return end
               local cls = self.ClassName
               if cls ~= "RemoteEvent" and cls ~= "RemoteFunction" then return end
               local name = self.Name
               local now = os.clock()
               if Spy.LastTime[name] and now - Spy.LastTime[name] < 0.3 then return end
               Spy.LastTime[name] = now
               local lname = name:lower()
               for _, kw in ipairs(Spy.Ignore) do
                  if lname:find(kw, 1, true) then return end
               end
               Spy.Log[#Spy.Log + 1] = { remote = self, args = packed, t = now }
               if #Spy.Log > 40 then table.remove(Spy.Log, 1) end
            end)
         end
         return old(self, ...)
      end))
   end)
   Spy.Hooked = ok
   return ok
end

local function argToken(v)
   local t = typeof(v)
   if t == "string" then
      if v:find("[,|]") then return nil end
      for _, tree in ipairs(TreeNames) do
         if tree:lower() == v:lower() then return "{tree}" end
      end
      return v
   elseif t == "number" or t == "boolean" then
      return tostring(v)
   elseif t == "nil" then
      return "nil"
   elseif t == "Instance" and v == Player then
      return "{player}"
   end
   return nil
end

-- Возвращает (строка привязки, были_неподдерживаемые_аргументы)
local function formatCall(rec)
   local toks, warn = {}, false
   for i = 1, rec.args.n do
      local tok = argToken(rec.args[i])
      if tok == nil then
         tok, warn = "?", true
      end
      toks[#toks + 1] = tok
   end
   return rec.remote:GetFullName() .. " | " .. table.concat(toks, ", "), warn
end

local function spyJournalText()
   if #Spy.Log == 0 then return "Журнал пуст. Включи Spy и сделай действие в игре руками." end
   local lines = {}
   for i = math.max(1, #Spy.Log - 11), #Spy.Log do
      local rec = Spy.Log[i]
      local toks = {}
      for j = 1, rec.args.n do toks[#toks + 1] = tostring(argToken(rec.args[j]) or typeof(rec.args[j])) end
      lines[#lines + 1] = ("%d) %s | %s"):format(i, rec.remote.Name, table.concat(toks, ", "))
   end
   return table.concat(lines, "\n")
end

-- Скан игры: возвращает (краткая сводка, полный отчёт)
local function scanGame()
   invalidateCache()
   local rem, prm, clk = {}, {}, {}
   for _, root in ipairs({ RS, WS }) do
      for _, o in ipairs(root:GetDescendants()) do
         if isRemote(o) then
            rem[#rem + 1] = o
         elseif o:IsA("ProximityPrompt") then
            prm[#prm + 1] = o
         elseif o:IsA("ClickDetector") then
            clk[#clk + 1] = o
         end
      end
   end

   local report = { ("PlaceId: %s | Executor: %s"):format(tostring(game.PlaceId), Executor.Name), "", "== REMOTES ==" }
   for i = 1, math.min(#rem, 400) do
      report[#report + 1] = ("[%s] %s"):format(rem[i].ClassName, rem[i]:GetFullName())
   end
   report[#report + 1] = ""
   report[#report + 1] = "== PROXIMITY PROMPTS =="
   for i = 1, math.min(#prm, 300) do
      report[#report + 1] = ("%s | action=%s object=%s"):format(prm[i]:GetFullName(), prm[i].ActionText, prm[i].ObjectText)
   end
   report[#report + 1] = ""
   report[#report + 1] = "== CLICK DETECTORS =="
   for i = 1, math.min(#clk, 300) do
      report[#report + 1] = clk[i]:GetFullName()
   end

   local summary = { ("Remote: %d | Prompt: %d | ClickDetector: %d"):format(#rem, #prm, #clk) }
   for _, key in ipairs(ActionOrder) do
      local spec = Actions[key]
      local hits = {}
      for _, r in ipairs(rem) do
         local ln = r.Name:lower()
         for _, kw in ipairs(spec.remotes) do
            if ln:find(kw:lower(), 1, true) then
               hits[#hits + 1] = r.Name
               break
            end
         end
         if #hits >= 3 then break end
      end
      summary[#summary + 1] = spec.label .. ": " .. (#hits > 0 and table.concat(hits, ", ") or "—")
   end
   return table.concat(summary, "\n"), table.concat(report, "\n")
end

local function capsReport()
   local names = {
      "fireproximityprompt", "fireclickdetector", "firetouchinterest", "firesignal", "getconnections",
      "hookmetamethod", "setclipboard", "queue_on_teleport", "setfpscap", "gethui",
   }
   local t = {}
   for _, n in ipairs(names) do
      t[#t + 1] = (type(env[n]) == "function" and "✅ " or "❌ ") .. n
   end
   return "Executor: " .. Executor.Name .. "\n" .. table.concat(t, "\n")
end

local function queueReload()
   if CONFIG.ReloadUrl ~= "" and type(queue_on_teleport) == "function" then
      pcall(queue_on_teleport, ("loadstring(game:HttpGet(%q))()"):format(CONFIG.ReloadUrl))
   end
end

local function rejoin()
   queueReload()
   if #Players:GetPlayers() <= 1 then
      TeleportService:Teleport(game.PlaceId, Player)
   else
      TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
   end
end

local function serverHop()
   local ok, body = pcall(function()
      return game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100")
   end)
   if not ok then return false, "HTTP-запрос не прошёл" end
   local okj, data = pcall(function() return HttpService:JSONDecode(body) end)
   if not okj or type(data) ~= "table" or type(data.data) ~= "table" then return false, "ответ API не разобран" end
   local candidates = {}
   for _, s in ipairs(data.data) do
      if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
         candidates[#candidates + 1] = s
      end
   end
   if #candidates == 0 then return false, "нет подходящих серверов" end
   local pick = candidates[math.random(1, #candidates)]
   queueReload()
   TeleportService:TeleportToPlaceInstance(game.PlaceId, pick.id, Player)
   return true
end

local function fpsBoost()
   pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
   pcall(function() Lighting.GlobalShadows = false end)
   local n = 0
   for _, o in ipairs(WS:GetDescendants()) do
      if o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam") or o:IsA("Smoke") or o:IsA("Fire") or o:IsA("Sparkles") then
         pcall(function() o.Enabled = false end)
         n = n + 1
      end
   end
   return n
end

local function setAfkSaver(v)
   State.AfkSaver = v
   pcall(function() RunService:Set3dRenderingEnabled(not v) end)
   if type(setfpscap) == "function" then pcall(setfpscap, v and 15 or 60) end
end

local function applySpeed()
   local hum = getHumanoid()
   if hum then hum.WalkSpeed = State.SpeedEnabled and State.SpeedValue or 16 end
end

-- Промокоды: remote -> либо UI (Menu → Codes → ENTER CODE → REDEEM)
local function redeemOne(code)
   local r = findRemote({ "RedeemCode", "Redeem", "Code", "RedeemPromoCode" })
   if r and callRemote(r, { n = 1, code }) then return true, "remote" end

   local box
   for _, o in ipairs(Player.PlayerGui:GetDescendants()) do
      if o:IsA("TextBox") and not isOwnGui(o) then
         local ph = (o.PlaceholderText or ""):lower()
         if ph:find("code", 1, true) or o.Name:lower():find("code", 1, true) then
            box = o
            break
         end
      end
   end
   if not box then return false, "поле кода не найдено — открой Menu → Codes" end
   box.Text = code

   local btn
   local scope = box.Parent
   for _ = 1, 4 do
      if not scope then break end
      for _, o in ipairs(scope:GetDescendants()) do
         if o:IsA("TextButton") and ((o.Text or ""):lower():find("redeem", 1, true) or o.Name:lower():find("redeem", 1, true)) then
            btn = o
            break
         end
      end
      if btn then break end
      scope = scope.Parent
   end
   if not btn then return false, "кнопка Redeem не найдена" end
   if clickGui(btn) then return true, "ui" end
   return false, "клик по Redeem не сработал"
end

-- =====================================================================
-- 10. UI
-- =====================================================================
local L_Status, L_Cash, L_Income, L_Rep, L_Actions, L_Time
local DecorLabel
local BindInputs = {}
local SpyToggle

-- ГЛАВНАЯ
local HomeTab = Window:CreateTab("🎄 Главная", "home")
HomeTab:CreateSection("Управление")
FarmToggle = HomeTab:CreateToggle({
   Name = "🚀 Автофарм (клавиша F6)",
   CurrentValue = false,
   Callback = function(v) setFarm(v) end,
})
local HudToggle = HomeTab:CreateToggle({
   Name = "📊 Мини-панель (клавиша F7)",
   CurrentValue = true,
   Flag = "HudVisible",
   Callback = function(v) HUD.SetVisible(v) end,
})
HomeTab:CreateButton({
   Name = "📢 Скопировать ссылку на Telegram",
   Callback = function()
      if copyLink() then
         notify("Готово", "Ссылка скопирована.", 3, "copy")
      else
         notify("Ссылка", CONFIG.TelegramUrl, 6, "copy")
      end
   end,
})

HomeTab:CreateSection("Статистика")
L_Status = HomeTab:CreateLabel("📊 Статус: Ожидание")
L_Cash = HomeTab:CreateLabel("💰 Деньги: —")
L_Income = HomeTab:CreateLabel("📈 Доход: запусти автофарм")
L_Rep = HomeTab:CreateLabel("⭐ Репутация: —")
L_Actions = HomeTab:CreateLabel("⚡ Действий: 0 (0/мин)")
L_Time = HomeTab:CreateLabel("⏱️ Сессия: 00:00:00")

-- АВТОФАРМ
local FarmTab = Window:CreateTab("🌲 Автофарм", "tree-pine")
FarmTab:CreateSection("Модули (работают при включённом автофарме)")
FarmTab:CreateToggle({ Name = "Авто-заказ деревьев", CurrentValue = true, Flag = "AutoOrder", Callback = function(v) State.AutoOrder = v end })
FarmTab:CreateToggle({ Name = "Авто-обслуживание (клиенты + касса)", CurrentValue = true, Flag = "AutoServe", Callback = function(v) State.AutoServe = v end })
FarmTab:CreateToggle({ Name = "Авто-найм работников", CurrentValue = true, Flag = "AutoHire", Callback = function(v) State.AutoHire = v end })
FarmTab:CreateToggle({ Name = "Авто-апгрейды", CurrentValue = true, Flag = "AutoUpgrade", Callback = function(v) State.AutoUpgrade = v end })
FarmTab:CreateToggle({ Name = "Авто-сбор (деньги / подарки)", CurrentValue = true, Flag = "AutoCollect", Callback = function(v) State.AutoCollect = v end })
FarmTab:CreateToggle({ Name = "Авто-награды (раз в минуту)", CurrentValue = true, Flag = "AutoReward", Callback = function(v) State.AutoReward = v end })

FarmTab:CreateSection("Настройки")
FarmTab:CreateDropdown({
   Name = "Какое дерево заказывать?",
   Options = TreeNames,
   CurrentOption = { "Pine" },
   MultipleOptions = false,
   Flag = "TreeType",
   Callback = function(opt)
      State.SelectedTree = (type(opt) == "table" and opt[1]) or opt or "Pine"
   end,
})
FarmTab:CreateSlider({
   Name = "Пауза между заказами/продажами",
   Range = { 0.3, 5 }, Increment = 0.1, Suffix = " сек", CurrentValue = 1.0, Flag = "CycleDelay",
   Callback = function(v) State.CycleDelay = v end,
})
FarmTab:CreateSlider({
   Name = "Интервал найма / апгрейдов",
   Range = { 5, 120 }, Increment = 5, Suffix = " сек", CurrentValue = 15, Flag = "SlowInterval",
   Callback = function(v) State.SlowInterval = v end,
})
FarmTab:CreateToggle({
   Name = "Человеческий разброс задержек",
   CurrentValue = true, Flag = "Humanize",
   Callback = function(v) State.Humanize = v end,
})

FarmTab:CreateSection("Авто-сбор")
FarmTab:CreateInput({
   Name = "Ключевые слова предметов",
   CurrentValue = "money, coin, gift, snowflake",
   PlaceholderText = "через запятую",
   RemoveTextAfterFocusLost = false,
   Flag = "CollectKW",
   Callback = function(text)
      State.CollectKW = parseKeywords(text)
      Cache["collectibles"] = nil
   end,
})
FarmTab:CreateSlider({
   Name = "Радиус сбора",
   Range = { 30, 500 }, Increment = 10, Suffix = " studs", CurrentValue = 150, Flag = "CollectRadius",
   Callback = function(v) State.CollectRadius = v end,
})

-- АВТО-БАЗА
local DecorTab = Window:CreateTab("🏠 Авто-База", "hammer")
DecorTab:CreateSection("Улучшение и украшение")
DecorTab:CreateParagraph({ Title = "Авто-декор", Content = "Покупает и расставляет декор, если в игре есть подходящие объекты. Если не срабатывает — привяжи действия во вкладке «Диагностика»." })
DecorLabel = DecorTab:CreateLabel("Действий с декором: 0")
DecorTab:CreateToggle({
   Name = "🛠️ Авто-покупка и установка декора",
   CurrentValue = false,
   Callback = function(v)
      State.AutoDecor = v
      if v then
         playSound("9118823103")
         notify("Авто-База", "Начинаю украшать базу!", 3, "decor")
      end
   end,
})

-- ДИАГНОСТИКА
local DiagTab = Window:CreateTab("🔧 Диагностика", "wrench")
DiagTab:CreateSection("Проверка действий")
DiagTab:CreateDropdown({
   Name = "Действие",
   Options = ActionLabels,
   CurrentOption = { ActionLabels[1] },
   MultipleOptions = false,
   Callback = function(opt)
      local label = (type(opt) == "table" and opt[1]) or opt
      State.TestTarget = LabelToKey[label] or State.TestTarget
   end,
})
DiagTab:CreateButton({
   Name = "▶️ Выполнить действие один раз",
   Callback = function()
      local ok, how = runAction(State.TestTarget)
      if ok then
         notify("✅ Сработало", Actions[State.TestTarget].label .. " — " .. how, 5, "test")
      else
         notify("❌ Не сработало", "Запусти «Сканер» или привяжи действие через Spy.", 6, "test")
      end
   end,
})

DiagTab:CreateSection("Сканер игры")
local ScanInfo = DiagTab:CreateParagraph({ Title = "Результат", Content = "Нажми «Сканировать игру»." })
local lastReport = ""
DiagTab:CreateButton({
   Name = "🔍 Сканировать игру",
   Callback = function()
      local summary, report = scanGame()
      lastReport = report
      ScanInfo:Set({ Title = "Результат (похожие remote по действиям)", Content = summary })
      notify("Скан завершён", "Полный отчёт можно скопировать кнопкой ниже.", 4, "scan")
   end,
})
DiagTab:CreateButton({
   Name = "📋 Копировать полный отчёт",
   Callback = function()
      if lastReport == "" then
         notify("Пусто", "Сначала нажми «Сканировать игру».", 3, "scan")
      elseif type(setclipboard) == "function" then
         pcall(setclipboard, lastReport)
         notify("Готово", "Отчёт скопирован в буфер.", 3, "scan")
      else
         notify("Нет буфера", "Твой executor не поддерживает setclipboard.", 4, "scan")
      end
   end,
})

DiagTab:CreateSection("Remote Spy — подсмотреть настоящие вызовы игры")
DiagTab:CreateParagraph({
   Title = "Как пользоваться",
   Content = "1) Включи Spy. 2) Сделай нужное действие в игре руками (купи дерево, продай, найми). 3) Нажми «Показать журнал», выбери действие ниже и нажми «Привязать». Скрипт запомнит remote и аргументы.",
})
SpyToggle = DiagTab:CreateToggle({
   Name = "👁️ Включить Remote Spy",
   CurrentValue = false,
   Callback = function(v)
      if v then
         if installSpy() then
            Spy.Enabled = true
            notify("Spy включён", "Делай действия в игре — вызовы попадут в журнал.", 4, "spy")
         else
            Spy.Enabled = false
            notify("Spy недоступен", "Executor не поддерживает hookmetamethod.", 5, "spy")
            task.defer(function() SpyToggle:Set(false) end)
         end
      else
         Spy.Enabled = false
      end
   end,
})
local SpyView = DiagTab:CreateParagraph({ Title = "Журнал", Content = "Пусто" })
DiagTab:CreateButton({
   Name = "🔄 Показать журнал",
   Callback = function()
      SpyView:Set({ Title = "Журнал (последние вызовы)", Content = spyJournalText() })
   end,
})
DiagTab:CreateDropdown({
   Name = "Привязать к действию",
   Options = ActionLabels,
   CurrentOption = { ActionLabels[1] },
   MultipleOptions = false,
   Callback = function(opt)
      local label = (type(opt) == "table" and opt[1]) or opt
      State.BindTarget = LabelToKey[label] or State.BindTarget
   end,
})
DiagTab:CreateInput({
   Name = "№ записи из журнала (пусто = последняя)",
   CurrentValue = "",
   PlaceholderText = "например 3",
   RemoveTextAfterFocusLost = false,
   Callback = function(text) State.SpyPick = text end,
})
DiagTab:CreateButton({
   Name = "🔗 Привязать выбранный вызов",
   Callback = function()
      local idx = tonumber(State.SpyPick) or #Spy.Log
      local rec = Spy.Log[idx]
      if not rec then
         notify("Журнал пуст", "Включи Spy и сделай действие в игре.", 4, "bind")
         return
      end
      local text, warn = formatCall(rec)
      BindInputs[State.BindTarget]:Set(text)
      if warn then
         notify("Привязано с оговоркой", "Часть аргументов не поддерживается (стоит «?»). Поправь вручную.", 6, "bind")
      else
         notify("✅ Привязано", Actions[State.BindTarget].label .. ": " .. text, 5, "bind")
      end
   end,
})

DiagTab:CreateSection("Привязки действий (формат: Remote | аргументы)")
DiagTab:CreateParagraph({
   Title = "Формат",
   Content = "Пример: ReplicatedStorage.Remotes.OrderTree | {tree}, 1\nМожно использовать {tree} (выбранное дерево) и {player}. Пусто = автопоиск.",
})
for _, key in ipairs(ActionOrder) do
   BindInputs[key] = DiagTab:CreateInput({
      Name = Actions[key].label,
      CurrentValue = "",
      PlaceholderText = "Remote | аргументы (пусто = авто)",
      RemoveTextAfterFocusLost = false,
      Flag = "Bind_" .. key,
      Callback = function(text)
         local remote, args = parseBinding(text)
         Binds[key] = { remote = remote, args = args }
      end,
   })
end
DiagTab:CreateButton({
   Name = "🧹 Сбросить все привязки",
   Callback = function()
      for _, key in ipairs(ActionOrder) do BindInputs[key]:Set("") end
      notify("Готово", "Все привязки сброшены.", 3, "bind")
   end,
})

DiagTab:CreateSection("Деньги и репутация (для панели)")
DiagTab:CreateInput({
   Name = "Имя валюты в leaderstats (если не нашлось само)",
   CurrentValue = "",
   PlaceholderText = "например Cash",
   RemoveTextAfterFocusLost = false,
   Flag = "CashName",
   Callback = function(text)
      State.CashName = text or ""
      invalidateCache()
   end,
})
DiagTab:CreateInput({
   Name = "Имя репутации (если не нашлось само)",
   CurrentValue = "",
   PlaceholderText = "например Reputation",
   RemoveTextAfterFocusLost = false,
   Flag = "RepName",
   Callback = function(text)
      State.RepName = text or ""
      invalidateCache()
   end,
})

DiagTab:CreateSection("Совместимость executor")
DiagTab:CreateParagraph({ Title = "Что поддерживается", Content = capsReport() })

-- ИГРОК
local PlayerTab = Window:CreateTab("🏃 Игрок", "user")
PlayerTab:CreateSection("Движение")
PlayerTab:CreateSlider({
   Name = "Скорость ходьбы",
   Range = { 16, 300 }, Increment = 1, Suffix = "", CurrentValue = 50, Flag = "SpeedValue",
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

PlayerTab:CreateSection("Телепорты")
PlayerTab:CreateToggle({ Name = "Плавный телепорт (анимация)", CurrentValue = true, Flag = "SmoothTP", Callback = function(v) State.SmoothTeleport = v end })
PlayerTab:CreateButton({
   Name = "🚚 Телепорт к грузовику",
   Callback = function()
      local pos = modelPosition(findModel({ "truck", "supply" }))
      if pos then teleportTo(pos) else notify("Не найдено", "Грузовик не найден.", 3, "tp") end
   end,
})
PlayerTab:CreateButton({
   Name = "💰 Телепорт к кассе",
   Callback = function()
      local pos = modelPosition(findModel({ "cashier", "register" }))
      if pos then teleportTo(pos) else notify("Не найдено", "Касса не найдена.", 3, "tp") end
   end,
})

PlayerTab:CreateSection("Безопасная точка")
PlayerTab:CreateButton({
   Name = "📍 Запомнить текущую позицию",
   Callback = function()
      local hrp = getHRP()
      if hrp then
         State.SafePos = hrp.Position
         notify("Готово", "Позиция сохранена.", 3, "safe")
      end
   end,
})
PlayerTab:CreateButton({
   Name = "🏠 Вернуться на сохранённую точку",
   Callback = function()
      if State.SafePos then teleportTo(State.SafePos) else notify("Нет точки", "Сначала запомни позицию.", 3, "safe") end
   end,
})
PlayerTab:CreateToggle({
   Name = "Анти-падение (вернуть, если упал под карту)",
   CurrentValue = true, Flag = "VoidGuard",
   Callback = function(v) State.VoidGuard = v end,
})

-- РАЗНОЕ
local MiscTab = Window:CreateTab("🎁 Разное", "gift")
MiscTab:CreateSection("Промокоды")
MiscTab:CreateButton({
   Name = "🚀 Ввести все коды",
   Callback = function()
      playSound("6895079853")
      local sent, lastErr = 0, nil
      for _, code in ipairs(ActiveCodes) do
         local ok, how = redeemOne(code)
         if ok then
            sent = sent + 1
         else
            lastErr = how
            if how and how:find("Codes", 1, true) then break end
         end
         task.wait(0.6)
      end
      if sent > 0 then
         notify("Коды", ("Отправлено: %d из %d. Часть кодов могла устареть."):format(sent, #ActiveCodes), 5, "codes")
      else
         notify("Коды не отправлены", lastErr or "неизвестная ошибка", 6, "codes")
      end
   end,
})
MiscTab:CreateInput({
   Name = "Свой промокод",
   CurrentValue = "",
   PlaceholderText = "введи код и нажми Enter",
   RemoveTextAfterFocusLost = true,
   Callback = function(text)
      if text and text ~= "" then
         local ok, how = redeemOne(text)
         notify(ok and "Код отправлен" or "Не получилось", ok and text or (how or "ошибка"), 4, "code1")
      end
   end,
})

MiscTab:CreateSection("Защита и сервер")
MiscTab:CreateToggle({ Name = "Анти-АФК (защита от кика)", CurrentValue = true, Flag = "AntiAFK", Callback = function(v) State.AntiAFK = v end })
MiscTab:CreateToggle({ Name = "Авто-рейджойн при дисконнекте", CurrentValue = false, Flag = "AutoRejoin", Callback = function(v) State.AutoRejoin = v end })
MiscTab:CreateButton({ Name = "🔁 Перезайти на сервер", Callback = function() rejoin() end })
MiscTab:CreateButton({
   Name = "🌐 Сменить сервер",
   Callback = function()
      local ok, err = serverHop()
      if not ok then notify("Не удалось", err or "ошибка", 5, "hop") end
   end,
})

MiscTab:CreateSection("Производительность")
MiscTab:CreateToggle({
   Name = "💤 Режим AFK (без 3D, 15 FPS)",
   CurrentValue = false,
   Callback = function(v) setAfkSaver(v) end,
})
MiscTab:CreateButton({
   Name = "⚡ Снизить нагрузку (эффекты, тени)",
   Callback = function()
      local n = fpsBoost()
      notify("Готово", ("Отключено эффектов: %d"):format(n), 4, "fps")
   end,
})

MiscTab:CreateSection("Интерфейс")
MiscTab:CreateDropdown({
   Name = "Тема",
   Options = { "Winter", "Default", "Ocean", "AmberGlow", "Amethyst", "Bloom", "DarkBlue", "Green", "Light", "Serenity" },
   CurrentOption = { "Winter" },
   MultipleOptions = false,
   Callback = function(opt)
      local name = (type(opt) == "table" and opt[1]) or opt
      if not name or name == State.ThemeName then return end
      State.ThemeName = name
      pcall(function()
         if name == "Winter" then Window.ModifyTheme(Theme) else Window.ModifyTheme(name) end
      end)
   end,
})
MiscTab:CreateKeybind({
   Name = "Клавиша автофарма",
   CurrentKeybind = "F6",
   HoldToInteract = false,
   Flag = "KeyFarm",
   Callback = function() FarmToggle:Set(not State.AutoFarm) end,
})
MiscTab:CreateKeybind({
   Name = "Клавиша мини-панели",
   CurrentKeybind = "F7",
   HoldToInteract = false,
   Flag = "KeyHud",
   Callback = function() HudToggle:Set(not HUD.Visible) end,
})
MiscTab:CreateButton({
   Name = "📢 Показать окно подписки (тест)",
   Callback = function() Popup.Show() end,
})

MiscTab:CreateSection("Управление")
MiscTab:CreateButton({
   Name = "🗑️ Выгрузить скрипт",
   Callback = function()
      if env.CheatHubWinter and env.CheatHubWinter.Unload then env.CheatHubWinter.Unload() end
   end,
})

-- =====================================================================
-- 11. UI REFRESH, CONNECTIONS, LOOPS
-- =====================================================================
local function updateUI()
   local now = os.clock()
   local cash = readStat("cash", State.CashName)
   local rep = readStat("rep", State.RepName)
   local farmSec = (State.AutoFarm and State.FarmStart) and (now - State.FarmStart) or 0

   local incomeText, hudIncome = "📈 Доход: запусти автофарм", "📈 —"
   if State.AutoFarm and cash and State.FarmStartCash then
      local gained = cash - State.FarmStartCash
      local perHour = (farmSec > 10) and (gained / (farmSec / 3600)) or 0
      incomeText = ("📈 За фарм: %s | в час: %s"):format(fmtNum(gained), fmtNum(perHour))
      hudIncome = ("📈 %s (%s/ч)"):format(fmtNum(gained), fmtNum(perHour))
   end
   local apm = (State.AutoFarm and farmSec > 10) and (State.FarmActions / (farmSec / 60)) or 0

   local color = GRAY
   if State.AutoFarm then
      local idle = now - State.LastSuccess
      if idle < 15 then color = GREEN elseif idle < 60 then color = YELLOW else color = RED end
   end
   if not State.AutoFarm and not State.AutoDecor then State.Status = "Ожидание" end

   L_Status:Set("📊 Статус: " .. State.Status)
   L_Cash:Set("💰 Деньги: " .. (cash and fmtNum(cash) or "— (укажи имя в «Диагностике»)"))
   L_Income:Set(incomeText)
   L_Rep:Set("⭐ Репутация: " .. fmtNum(rep))
   L_Actions:Set(("⚡ Действий: %d (%.1f/мин)"):format(State.TotalActions, apm))
   L_Time:Set("⏱️ Сессия: " .. fmtTime(now - State.SessionStart))
   DecorLabel:Set("Действий с декором: " .. State.DecorActions)

   HUD.Update(
      "● " .. State.Status,
      "💰 " .. fmtNum(cash),
      hudIncome,
      ("⭐ %s   ⚡ %.0f/мин"):format(fmtNum(rep), apm),
      color,
      State.AutoFarm
   )

   -- Сторож: фарм идёт, а прибыли нет
   if State.AutoFarm then
      if cash then
         if State.WatchCash == nil or cash ~= State.WatchCash then
            State.WatchCash, State.WatchAt = cash, now
         elseif now - State.WatchAt > 120 and farmSec > 120 then
            notify("⚠️ Деньги не растут", "2 минуты без изменений. Загляни во вкладку «Диагностика».", 7, "wd_cash", 300)
         end
      end
      if now - State.LastSuccess > 90 then
         notify("⚠️ Нет успешных действий", "Скрипт не находит, что нажимать. Запусти «Сканер» в «Диагностике».", 7, "wd_idle", 300)
      end
   end

   -- Анти-падение
   if State.VoidGuard and State.SafePos then
      local hrp = getHRP()
      if hrp and hrp.Position.Y < State.SafePos.Y - 150 then
         hrp.CFrame = CFrame.new(State.SafePos + Vector3.new(0, 5, 0))
         notify("Анти-падение", "Вернул на безопасную точку.", 3, "void", 5)
      end
   end

   -- Некоторые игры сбрасывают скорость
   if State.SpeedEnabled then applySpeed() end
end

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

-- Авто-рейджойн при окне ошибки Roblox
task.spawn(function()
   local ok, overlay = pcall(function()
      local gui = game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 10)
      return gui and gui:WaitForChild("promptOverlay", 10)
   end)
   if ok and overlay then
      table.insert(Connections, overlay.ChildAdded:Connect(function(child)
         if State.AutoRejoin and child.Name == "ErrorPrompt" then
            task.wait(3)
            queueReload()
            TeleportService:Teleport(game.PlaceId, Player)
         end
      end))
   end
end)

-- Безопасная точка по умолчанию — место, где скрипт запустили
task.spawn(function()
   local t0 = os.clock()
   while State.Running and not getHRP() and os.clock() - t0 < 15 do task.wait(0.5) end
   local hrp = getHRP()
   if hrp and not State.SafePos then State.SafePos = hrp.Position end
end)

-- Главный цикл (каждая итерация под pcall — одна ошибка не убьёт цикл)
task.spawn(function()
   while State.Running do
      task.wait(0.2)
      local ok, err = pcall(function()
         local hum = getHumanoid()
         if not hum or hum.Health <= 0 then
            if State.AutoFarm or State.AutoDecor then State.Status = "Ждём респавн..." end
            return
         end
         if State.AutoFarm then farmStep() end
         if State.AutoDecor and due("decor", 6) then doDecor() end
      end)
      if not ok then dbg("Ошибка цикла:", err) end
   end
end)

-- Обновление интерфейса
task.spawn(function()
   while State.Running do
      task.wait(1)
      local ok, err = pcall(updateUI)
      if not ok then dbg("Ошибка UI:", err) end
   end
end)

-- Окно «Подпишитесь на канал»: появляется со временем, ✕ закрывает, OK копирует ссылку
task.spawn(function()
   if not CONFIG.Popup.Enabled then return end
   local waitFor = CONFIG.Popup.FirstDelay
   while State.Running do
      local t0 = os.clock()
      while State.Running and os.clock() - t0 < waitFor do task.wait(1) end
      if not State.Running then break end
      Popup.Show()
      while State.Running and Popup.Open do task.wait(0.5) end
      if Popup.LastAction == "ok" then
         waitFor = CONFIG.Popup.IntervalAfterOk
      else
         waitFor = CONFIG.Popup.IntervalAfterClose
      end
   end
end)

-- =====================================================================
-- 12. UNLOAD & START
-- =====================================================================
local function Unload()
   State.Running = false
   State.AutoFarm, State.AutoDecor = false, false
   Spy.Enabled = false
   if State.AfkSaver then setAfkSaver(false) end
   for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
   pcall(HUD.Destroy)
   pcall(Popup.Destroy)
   local hum = getHumanoid()
   if hum then hum.WalkSpeed = 16 end
   pcall(function() Rayfield:Destroy() end)
   env.CheatHubWinter = nil
end
env.CheatHubWinter = { Unload = Unload }

Rayfield:LoadConfiguration()
playSound("9118823103")
notify("❄️ Winter Magic", "CheatHub v9 загружен! Меню: клавиша K, автофарм: F6.", 6, "loaded")
