-- CheatHub v10 — Winter Magic Edition
-- Run a Christmas Tree Lot
-- by dj

-- =====================================================================
-- 0. CONFIG (правь здесь)
-- =====================================================================
local CONFIG = {
   TelegramUrl = "https://t.me/my_christmas_market",
   ReloadUrl = "",      -- ссылка на этот скрипт (для loadstring): после рейджойна он запустится сам
   Debug = false,       -- true = подробный вывод в консоль
   CacheTTL = 10,       -- сколько секунд помнить результаты редких поисков

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
local PPS = game:GetService("ProximityPromptService")
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

local function resolvePath(path)
   local cur = game
   for part in tostring(path):gmatch("[^%.]+") do
      cur = cur and cur:FindFirstChild(part)
      if not cur then return nil end
   end
   return cur
end

local function isOwnGui(obj)
   local sg = obj:FindFirstAncestorWhichIsA("ScreenGui")
   return sg ~= nil and (sg.Name == "Rayfield" or sg.Name:sub(1, 8) == "CheatHub")
end

-- Ключевые слова через запятую (фразы с пробелами допустимы)
local function parseKeywords(text)
   local list = {}
   for w in tostring(text or ""):gmatch("[^,]+") do
      local s = w:match("^%s*(.-)%s*$"):lower()
      if s ~= "" then list[#list + 1] = s end
   end
   return list
end

local function matchesAny(text, kws)
   for _, kw in ipairs(kws) do
      if text:find(kw, 1, true) then return true end
   end
   return false
end

-- Кэш для редких поисков (статы и т.п.)
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
-- 2. COLORS, THEME, STATE, ACTIONS
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
   AutoOrder = true, AutoServe = true, AutoPlace = true, AutoHire = true, AutoUpgrade = true,
   AutoReward = true, AutoCollect = false, AutoDecor = false, AutoPrice = false,
   SelectedTree = "Pine",
   CycleDelay = 1.0, OrderInterval = 40, SlowInterval = 20, Humanize = true,
   MoveMode = "teleport", HopCooldown = 0.6, MaxPerTick = 2, PromptCooldown = 2.0,
   PlotRadius = 160,
   PriceStep = 10, PriceMinPct = 60, NormalPrice = 0, PriceCooldown = 25,
   CashName = "", RepName = "",
   AntiAFK = true, AntiSit = true, AutoRejoin = false, VoidGuard = true,
   SpeedEnabled = false, SpeedValue = 50,
   AfkSaver = false,
   ThemeName = "Winter",
   Status = "Ожидание",
   SessionStart = os.clock(),
   FarmStart = nil, FarmStartCash = nil,
   WatchCash = nil, WatchAt = 0,
   TotalActions = 0, FarmActions = 0, DecorActions = 0, LastSuccess = 0,
   SafePos = nil, Firing = false,
   BindTarget = "order", TestTarget = "order", TeachCat = "pickup", Pick = "",
}

-- Цена: текущая и базовая (узнаются из привязки «Цена»)
local Price = { value = nil, base = nil }

-- Категории действий. kw — слова для поиска ProximityPrompt (редактируются во вкладке «Правила»)
local ActionKeys = { "order", "pickup", "load", "checkout", "help", "place", "decor", "upgrade", "hire", "collect", "reward", "price" }
local Actions = {
   order = { label = "Заказ деревьев", kw = "order, supply, truck, delivery, catalog, computer, lot manager, wholesale, restock" },
   pickup = { label = "Взять дерево", kw = "pick up, pickup, pick, grab, take, carry" },
   load = { label = "Погрузка в машину", kw = "load, trunk, roof, vehicle, deliver, hand over" },
   checkout = { label = "Касса / оплата", kw = "checkout, check out, cashier, register, ring up, pay, till" },
   help = { label = "Помощь покупателю", kw = "help, serve, assist, greet, customer, shopper" },
   place = { label = "Расстановка деревьев", kw = "place, stock, unpack, unwrap, rack, shelf, display, crate, plant" },
   decor = { label = "Декор", kw = "decor, ornament, wreath, garland, tinsel, lights" },
   upgrade = { label = "Апгрейд HQ / расширение", kw = "upgrade, hq, headquarter, expand, expansion, unlock, extend, enlarge" },
   hire = { label = "Найм работников", kw = "hire" },
   collect = { label = "Сбор денег / предметов", kw = "collect, money, coin, tip" },
   reward = { label = "Награды", kw = "reward, daily, gift, present" },
   price = { label = "Цена (только через привязку)", kw = "", noPrompt = true },
}
-- Порядок классификации промптов (первое совпадение побеждает)
local CatOrder = { "hire", "upgrade", "order", "reward", "load", "pickup", "checkout", "help", "place", "decor", "collect" }
local GlobalExclude = { "robux", "gamepass", "game pass", "premium", "vip", "claim plot", "teleport", "bench", "seat", "chair", "sit down", "settings" }

local ActionLabels, LabelToKey, CatKW = {}, {}, {}
for _, k in ipairs(ActionKeys) do
   ActionLabels[#ActionLabels + 1] = Actions[k].label
   LabelToKey[Actions[k].label] = k
   CatKW[k] = parseKeywords(Actions[k].kw)
end

-- Ручные привязки: Binds[ключ] = { remote = "Имя или Путь", args = "a, b, {tree}" или JSON-массив }
local Binds = {}
for _, k in ipairs(ActionKeys) do Binds[k] = { remote = "", args = "" } end

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

local function findButton(keywords)
   for _, obj in ipairs(Player.PlayerGui:GetDescendants()) do
      if obj:IsA("TextButton") and obj.Visible and not isOwnGui(obj) then
         local txt = obj.Text:lower()
         if not txt:find("robux", 1, true) and matchesAny(txt, keywords) then return obj end
      end
   end
   return nil
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
   LoadingSubtitle = "v10",
   Theme = Theme,
   ToggleUIKeybind = "K",
   DisableRayfieldPrompts = true,
   DisableBuildWarnings = true,
   ConfigurationSaving = { Enabled = true, FolderName = "CheatHubWinter", FileName = "Config" },
   KeySystem = false,
})

-- =====================================================================
-- 5. АРГУМЕНТЫ REMOTE, ИНДЕКСЫ (без тяжёлых сканов), ПРОСЛУШКА СЕРВЕРА
-- =====================================================================
local function decodeValue(v, ctx)
   local t = type(v)
   if t == "string" then
      if v == "{tree}" then return State.SelectedTree end
      if v == "{player}" then return Player end
      if v == "{price}" then return (ctx and ctx.price) or Price.value or 0 end
      return v
   elseif t == "table" then
      if v.__inst then return resolvePath(v.__inst) end
      if v.__v3 then return Vector3.new(v.__v3[1], v.__v3[2], v.__v3[3]) end
      if v.__cf then return CFrame.new(table.unpack(v.__cf)) end
      local out = {}
      for k, x in pairs(v) do out[k] = decodeValue(x, ctx) end
      return out
   end
   return v
end

local function parseBinding(text)
   text = tostring(text or "")
   local remote, args = text:match("^%s*([^|]-)%s*|%s*(.-)%s*$")
   if not remote then
      remote = text:match("^%s*(.-)%s*$")
      args = ""
   end
   return remote or "", args or ""
end

-- Аргументы: "Pine, 1, true, {tree}, {price}" или JSON-массив: [{"Pine":5}, "{price}"]
local function parseArgs(text, ctx)
   local out = { n = 0 }
   text = tostring(text or "")
   if text:match("^%s*$") then return out end
   if text:match("^%s*%[") then
      local ok, arr = pcall(function() return HttpService:JSONDecode(text) end)
      if ok and type(arr) == "table" then
         for i = 1, #arr do
            out.n = out.n + 1
            out[out.n] = decodeValue(arr[i], ctx)
         end
      end
      return out
   end
   for token in (text .. ","):gmatch("%s*(.-)%s*,") do
      local low = token:lower()
      local v
      if token == "{tree}" or token == "{player}" or token == "{price}" then
         v = decodeValue(token, ctx)
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

local function summarizeArg(v, depth)
   depth = depth or 0
   local t = typeof(v)
   if t == "string" then
      return v:sub(1, 80)
   elseif t == "number" or t == "boolean" then
      return tostring(v)
   elseif t == "Instance" then
      return v.Name
   elseif t == "table" and depth < 2 then
      local parts, n = {}, 0
      for k, x in pairs(v) do
         n = n + 1
         if n > 6 then
            parts[#parts + 1] = "…"
            break
         end
         parts[#parts + 1] = tostring(k) .. "=" .. summarizeArg(x, depth + 1)
      end
      return "{" .. table.concat(parts, ", ") .. "}"
   end
   return t
end

local function collectStrings(v, out, depth)
   depth = depth or 0
   if type(v) == "string" then
      out[#out + 1] = v
   elseif type(v) == "table" and depth < 3 then
      for _, x in pairs(v) do collectStrings(x, out, depth + 1) end
   end
end

local Reviews = { log = {}, seen = {}, lastHandled = 0, lastText = "", lastTextAt = 0, watching = false }
local Listen = { active = false, record = false, hooked = {}, log = {} }

local function listenRemote(r)
   if Listen.hooked[r] or r.ClassName ~= "RemoteEvent" then return end
   Listen.hooked[r] = r.OnClientEvent:Connect(function(...)
      if not State.Running then return end
      local packed = table.pack(...)
      if Listen.record then
         local parts = {}
         for i = 1, math.min(packed.n, 4) do parts[#parts + 1] = summarizeArg(packed[i]) end
         Listen.log[#Listen.log + 1] = r.Name .. " ← " .. table.concat(parts, ", ")
         if #Listen.log > 40 then table.remove(Listen.log, 1) end
      end
      if Reviews.feed then
         local strs = {}
         for i = 1, packed.n do collectStrings(packed[i], strs) end
         for _, s in ipairs(strs) do Reviews.feed(s, "remote:" .. r.Name) end
      end
   end)
end

local Index = { prompts = {}, clicks = {}, remotes = {}, remoteSet = {}, ready = false }

local function indexAdd(o)
   local c = o.ClassName
   if c == "ProximityPrompt" then
      Index.prompts[o] = true
   elseif c == "ClickDetector" then
      Index.clicks[o] = true
   elseif c == "RemoteEvent" or c == "RemoteFunction" then
      Index.remoteSet[o] = true
      local k = o.Name:lower()
      if not Index.remotes[k] then Index.remotes[k] = o end
      if Listen.active then listenRemote(o) end
   end
end

local function indexRemove(o)
   Index.prompts[o] = nil
   Index.clicks[o] = nil
   if Index.remoteSet[o] then
      Index.remoteSet[o] = nil
      local k = o.Name:lower()
      if Index.remotes[k] == o then Index.remotes[k] = nil end
   end
end

-- Один раз и порциями (чтобы не фризить), дальше индекс обновляется событиями
task.spawn(function()
   for _, root in ipairs({ RS, WS }) do
      local n = 0
      for _, o in ipairs(root:GetDescendants()) do
         indexAdd(o)
         n = n + 1
         if n % 2500 == 0 then task.wait() end
      end
   end
   Index.ready = true
end)
for _, root in ipairs({ RS, WS }) do
   table.insert(Connections, root.DescendantAdded:Connect(indexAdd))
   table.insert(Connections, root.DescendantRemoving:Connect(indexRemove))
end

local function isRemote(o)
   return o ~= nil and (o.ClassName == "RemoteEvent" or o.ClassName == "RemoteFunction")
end

local function findRemote(names)
   for _, name in ipairs(names) do
      if name ~= "" then
         if name:find(".", 1, true) then
            local o = resolvePath(name)
            if isRemote(o) then return o end
         end
         local leaf = name:match("([^%.]+)$") or name
         local o = Index.remotes[leaf:lower()]
         if o and o.Parent then return o end
      end
   end
   return nil
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

-- Наблюдение за текстами (для отзывов «дорого»)
local function startLabelWatch()
   if Reviews.watching then return end
   Reviews.watching = true
   local function onAdded(o)
      if o.ClassName ~= "TextLabel" then return end
      local function check()
         if not State.Running or not Reviews.feed then return end
         local t = o.Text
         if t ~= "" and not isOwnGui(o) then Reviews.feed(t, "ui") end
      end
      check()
      o:GetPropertyChangedSignal("Text"):Connect(check)
   end
   table.insert(Connections, Player.PlayerGui.DescendantAdded:Connect(onAdded))
   table.insert(Connections, WS.DescendantAdded:Connect(onAdded))
end

local function refreshListen()
   Listen.active = State.AutoPrice or Listen.record
   if Listen.active then
      for r in pairs(Index.remoteSet) do listenRemote(r) end
      startLabelWatch()
   end
end

-- =====================================================================
-- 6. МОЙ УЧАСТОК (чтобы не ходить по чужим кассам)
-- =====================================================================
local Plot = { root = nil, center = nil, method = "не определён" }

local function myRef(v)
   if v == nil then return false end
   local t = typeof(v)
   if t == "Instance" then return v == Player or (Player.Character ~= nil and v == Player.Character) end
   if t == "number" then return v == Player.UserId end
   if t == "string" then
      local s = v:lower()
      return s == Player.Name:lower() or s == Player.DisplayName:lower() or s == tostring(Player.UserId)
   end
   return false
end

local function otherRef(v)
   if v == nil then return false end
   local t = typeof(v)
   if t == "Instance" then
      if v:IsA("Player") then return v ~= Player end
      if v:IsA("Model") then
         local pl = Players:GetPlayerFromCharacter(v)
         return pl ~= nil and pl ~= Player
      end
      return false
   end
   for _, p in ipairs(Players:GetPlayers()) do
      if p ~= Player then
         if t == "number" and v == p.UserId then return true end
         if t == "string" then
            local s = v:lower()
            if s == p.Name:lower() or s == p.DisplayName:lower() or s == tostring(p.UserId) then return true end
         end
      end
   end
   return false
end

-- "mine" | "other" | nil — по атрибутам и Value-детям (Owner, PlayerName, UserId ...)
local function ownerOf(inst)
   local seenOther = false
   local function check(v)
      if myRef(v) then return true end
      if otherRef(v) then seenOther = true end
      return false
   end
   local okA, attrs = pcall(function() return inst:GetAttributes() end)
   if okA then
      for _, val in pairs(attrs) do
         if check(val) then return "mine" end
      end
   end
   for _, ch in ipairs(inst:GetChildren()) do
      if ch:IsA("ValueBase") then
         local ok, v = pcall(function() return ch.Value end)
         if ok and check(v) then return "mine" end
      end
   end
   if seenOther then return "other" end
   return nil
end

local function nameHasPlayer(name)
   local n = name:lower()
   local a, b = Player.Name:lower(), Player.DisplayName:lower()
   if #a >= 3 and n:find(a, 1, true) then return true end
   if #b >= 3 and n:find(b, 1, true) then return true end
   return false
end

local function instPosition(inst)
   if inst:IsA("ProximityPrompt") or inst:IsA("ClickDetector") then
      local par = inst.Parent
      if par and par:IsA("Attachment") then return par.WorldPosition end
      if par and par:IsA("BasePart") then return par.Position end
      if par and par:IsA("Model") then return par:GetPivot().Position end
      return nil
   elseif inst:IsA("BasePart") then
      return inst.Position
   elseif inst:IsA("Model") then
      return inst:GetPivot().Position
   end
   return nil
end

local function countPrompts(root)
   local n = 0
   for p in pairs(Index.prompts) do
      if p:IsDescendantOf(root) then n = n + 1 end
   end
   return n
end

-- Поднимаемся от объекта к участку: берём самый высокий предок, который содержит не больше 45% всех промптов
local function ascendToPlot(inst)
   local chain = {}
   local cur = inst
   while cur and cur ~= WS do
      if cur:IsA("Model") or cur:IsA("Folder") then chain[#chain + 1] = cur end
      cur = cur.Parent
   end
   if #chain == 0 then return nil end
   local total = 0
   for _ in pairs(Index.prompts) do total = total + 1 end
   local best
   for _, anc in ipairs(chain) do
      if total < 20 or countPrompts(anc) <= total * 0.45 then best = anc end
   end
   return best or chain[1]
end

local function detectPlotByOwner()
   local queue, qi = {}, 1
   for _, ch in ipairs(WS:GetChildren()) do queue[#queue + 1] = { ch, 1 } end
   while qi <= #queue do
      local node, depth = queue[qi][1], queue[qi][2]
      qi = qi + 1
      if (node:IsA("Model") or node:IsA("Folder")) and not Players:GetPlayerFromCharacter(node) then
         if ownerOf(node) == "mine" then return node, "по владельцу" end
         if nameHasPlayer(node.Name) then return node, "по имени" end
         if depth < 4 then
            for _, ch in ipairs(node:GetChildren()) do queue[#queue + 1] = { ch, depth + 1 } end
         end
      end
   end
   return nil
end

local function detectPlotByLabels()
   local n1, n2 = Player.Name:lower(), Player.DisplayName:lower()
   local scanned = 0
   for _, d in ipairs(WS:GetDescendants()) do
      scanned = scanned + 1
      if scanned % 3000 == 0 then task.wait() end
      if d.ClassName == "TextLabel" then
         local t = d.Text:lower()
         if (#n1 >= 3 and t:find(n1, 1, true)) or (#n2 >= 3 and t:find(n2, 1, true)) then
            local model = d:FindFirstAncestorOfClass("Model")
            if model and not Players:GetPlayerFromCharacter(model) then return d end
         end
      end
   end
   return nil
end

local function detectPlotByPosition()
   local hrp = getHRP()
   if not hrp then return nil end
   -- 1) что под ногами
   local params = RaycastParams.new()
   params.FilterType = Enum.RaycastFilterType.Exclude
   params.FilterDescendantsInstances = { Player.Character }
   local res = WS:Raycast(hrp.Position, Vector3.new(0, -60, 0), params)
   if res and res.Instance then
      local r = ascendToPlot(res.Instance)
      if r then return r end
   end
   -- 2) ближайший промпт
   local best, bestD
   for p in pairs(Index.prompts) do
      if p.Parent then
         local pos = instPosition(p)
         if pos then
            local d = (pos - hrp.Position).Magnitude
            if d < 90 and (not bestD or d < bestD) then best, bestD = p, d end
         end
      end
   end
   if best then return ascendToPlot(best) end
   return nil
end

function Plot.set(root, method)
   Plot.root, Plot.method, Plot.center = root, method, nil
   if not root then return end
   local sum, n = Vector3.zero, 0
   for p in pairs(Index.prompts) do
      if p:IsDescendantOf(root) then
         local pos = instPosition(p)
         if pos then
            sum = sum + pos
            n = n + 1
         end
      end
   end
   if n > 0 then
      Plot.center = sum / n
   elseif root:IsA("Model") then
      Plot.center = root:GetPivot().Position
   end
end

-- manual = true: игрок сам сказал «я стою на своём участке»
local function detectPlot(manual)
   if not manual then
      local root, how = detectPlotByOwner()
      if root then
         Plot.set(root, how)
         return true
      end
      local lbl = detectPlotByLabels()
      if lbl then
         local r = ascendToPlot(lbl)
         if r then
            Plot.set(r, "по табличке")
            return true
         end
      end
   end
   local r = detectPlotByPosition()
   if r then
      Plot.set(r, manual and "вручную (по позиции)" or "по позиции — проверь!")
      return true
   end
   return false
end

local function flashPlot()
   if not Plot.root then return false end
   local targets = {}
   if Plot.root:IsA("Model") then
      targets[1] = Plot.root
   else
      for _, ch in ipairs(Plot.root:GetChildren()) do
         if (ch:IsA("Model") or ch:IsA("BasePart")) and #targets < 30 then targets[#targets + 1] = ch end
      end
   end
   for _, t in ipairs(targets) do
      pcall(function()
         local h = Instance.new("Highlight")
         h.FillColor = ACCENT
         h.FillTransparency = 0.6
         h.OutlineColor = GREEN
         h.Adornee = t
         h.Parent = t
         task.delay(4, function() h:Destroy() end)
      end)
   end
   return #targets > 0
end

local mineCache = setmetatable({}, { __mode = "k" })

local function computeMine(inst)
   if not Plot.root or not Plot.root.Parent then
      local c = Plot.center or State.SafePos
      if not c then return false end
      local pos = instPosition(inst)
      return pos ~= nil and (pos - c).Magnitude <= State.PlotRadius
   end
   if inst:IsDescendantOf(Plot.root) then return true end
   local container = Plot.root.Parent
   if container and container ~= WS and inst:IsDescendantOf(container) then return false end -- чужой участок
   -- вне контейнера участков (покупатели, машины, общие объекты): владелец или расстояние
   local node, depth = inst, 0
   while node and node ~= WS and depth < 5 do
      local o = ownerOf(node)
      if o == "mine" then return true end
      if o == "other" then return false end
      node = node.Parent
      depth = depth + 1
   end
   local pos = instPosition(inst)
   return pos ~= nil and Plot.center ~= nil and (pos - Plot.center).Magnitude <= State.PlotRadius
end

local function isMine(inst)
   local e = mineCache[inst]
   local now = os.clock()
   if e and now - e.t < 3 then return e.v end
   local v = computeMine(inst)
   mineCache[inst] = { v = v, t = now }
   return v
end

-- =====================================================================
-- 7. ДВИЖЕНИЕ И АНТИ-СИДЕНИЕ
-- =====================================================================
local lastHop = 0

-- Подходим к объекту, только если он дальше range. Прыжки ограничены по частоте.
local function approach(inst, range)
   if State.MoveMode == "none" then return true end
   local hrp = getHRP()
   local pos = instPosition(inst)
   if not hrp or not pos then return false end
   if (hrp.Position - pos).Magnitude <= range then return true end

   local pause = State.HopCooldown - (os.clock() - lastHop)
   if pause > 0 then task.wait(pause) end
   lastHop = os.clock()

   local away = hrp.Position - pos
   local dir = (away.Magnitude > 0.1) and away.Unit or Vector3.new(0, 0, 1)
   local target = pos + dir * math.min(range * 0.6, 6) + Vector3.new(0, 2.5, 0)

   if State.MoveMode == "walk" then
      local hum = getHumanoid()
      if hum then
         hum:MoveTo(target)
         local t0 = os.clock()
         while State.Running and (hrp.Position - target).Magnitude > range * 0.8 and os.clock() - t0 < 6 do
            task.wait(0.1)
         end
      end
   else
      hrp.CFrame = CFrame.lookAt(target, Vector3.new(pos.X, target.Y, pos.Z))
      hrp.AssemblyLinearVelocity = Vector3.zero
      task.wait(0.05)
   end
   return true
end

local function teleportTo(pos)
   local hrp = getHRP()
   if not hrp or not pos then return false end
   hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
   hrp.AssemblyLinearVelocity = Vector3.zero
   return true
end

local function standUp()
   local hum = getHumanoid()
   if hum and (hum.Sit or hum.SeatPart ~= nil) then
      hum.Sit = false
      pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
      return true
   end
   return false
end

local function isCarrying()
   local c = Player.Character
   return c ~= nil and c:FindFirstChildOfClass("Tool") ~= nil
end

local function applySpeed()
   local hum = getHumanoid()
   if hum then hum.WalkSpeed = State.SpeedEnabled and State.SpeedValue or 16 end
end

-- =====================================================================
-- 8. ДВИЖОК ДЕЙСТВИЙ: промпты ТОЛЬКО на моём участке
-- =====================================================================
local lastUiScan = 0
local lastFired = setmetatable({}, { __mode = "k" })
local classCache = setmetatable({}, { __mode = "k" })

local function markSuccess()
   State.LastSuccess = os.clock()
   State.TotalActions = State.TotalActions + 1
   if State.AutoFarm then State.FarmActions = State.FarmActions + 1 end
end

local function promptText(p, withParent)
   local s = p.ActionText .. " " .. p.ObjectText .. " " .. p.Name
   if withParent and p.Parent then s = s .. " " .. p.Parent.Name end
   return s:lower()
end

local function classify(p)
   local e = classCache[p]
   local now = os.clock()
   if e and now - e.t < 1.5 then return e.v end
   local v = nil
   if not matchesAny(promptText(p, false), GlobalExclude) then
      local text = promptText(p, true)
      for _, key in ipairs(CatOrder) do
         if matchesAny(text, CatKW[key]) then
            v = key
            break
         end
      end
   end
   classCache[p] = { v = v, t = now }
   return v
end

-- Промпты категории на моём участке, ближайшие первыми
local function candidates(cat, requireEnabled)
   local list = {}
   local hrp = getHRP()
   local origin = hrp and hrp.Position
   for p in pairs(Index.prompts) do
      if p.Parent and (not requireEnabled or p.Enabled) and classify(p) == cat and isMine(p) then
         local pos = instPosition(p)
         list[#list + 1] = { p = p, d = (origin and pos) and (pos - origin).Magnitude or 0 }
      end
   end
   table.sort(list, function(a, b) return a.d < b.d end)
   return list
end

local function usablePrompt(p, cooldown)
   if not p.Parent or not p.Enabled then return false end
   local t = lastFired[p]
   if t and os.clock() - t < cooldown then return false end
   return true
end

local function firePromptSmart(p)
   local range = math.max((p.MaxActivationDistance or 10) - 1.5, 3)
   approach(p, range)
   if State.Humanize then task.wait(0.03 + math.random() * 0.1) end
   State.Firing = true
   local ok = firePrompt(p)
   State.Firing = false
   lastFired[p] = os.clock()
   return ok
end

-- Выполнить до maxN промптов категории. Возвращает (успех, сколько_нажато)
local function promptTask(cat, maxN, cooldown)
   local did, fired = false, 0
   for _, c in ipairs(candidates(cat, true)) do
      if fired >= maxN then break end
      if usablePrompt(c.p, cooldown) then
         State.Status = Actions[cat].label
         if firePromptSmart(c.p) then
            did = true
            markSuccess()
         end
         fired = fired + 1
         task.wait(0.12)
      end
   end
   return did, fired
end

local function tryBound(key)
   local bind = Binds[key]
   if not bind or bind.remote == "" then return false end
   local r = findRemote({ bind.remote })
   if not r then return false end
   if callRemote(r, parseArgs(bind.args)) then
      State.Status = Actions[key].label
      markSuccess()
      return true
   end
   return false
end

-- Если после промпта открылось меню — пробуем нажать подтверждение
local function uiFollowUp(keywords)
   if os.clock() - lastUiScan < 3 then return false end
   lastUiScan = os.clock()
   local btn = findButton(keywords)
   if btn and clickGui(btn) then
      markSuccess()
      return true
   end
   return false
end

-- Обслуживание: погрузка → касса → помощь → взять дерево
local function serveStep()
   local budget = State.MaxPerTick
   for _, cat in ipairs({ "load", "checkout", "help", "pickup" }) do
      if budget <= 0 then break end
      if not (cat == "pickup" and isCarrying()) then
         if tryBound(cat) then
            budget = budget - 1
         else
            local _, fired = promptTask(cat, budget, State.PromptCooldown)
            budget = budget - fired
         end
      end
   end
end

local function placeStep()
   if tryBound("place") then return end
   promptTask("place", 2, 1.5)
end

local function orderStep()
   if tryBound("order") then return end
   local did = promptTask("order", 1, State.OrderInterval * 0.8)
   if did then
      task.wait(0.6)
      uiFollowUp({ "confirm", "order", "buy", "purchase", State.SelectedTree:lower() })
   end
end

local function slowStep(cat)
   if tryBound(cat) then return end
   local did = promptTask(cat, 1, State.SlowInterval * 0.8)
   if did then
      task.wait(0.5)
      uiFollowUp({ "confirm", "yes", cat })
   end
end

local function rewardStep()
   if tryBound("reward") then return end
   local r = findRemote({ "ClaimReward", "ClaimDaily", "DailyReward", "ClaimGift" })
   if r and callRemote(r) then
      markSuccess()
      return
   end
   promptTask("reward", 1, 30)
end

local function decorStep()
   local did = false
   if tryBound("decor") then
      did = true
   else
      did = promptTask("decor", 2, 3)
   end
   if did then State.DecorActions = State.DecorActions + 1 end
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

local function farmStep()
   if State.AutoServe and due("serve", State.CycleDelay) then serveStep() end
   if State.AutoPlace and due("place", 2.5) then placeStep() end
   if State.AutoOrder and due("order", State.OrderInterval) then orderStep() end
   if State.AutoCollect and due("collect", 3) then promptTask("collect", 2, 2) end
   if State.AutoHire and due("hire", State.SlowInterval) then slowStep("hire") end
   if State.AutoUpgrade and due("upgrade", State.SlowInterval) then slowStep("upgrade") end
   if State.AutoReward and due("reward", 60) then rewardStep() end
end

-- Одно действие по кнопке «проверить»
local function runOnce(key)
   if tryBound(key) then return true, "привязка" end
   if Actions[key].noPrompt then return false, "нужна привязка (Spy)" end
   local did, fired = promptTask(key, 1, 0)
   if did then return true, "промпт" end
   if fired > 0 then return false, "промпт нажат, но не сработал" end
   return false, "на участке нет подходящих промптов"
end

-- =====================================================================
-- 9. ЦЕНА И ОТЗЫВЫ («слишком дорого» → снизить цену)
-- =====================================================================
local ExpensiveKW = { "too expensive", "expensive", "pricey", "overpriced", "too high", "price is high", "rip off", "ripoff", "costly", "too much", "дорого" }

local function isExpensiveText(s)
   return matchesAny(s:lower(), ExpensiveKW)
end

local function setPriceViaUI(price)
   for _, o in ipairs(Player.PlayerGui:GetDescendants()) do
      if o:IsA("TextBox") and o.Visible and not isOwnGui(o) then
         local label = (o.Name .. " " .. (o.PlaceholderText or "")):lower()
         if label:find("price", 1, true) then
            o.Text = tostring(price)
            if type(firesignal) == "function" then pcall(firesignal, o.FocusLost, true) end
            return true
         end
      end
   end
   return false
end

local function applyPrice(newPrice)
   local bind = Binds.price
   if bind and bind.remote ~= "" then
      local r = findRemote({ bind.remote })
      if r then
         return callRemote(r, parseArgs(bind.args, { price = newPrice }))
      end
   end
   return setPriceViaUI(newPrice)
end

local function handleExpensive(text)
   local newP
   if State.NormalPrice > 0 then
      newP = State.NormalPrice
   else
      local cur = Price.value
      if not cur or cur <= 0 then
         notify("Отзыв «дорого»", "Не знаю текущую цену: привяжи «Цена» через Spy или задай нормальную цену.", 8, "price_unknown", 60)
         return
      end
      newP = cur * (1 - State.PriceStep / 100)
      if Price.base then newP = math.max(newP, Price.base * State.PriceMinPct / 100) end
   end
   newP = math.max(1, math.floor(newP + 0.5))
   if applyPrice(newP) then
      Price.value = newP
      notify("💲 Цена снижена", ("Отзыв «%s» → цена %s"):format(text:sub(1, 40), fmtNum(newP)), 6, "price_ok", 5)
   else
      notify("Не удалось сменить цену", "Привяжи действие «Цена» (вкладка «Правила»).", 8, "price_fail", 60)
   end
end

function Reviews.feed(text, source)
   if not State.Running or type(text) ~= "string" or #text > 200 then return end
   local now = os.clock()
   if text == Reviews.lastText and now - Reviews.lastTextAt < 5 then return end
   local low = text:lower()
   if low:find("review", 1, true) or low:find("star", 1, true) then
      Reviews.seen[#Reviews.seen + 1] = text
      if #Reviews.seen > 20 then table.remove(Reviews.seen, 1) end
   end
   if not isExpensiveText(text) then return end
   Reviews.lastText, Reviews.lastTextAt = text, now
   Reviews.log[#Reviews.log + 1] = { t = now, text = text, src = source }
   if #Reviews.log > 30 then table.remove(Reviews.log, 1) end
   if State.AutoPrice and now - Reviews.lastHandled > State.PriceCooldown then
      Reviews.lastHandled = now
      task.spawn(handleExpensive, text)
   end
end

-- =====================================================================
-- 10. STATS (деньги / репутация) И ГЛАВНЫЙ ПЕРЕКЛЮЧАТЕЛЬ
-- =====================================================================
local STAT_KW = {
   cash = { "cash", "money", "coin", "dollar", "buck", "balance" },
   rep = { "reputation" },
}

local function statMatches(kind, name, override)
   local n = name:lower()
   if override and override ~= "" then return n == override:lower() end
   return matchesAny(n, STAT_KW[kind])
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
      if not (Plot.root and Plot.root.Parent) then
         notify("⚠️ Участок не найден", "Без него скрипт ничего не нажмёт. «Главная» → «Это мой участок».", 8, "plot_warn", 30)
      end
   else
      State.Status = "Остановлено"
      notify("Автофарм", "Остановлен.", 3, "farm")
   end
end

-- =====================================================================
-- 11. HUD (мини-панель, перетаскивается) и окно «Подпишитесь на канал»
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
-- 12. SPY, TEACH, СКАНЕР, СЕРВИС
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

-- Кодируем аргумент в JSON-совместимый вид. Возвращает (значение, были_проблемы)
local function encodeArg(v, depth)
   depth = depth or 0
   if depth > 4 then return nil, true end
   local t = typeof(v)
   if t == "string" then
      for _, tree in ipairs(TreeNames) do
         if tree:lower() == v:lower() then return "{tree}", false end
      end
      return v, false
   elseif t == "number" or t == "boolean" then
      return v, false
   elseif t == "Instance" then
      if v == Player then return "{player}", false end
      return { __inst = v:GetFullName() }, false
   elseif t == "Vector3" then
      return { __v3 = { v.X, v.Y, v.Z } }, false
   elseif t == "CFrame" then
      return { __cf = { v:GetComponents() } }, false
   elseif t == "table" then
      local out, bad = {}, false
      local isArray = (#v > 0)
      for k, x in pairs(v) do
         local ev, vbad = encodeArg(x, depth + 1)
         if vbad then bad = true end
         if (type(k) == "number" and isArray) or type(k) == "string" then
            out[k] = ev
         else
            bad = true
         end
      end
      return out, bad
   end
   return nil, true
end

-- Строка привязки из записи Spy: "Путь | аргументы". priceMode — последнее число станет {price}
local function formatCall(rec, priceMode)
   local list, bad = {}, false
   for i = 1, rec.args.n do
      local e, b = encodeArg(rec.args[i], 0)
      if b then bad = true end
      if e == nil then
         bad = true
      else
         list[#list + 1] = e
      end
   end
   if priceMode then
      for i = #list, 1, -1 do
         if type(list[i]) == "number" then
            Price.value, Price.base = list[i], list[i]
            list[i] = "{price}"
            break
         end
      end
   end
   local complex = false
   for _, e in ipairs(list) do
      if type(e) == "table" or (type(e) == "string" and e:find("[,|]")) then complex = true end
   end
   local path = rec.remote:GetFullName()
   if complex then
      local ok, json = pcall(function() return HttpService:JSONEncode(list) end)
      if ok then return path .. " | " .. json, bad end
   end
   local toks = {}
   for _, e in ipairs(list) do toks[#toks + 1] = tostring(e) end
   return path .. " | " .. table.concat(toks, ", "), bad
end

local function spyJournalText()
   if #Spy.Log == 0 then return "Журнал пуст. Включи Spy и сделай действие в игре руками." end
   local lines = {}
   for i = math.max(1, #Spy.Log - 11), #Spy.Log do
      local rec = Spy.Log[i]
      local toks = {}
      for j = 1, rec.args.n do toks[#toks + 1] = summarizeArg(rec.args[j]) end
      lines[#lines + 1] = ("%d) %s | %s"):format(i, rec.remote.Name, table.concat(toks, ", "))
   end
   return table.concat(lines, "\n")
end

-- Teach: запоминаем промпты, которые игрок нажал РУКАМИ
local Teach = { enabled = false, log = {} }
table.insert(Connections, PPS.PromptTriggered:Connect(function(prompt, plr)
   if not Teach.enabled or plr ~= Player or State.Firing then return end
   Teach.log[#Teach.log + 1] = prompt
   if #Teach.log > 30 then table.remove(Teach.log, 1) end
end))

local function teachJournalText()
   if #Teach.log == 0 then return "Пусто. Включи запись и нажми нужный объект в игре руками." end
   local lines = {}
   for i = math.max(1, #Teach.log - 11), #Teach.log do
      local p = Teach.log[i]
      lines[#lines + 1] = ("%d) %s | %s | %s → %s"):format(
         i, p.ActionText, p.ObjectText, p.Parent and p.Parent.Name or "?", classify(p) or "?")
   end
   return table.concat(lines, "\n")
end

-- Добавляем слово из выбранного промпта в правила категории (через поле во вкладке «Правила»)
local CatInputs = {}
local function teachBind(cat, idx)
   local p = Teach.log[idx or #Teach.log]
   if not p then return false, "журнал пуст" end
   local token = (p.ActionText ~= "" and p.ActionText) or (p.ObjectText ~= "" and p.ObjectText) or p.Name
   token = token:lower():gsub("^%s+", ""):gsub("%s+$", "")
   for _, kw in ipairs(CatKW[cat]) do
      if kw == token then return true, "слово уже есть: " .. token end
   end
   local input = CatInputs[cat]
   if not input then return false, "для этой категории нет правила" end
   input:Set(table.concat(CatKW[cat], ", ") .. ", " .. token)
   return true, "добавлено слово: " .. token
end

-- Отчёт по моим промптам: что нашлось на участке и как классифицировалось
local function plotPromptReport()
   local groups, order, total, mine = {}, {}, 0, 0
   for p in pairs(Index.prompts) do
      total = total + 1
      if p.Parent and isMine(p) then
         mine = mine + 1
         local key = (classify(p) or "?") .. " | " .. p.ActionText .. " | " .. p.ObjectText
         if not groups[key] then
            groups[key] = { n = 0, example = p:GetFullName() }
            order[#order + 1] = key
         end
         groups[key].n = groups[key].n + 1
      end
   end
   table.sort(order)
   local summary = { ("Промптов на моём участке: %d (в мире: %d)"):format(mine, total) }
   local full = { summary[1] }
   for i, key in ipairs(order) do
      local g = groups[key]
      local line = ("%s ×%d"):format(key, g.n)
      if i <= 30 then summary[#summary + 1] = line end
      full[#full + 1] = line .. "  [" .. g.example .. "]"
   end
   return table.concat(summary, "\n"), table.concat(full, "\n")
end

-- Скан remote: полный отчёт + похожие по действиям
local function scanGame()
   local rem = {}
   for r in pairs(Index.remoteSet) do rem[#rem + 1] = r end
   table.sort(rem, function(a, b) return a:GetFullName() < b:GetFullName() end)

   local report = { ("PlaceId: %s | Executor: %s"):format(tostring(game.PlaceId), Executor.Name), "", "== REMOTES ==" }
   for i = 1, math.min(#rem, 500) do
      report[#report + 1] = ("[%s] %s"):format(rem[i].ClassName, rem[i]:GetFullName())
   end

   local summary = { ("Remote: %d"):format(#rem) }
   for _, key in ipairs(ActionKeys) do
      local hits = {}
      for _, r in ipairs(rem) do
         if #CatKW[key] > 0 and matchesAny(r.Name:lower(), CatKW[key]) then
            hits[#hits + 1] = r.Name
            if #hits >= 3 then break end
         end
      end
      summary[#summary + 1] = Actions[key].label .. ": " .. (#hits > 0 and table.concat(hits, ", ") or "—")
   end
   return table.concat(summary, "\n"), table.concat(report, "\n")
end

local function capsReport()
   local names = {
      "fireproximityprompt", "fireclickdetector", "firesignal", "getconnections",
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
   local candidates2 = {}
   for _, s in ipairs(data.data) do
      if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
         candidates2[#candidates2 + 1] = s
      end
   end
   if #candidates2 == 0 then return false, "нет подходящих серверов" end
   local pick = candidates2[math.random(1, #candidates2)]
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
-- 13. UI
-- =====================================================================
local L_Plot, L_Status, L_Cash, L_Income, L_Rep, L_Actions, L_Time
local DecorLabel
local BindInputs = {}
local SpyToggle

local MoveLabels = { "Телепорт рядом", "Пешком", "Не двигаться" }
local MoveKeys = { ["Телепорт рядом"] = "teleport", ["Пешком"] = "walk", ["Не двигаться"] = "none" }

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

HomeTab:CreateSection("Мой участок (важно!)")
L_Plot = HomeTab:CreateLabel("🏠 Участок: ищу...")
HomeTab:CreateButton({
   Name = "📍 Это мой участок (я стою на нём)",
   Callback = function()
      if detectPlot(true) then
         notify("🏠 Участок задан", Plot.root:GetFullName(), 7, "plot")
         flashPlot()
      else
         notify("Не получилось", "Подойди ближе к своей кассе и повтори.", 5, "plot")
      end
   end,
})
HomeTab:CreateButton({
   Name = "🔎 Найти участок заново (по владельцу/табличке)",
   Callback = function()
      task.spawn(function()
         if detectPlot(false) then
            notify("🏠 Участок найден", Plot.method .. ": " .. Plot.root:GetFullName(), 7, "plot")
            flashPlot()
         else
            notify("Не найден", "Встань на свой участок и нажми «Это мой участок».", 6, "plot")
         end
      end)
   end,
})
HomeTab:CreateButton({
   Name = "💡 Подсветить найденный участок",
   Callback = function()
      if not flashPlot() then notify("Участок не задан", "Сначала найди или задай участок.", 4, "plot") end
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
FarmTab:CreateToggle({ Name = "Авто-обслуживание (погрузка, касса, помощь)", CurrentValue = true, Flag = "AutoServe", Callback = function(v) State.AutoServe = v end })
FarmTab:CreateToggle({ Name = "Авто-расстановка деревьев", CurrentValue = true, Flag = "AutoPlace", Callback = function(v) State.AutoPlace = v end })
FarmTab:CreateToggle({ Name = "Авто-найм работников", CurrentValue = true, Flag = "AutoHire", Callback = function(v) State.AutoHire = v end })
FarmTab:CreateToggle({ Name = "Авто-апгрейд HQ и расширение участка", CurrentValue = true, Flag = "AutoUpgrade", Callback = function(v) State.AutoUpgrade = v end })
FarmTab:CreateToggle({ Name = "Авто-награды (раз в минуту)", CurrentValue = true, Flag = "AutoReward", Callback = function(v) State.AutoReward = v end })
FarmTab:CreateToggle({ Name = "Авто-сбор денег/предметов", CurrentValue = false, Flag = "AutoCollect", Callback = function(v) State.AutoCollect = v end })
FarmTab:CreateToggle({
   Name = "Авто-цена: снижать при отзывах «дорого»",
   CurrentValue = false,
   Flag = "AutoPrice",
   Callback = function(v)
      State.AutoPrice = v
      refreshListen()
   end,
})

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
   Name = "Пауза обслуживания клиентов",
   Range = { 0.3, 5 }, Increment = 0.1, Suffix = " сек", CurrentValue = 1.0, Flag = "CycleDelay",
   Callback = function(v) State.CycleDelay = v end,
})
FarmTab:CreateSlider({
   Name = "Интервал заказа деревьев",
   Range = { 10, 300 }, Increment = 5, Suffix = " сек", CurrentValue = 40, Flag = "OrderInterval",
   Callback = function(v) State.OrderInterval = v end,
})
FarmTab:CreateSlider({
   Name = "Интервал найма / апгрейдов",
   Range = { 5, 180 }, Increment = 5, Suffix = " сек", CurrentValue = 20, Flag = "SlowInterval",
   Callback = function(v) State.SlowInterval = v end,
})
FarmTab:CreateToggle({
   Name = "Человеческий разброс задержек",
   CurrentValue = true, Flag = "Humanize",
   Callback = function(v) State.Humanize = v end,
})

FarmTab:CreateSection("Движение (меньше полётов = меньше лагов)")
FarmTab:CreateDropdown({
   Name = "Как подходить к объектам",
   Options = MoveLabels,
   CurrentOption = { "Телепорт рядом" },
   MultipleOptions = false,
   Flag = "MoveMode",
   Callback = function(opt)
      local label = (type(opt) == "table" and opt[1]) or opt
      State.MoveMode = MoveKeys[label] or "teleport"
   end,
})
FarmTab:CreateSlider({
   Name = "Пауза между перемещениями",
   Range = { 0.2, 3 }, Increment = 0.1, Suffix = " сек", CurrentValue = 0.6, Flag = "HopCooldown",
   Callback = function(v) State.HopCooldown = v end,
})
FarmTab:CreateSlider({
   Name = "Действий за один цикл",
   Range = { 1, 5 }, Increment = 1, Suffix = "", CurrentValue = 2, Flag = "MaxPerTick",
   Callback = function(v) State.MaxPerTick = v end,
})
FarmTab:CreateSlider({
   Name = "Радиус участка (для покупателей вне участка)",
   Range = { 60, 400 }, Increment = 10, Suffix = " studs", CurrentValue = 160, Flag = "PlotRadius",
   Callback = function(v) State.PlotRadius = v end,
})

FarmTab:CreateSection("Авто-цена")
FarmTab:CreateInput({
   Name = "Нормальная цена (пусто = снижать шагом)",
   CurrentValue = "",
   PlaceholderText = "например 45",
   RemoveTextAfterFocusLost = false,
   Flag = "NormalPrice",
   Callback = function(text) State.NormalPrice = tonumber(text) or 0 end,
})
FarmTab:CreateSlider({
   Name = "Шаг снижения цены",
   Range = { 3, 40 }, Increment = 1, Suffix = " %", CurrentValue = 10, Flag = "PriceStep",
   Callback = function(v) State.PriceStep = v end,
})
FarmTab:CreateSlider({
   Name = "Не опускать ниже",
   Range = { 20, 100 }, Increment = 5, Suffix = " % от базовой", CurrentValue = 60, Flag = "PriceMinPct",
   Callback = function(v) State.PriceMinPct = v end,
})
FarmTab:CreateButton({
   Name = "💲 Применить цену сейчас (проверка)",
   Callback = function()
      local p = (State.NormalPrice > 0 and State.NormalPrice) or Price.value
      if not p then
         notify("Нет цены", "Задай нормальную цену или привяжи «Цена» через Spy.", 5, "price_test")
         return
      end
      local ok = applyPrice(p)
      notify(ok and "Цена отправлена" or "Не удалось", tostring(p), 4, "price_test")
   end,
})

-- АВТО-БАЗА
local DecorTab = Window:CreateTab("🏠 Авто-База", "hammer")
DecorTab:CreateSection("Украшение")
DecorTab:CreateParagraph({ Title = "Авто-декор", Content = "Жмёт промпты декора на твоём участке. Слова поиска меняются во вкладке «Правила»." })
DecorLabel = DecorTab:CreateLabel("Действий с декором: 0")
DecorTab:CreateToggle({
   Name = "🛠️ Авто-декор",
   CurrentValue = false,
   Callback = function(v)
      State.AutoDecor = v
      if v then
         playSound("9118823103")
         notify("Авто-База", "Начинаю украшать участок!", 3, "decor")
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
      local ok, how = runOnce(State.TestTarget)
      if ok then
         notify("✅ Сработало", Actions[State.TestTarget].label .. " — " .. how, 5, "test")
      else
         notify("❌ Не сработало", how, 7, "test")
      end
   end,
})

DiagTab:CreateSection("Что есть на моём участке")
local PromptInfo = DiagTab:CreateParagraph({ Title = "Промпты участка", Content = "Нажми кнопку ниже." })
local lastPromptReport = ""
DiagTab:CreateButton({
   Name = "🔍 Показать промпты моего участка",
   Callback = function()
      local summary, full = plotPromptReport()
      lastPromptReport = full
      PromptInfo:Set({ Title = "Промпты участка (категория | действие | объект)", Content = summary })
   end,
})
DiagTab:CreateButton({
   Name = "📋 Копировать полный список промптов",
   Callback = function()
      if lastPromptReport == "" then
         notify("Пусто", "Сначала нажми «Показать промпты моего участка».", 3, "pr")
      elseif type(setclipboard) == "function" then
         pcall(setclipboard, lastPromptReport)
         notify("Готово", "Список скопирован в буфер.", 3, "pr")
      else
         notify("Нет буфера", "Твой executor не поддерживает setclipboard.", 4, "pr")
      end
   end,
})

DiagTab:CreateSection("Обучение: покажи скрипту, что нажимать")
DiagTab:CreateParagraph({
   Title = "Как пользоваться",
   Content = "1) Включи запись. 2) Нажми в игре РУКАМИ нужный объект (например, погрузку дерева в машину). 3) «Показать журнал», выбери категорию и «Запомнить». Скрипт добавит слово в правила.",
})
DiagTab:CreateToggle({
   Name = "🎓 Запись моих нажатий на промпты",
   CurrentValue = false,
   Callback = function(v) Teach.enabled = v end,
})
local TeachView = DiagTab:CreateParagraph({ Title = "Журнал нажатий", Content = "Пусто" })
DiagTab:CreateButton({
   Name = "🔄 Показать журнал нажатий",
   Callback = function()
      TeachView:Set({ Title = "Журнал нажатий (→ категория)", Content = teachJournalText() })
   end,
})
DiagTab:CreateDropdown({
   Name = "Запомнить для категории",
   Options = ActionLabels,
   CurrentOption = { Actions.pickup.label },
   MultipleOptions = false,
   Callback = function(opt)
      local label = (type(opt) == "table" and opt[1]) or opt
      State.TeachCat = LabelToKey[label] or State.TeachCat
   end,
})
DiagTab:CreateInput({
   Name = "№ записи (пусто = последняя)",
   CurrentValue = "",
   PlaceholderText = "например 2",
   RemoveTextAfterFocusLost = false,
   Callback = function(text) State.Pick = text end,
})
DiagTab:CreateButton({
   Name = "🎯 Запомнить выбранное нажатие",
   Callback = function()
      local ok, msg = teachBind(State.TeachCat, tonumber(State.Pick))
      notify(ok and "✅ Готово" or "❌ Не получилось", msg, 5, "teach")
   end,
})

DiagTab:CreateSection("Сканер remote")
local ScanInfo = DiagTab:CreateParagraph({ Title = "Результат", Content = "Нажми «Сканировать remote»." })
local lastReport = ""
DiagTab:CreateButton({
   Name = "🔍 Сканировать remote",
   Callback = function()
      local summary, report = scanGame()
      lastReport = report
      ScanInfo:Set({ Title = "Похожие remote по действиям", Content = summary })
   end,
})
DiagTab:CreateButton({
   Name = "📋 Копировать список remote",
   Callback = function()
      if lastReport == "" then
         notify("Пусто", "Сначала нажми «Сканировать remote».", 3, "scan")
      elseif type(setclipboard) == "function" then
         pcall(setclipboard, lastReport)
         notify("Готово", "Список скопирован в буфер.", 3, "scan")
      else
         notify("Нет буфера", "Твой executor не поддерживает setclipboard.", 4, "scan")
      end
   end,
})

DiagTab:CreateSection("Remote Spy — подсмотреть вызовы игры")
DiagTab:CreateParagraph({
   Title = "Как пользоваться",
   Content = "1) Включи Spy. 2) Сделай действие в игре руками (закажи деревья, поменяй цену, найми). 3) «Показать журнал», выбери действие и «Привязать». Для «Цены» последнее число в вызове станет {price}.",
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
      local text, warn = formatCall(rec, State.BindTarget == "price")
      BindInputs[State.BindTarget]:Set(text)
      if warn then
         notify("Привязано с оговоркой", "Часть аргументов не поддерживается. Проверь строку во вкладке «Правила».", 7, "bind")
      else
         notify("✅ Привязано", Actions[State.BindTarget].label, 5, "bind")
      end
   end,
})

DiagTab:CreateSection("События сервера и отзывы")
DiagTab:CreateToggle({
   Name = "📡 Слушать сообщения сервера",
   CurrentValue = false,
   Callback = function(v)
      Listen.record = v
      refreshListen()
   end,
})
local ServerView = DiagTab:CreateParagraph({ Title = "События сервера и отзывы", Content = "Пусто" })
DiagTab:CreateButton({
   Name = "🔄 Показать события и отзывы",
   Callback = function()
      local lines = {}
      for i = math.max(1, #Listen.log - 9), #Listen.log do lines[#lines + 1] = Listen.log[i] end
      lines[#lines + 1] = "— отзывы «дорого» —"
      for i = math.max(1, #Reviews.log - 4), #Reviews.log do lines[#lines + 1] = Reviews.log[i].text end
      lines[#lines + 1] = "— тексты про review/star —"
      for i = math.max(1, #Reviews.seen - 4), #Reviews.seen do lines[#lines + 1] = Reviews.seen[i] end
      ServerView:Set({ Title = "События сервера и отзывы", Content = table.concat(lines, "\n") })
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

-- ПРАВИЛА
local RulesTab = Window:CreateTab("🧩 Правила", "list-checks")
RulesTab:CreateSection("Слова для поиска промптов (через запятую)")
for _, key in ipairs(CatOrder) do
   CatInputs[key] = RulesTab:CreateInput({
      Name = Actions[key].label,
      CurrentValue = Actions[key].kw,
      PlaceholderText = "через запятую",
      RemoveTextAfterFocusLost = false,
      Flag = "KW_" .. key,
      Callback = function(text)
         CatKW[key] = parseKeywords(text)
         table.clear(classCache)
      end,
   })
end

RulesTab:CreateSection("Привязки (формат: Remote | аргументы)")
RulesTab:CreateParagraph({
   Title = "Формат",
   Content = "Пример: ReplicatedStorage.Remotes.OrderTrees | [{\"Pine\":5}]\nМожно писать аргументы через запятую или JSON-массивом. Токены: {tree}, {player}, {price}. Пусто = без привязки.",
})
for _, key in ipairs(ActionKeys) do
   BindInputs[key] = RulesTab:CreateInput({
      Name = Actions[key].label,
      CurrentValue = "",
      PlaceholderText = "Remote | аргументы",
      RemoveTextAfterFocusLost = false,
      Flag = "Bind_" .. key,
      Callback = function(text)
         local remote, args = parseBinding(text)
         Binds[key] = { remote = remote, args = args }
      end,
   })
end
RulesTab:CreateButton({
   Name = "🧹 Сбросить все привязки",
   Callback = function()
      for _, key in ipairs(ActionKeys) do BindInputs[key]:Set("") end
      notify("Готово", "Все привязки сброшены.", 3, "bind")
   end,
})

-- ИГРОК
local PlayerTab = Window:CreateTab("🏃 Игрок", "user")
PlayerTab:CreateSection("Движение")
PlayerTab:CreateToggle({
   Name = "🪑 Вставать со скамейки/сидений",
   CurrentValue = true, Flag = "AntiSit",
   Callback = function(v) State.AntiSit = v end,
})
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

PlayerTab:CreateSection("Телепорты (только по моему участку)")
PlayerTab:CreateButton({
   Name = "💰 К моей кассе",
   Callback = function()
      local list = candidates("checkout", false)
      if #list > 0 then teleportTo(instPosition(list[1].p)) else notify("Не найдено", "Касса на участке не найдена.", 3, "tp") end
   end,
})
PlayerTab:CreateButton({
   Name = "🚚 К заказу деревьев",
   Callback = function()
      local list = candidates("order", false)
      if #list > 0 then teleportTo(instPosition(list[1].p)) else notify("Не найдено", "Заказ на участке не найден.", 3, "tp") end
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
-- 14. UI REFRESH, CONNECTIONS, LOOPS
-- =====================================================================
local lastPlotRetry = 0

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

   if Plot.root and Plot.root.Parent then
      L_Plot:Set("🏠 Участок: " .. Plot.root.Name .. " (" .. Plot.method .. ")")
   else
      L_Plot:Set("⚠️ Участок не найден — встань на свой и нажми «Это мой участок»")
   end
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
         notify("⚠️ Нет успешных действий", "Скрипт не находит, что нажимать. «Диагностика» → «Показать промпты моего участка».", 8, "wd_idle", 300)
      end
   end

   -- Участок пропал (перезашёл/пересоздан) — ищем снова, не чаще раза в 20 сек
   if Index.ready and not (Plot.root and Plot.root.Parent) and now - lastPlotRetry > 20 then
      lastPlotRetry = now
      task.spawn(function() detectPlot(false) end)
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

local function hookCharacter(char)
   local hum = char:WaitForChild("Humanoid", 10)
   if not hum then return end
   table.insert(Connections, hum:GetPropertyChangedSignal("Sit"):Connect(function()
      if State.AntiSit and hum.Sit then
         task.wait(0.15)
         standUp()
      end
   end))
end

table.insert(Connections, Player.CharacterAdded:Connect(function(char)
   task.wait(0.5)
   if State.SpeedEnabled then applySpeed() end
   hookCharacter(char)
end))
if Player.Character then task.spawn(hookCharacter, Player.Character) end

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

-- Старт: безопасная точка и поиск моего участка
task.spawn(function()
   local t0 = os.clock()
   while State.Running and not Index.ready and os.clock() - t0 < 30 do task.wait(0.3) end
   while State.Running and not getHRP() and os.clock() - t0 < 40 do task.wait(0.3) end
   task.wait(1.5)
   if not State.Running then return end
   local hrp = getHRP()
   if hrp and not State.SafePos then State.SafePos = hrp.Position end
   if detectPlot(false) then
      notify("🏠 Участок найден", Plot.method .. ": " .. Plot.root.Name, 7, "plot")
   else
      notify("⚠️ Участок не найден", "Встань на свой участок и нажми «Главная» → «Это мой участок».", 10, "plot")
   end
end)

-- Главный цикл (каждая итерация под pcall — одна ошибка не убьёт цикл)
task.spawn(function()
   while State.Running do
      task.wait(0.25)
      local ok, err = pcall(function()
         if State.AntiSit then standUp() end
         local hum = getHumanoid()
         if not hum or hum.Health <= 0 then
            if State.AutoFarm or State.AutoDecor then State.Status = "Ждём респавн..." end
            return
         end
         if State.AutoFarm then farmStep() end
         if State.AutoDecor and due("decor", 6) then decorStep() end
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
-- 15. UNLOAD & START
-- =====================================================================
local function Unload()
   State.Running = false
   State.AutoFarm, State.AutoDecor = false, false
   Spy.Enabled = false
   Teach.enabled = false
   if State.AfkSaver then setAfkSaver(false) end
   for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
   for _, c in pairs(Listen.hooked) do pcall(function() c:Disconnect() end) end
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
notify("❄️ Winter Magic", "CheatHub v10 загружен! Меню: клавиша K, автофарм: F6.", 6, "loaded")