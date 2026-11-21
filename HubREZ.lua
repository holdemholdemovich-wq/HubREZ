-- ============================================================
-- HubREZ — хаб скриптов (Games / Favorites / Execute / About)
-- Запускать в исполнителе (Delta и др.). Телефон + ПК.
-- ============================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera or workspace:WaitForChild("Camera")

-- если хаб уже запущен, сначала полностью выгружаем старую копию (иначе её циклы, например Fly, продолжат работать)
local genv = (getgenv and getgenv()) or _G
if typeof(genv.HubREZ_Unload) == "function" then pcall(genv.HubREZ_Unload) end
genv.HubREZ_Unload = nil

---------------------------------------------------------------- НАСТРОЙКИ ХАБА
-- 1) Залей скрипты на GitHub и впиши СВОЙ ник и репозиторий:
local GITHUB_RAW = "https://raw.githubusercontent.com/holdemholdemovich-wq/HubREZ/main/"

-- 2) (по желанию) ссылка на файл со списком игр, чтобы добавлять игры без правки хаба.
--    Файл должен возвращать такую же таблицу, как GAMES ниже: return { {...}, {...} }
local GAMES_LIST_URL = GITHUB_RAW .. "games.lua"  -- список игр лежит в репозитории

-- 3) Запасной список игр (копия games.lua). Основной список хаб берёт из games.lua в репозитории.
local GAMES = {
	{
		name = "The Button",
		sub = "TheButtonREZ  ·  ESP",
		file = "TheButtonREZ_menu.lua",
		icon = "gameimages/thebutton.png",
		guiName = "TheButtonREZ",
		status = "ok", -- "ok" = работает, "updating" = временно обновляется
		placeId = 107828406309109,
		about = "TheButtonREZ — меню для игры The Button.\n\nЧто умеет:\n• ESP: боксы, трейсеры, ники, здоровье, дистанция, скелет\n• Стрелки-указатели на игроков за экраном\n• Настройка цветов, толщины линий и дальности\n• Работает на телефоне и ПК, сворачивается в кружок\n\nМеню открывается после нажатия Execute.\n\n✔ Пока без банов — следим за обновлениями игры\n✔ Скрипт регулярно проходит проверку на чистоту\n\n<font color=\"#6b6b85\" size=\"11\">За слишком агрессивное использование скрипта вы не защищены от бана.</font>",
	},
	{
		name = "Build A Boat For Treasure",
		sub = "BabftREZ  ·  Auto Farm",
		file = "BabftREZ.lua",
		icon = "gameimages/babft.png",
		guiName = "BabftREZ",
		status = "ok",
		placeId = 537413528,
		about = "BabftREZ — меню для Build A Boat For Treasure.\n\nЧто умеет:\n• Auto Farm: проходит этапы, забирает золото и сундук, сам сбрасывает персонажа и начинает новый круг\n• Счётчик золота и таймер: сколько намайнено за время работы фарма\n• Защита от зависаний и смены карты\n• Quests: выполняет квесты\n• Auto Build: копирование баз других игроков и постройка у себя\n• Anti-AFK включён автоматически\n\nЗапускай внутри игры, на старте забега.\n\n✔ Пока без банов — следим за обновлениями игры\n✔ Скрипт регулярно проходит проверку на чистоту\n\n<font color=\"#6b6b85\" size=\"11\">За слишком агрессивное использование скрипта вы не защищены от бана.</font>",
	},
}

-- уникальный параметр, чтобы GitHub отдавал свежий файл, а не кэш
local function nocache(u) return u .. (u:find("?", 1, true) and "&" or "?") .. "t=" .. os.time() end

if GAMES_LIST_URL then
	local ok, res = pcall(function() return loadstring(game:HttpGet(nocache(GAMES_LIST_URL)))() end)
	if ok and typeof(res) == "table" then GAMES = res end
end

-- игра, в которой ты сейчас находишься (по PlaceId), встаёт в списке первой
do
	local here, rest = {}, {}
	for _, g in ipairs(GAMES) do
		if g.placeId and g.placeId == game.PlaceId then here[#here + 1] = g else rest[#rest + 1] = g end
	end
	for _, g in ipairs(rest) do here[#here + 1] = g end
	GAMES = here
end

---------------------------------------------------------------- Избранное (сохраняется в файл, если исполнитель умеет)
local FAV_FILE = "HubREZ_favorites.json"
local Favs = {}
pcall(function()
	if isfile and isfile(FAV_FILE) then
		local data = HttpService:JSONDecode(readfile(FAV_FILE))
		if typeof(data) == "table" then Favs = data end
	end
end)
local function saveFavs()
	pcall(function()
		if writefile then writefile(FAV_FILE, HttpService:JSONEncode(Favs)) end
	end)
end

---------------------------------------------------------------- Конфиг хаба, ассеты
local VERSION = "1.4"
local hubCfg = { Watermark = true, Transparency = 0 }
local closeHub = function() end -- задаётся ниже
local playerCleanup = function() end -- задаётся во вкладке Player

local assetCache = {}
local function fetchAsset(rel)
	if assetCache[rel] then return assetCache[rel] end
	local path = "HubREZ_" .. rel:gsub("[/\\]", "_")
	if not (isfile and isfile(path)) then
		writefile(path, game:HttpGet(GITHUB_RAW .. rel))
	end
	local a = (getcustomasset or getsynasset)(path)
	assetCache[rel] = a
	return a
end
local function applyAsset(img, rel, onOk)
	task.spawn(function()
		local ok, a = pcall(fetchAsset, rel)
		if ok and a and img.Parent then
			img.Image = a
			if onOk then onOk() end
		end
	end)
end

---------------------------------------------------------------- Тема и помощники
local C = {
	bg = Color3.fromRGB(14, 14, 22), bg2 = Color3.fromRGB(24, 18, 42),
	card = Color3.fromRGB(23, 23, 36), line = Color3.fromRGB(40, 40, 62),
	txt = Color3.fromRGB(235, 235, 247), mut = Color3.fromRGB(128, 128, 158),
	acc = Color3.fromRGB(139, 92, 246), acc2 = Color3.fromRGB(192, 132, 252),
	off = Color3.fromRGB(44, 44, 66), green = Color3.fromRGB(34, 197, 94),
	red = Color3.fromRGB(239, 68, 68), gold = Color3.fromRGB(250, 204, 21),
}
local WIN_W, WIN_H, HEADER_H, CARD_H = 540, 370, 50, 60
local TI = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local conns = {}
local function track(c) conns[#conns + 1] = c return c end
local order = 0
local function nextOrder() order += 1 return order end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(obj, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, obj) end
local function stroke(obj, color, t, tr)
	return new("UIStroke", { Color = color, Thickness = t or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, obj)
end
local function gradient(obj, c1, c2, rot)
	return new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rot or 0 }, obj)
end
local function label(parent, text, size, color, bold)
	return new("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color,
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
	}, parent)
end

local function makeDraggable(handle, target, onTap)
	local dragging, moved, startPos, startMouse = false, false, nil, nil
	local goal, cur = Vector2.zero, Vector2.zero
	local follow = nil
	local function stopFollow()
		if follow then follow:Disconnect() follow = nil end
	end
	-- плавное «догоняние» курсора: движение не дёргается, даже если касания приходят редко
	local function startFollow()
		if follow then return end
		follow = RunService.RenderStepped:Connect(function(dt)
			if not target.Parent then stopFollow() return end
			cur = cur:Lerp(goal, 1 - math.exp(-dt * 24))
			local settled = not dragging and (goal - cur).Magnitude < 0.5
			if settled then cur = goal end
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + cur.X, startPos.Y.Scale, startPos.Y.Offset + cur.Y)
			if settled then stopFollow() end
		end)
	end
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, moved = true, false
			stopFollow()
			startMouse, startPos = input.Position, target.Position
			cur, goal = Vector2.zero, Vector2.zero
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					if not moved and onTap then onTap() end
				end
			end)
		end
	end)
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - startMouse
			if d.Magnitude > 6 then moved = true end
			if moved then
				goal = Vector2.new(d.X, d.Y)
				startFollow()
			end
		end
	end))
end

---------------------------------------------------------------- GUI
local GUI_NAME = "HubREZ"
local function getContainers()
	local list = {}
	pcall(function() if gethui then list[#list + 1] = gethui() end end)
	pcall(function() list[#list + 1] = game:GetService("CoreGui") end)
	pcall(function() list[#list + 1] = player:FindFirstChildOfClass("PlayerGui") end)
	return list
end
for _, c in ipairs(getContainers()) do
	pcall(function()
		local old = c:FindFirstChild(GUI_NAME)
		if old then old:Destroy() end
	end)
end

local gui = new("ScreenGui", { Name = GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 998 }, nil)
pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
do
	local ok = pcall(function() if gethui then gui.Parent = gethui() else error("no gethui") end end)
	if not (ok and gui.Parent) then
		ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
		if not (ok and gui.Parent) then gui.Parent = player:WaitForChild("PlayerGui") end
	end
end

local root = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundTransparency = 1 }, gui)
local uiScale = new("UIScale", {}, root)
local function updateScale()
	local vp = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(vp.X * 0.94 / WIN_W, vp.Y * 0.9 / WIN_H), 0.45, 1.15)
end
updateScale()
track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))

local win = new("CanvasGroup", { Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundColor3 = C.bg,
	BorderSizePixel = 0, GroupTransparency = 1 }, root)
corner(win, 16)
local winBg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, win)
gradient(winBg, C.bg2, C.bg, 55)
local winStroke = stroke(win, C.acc, 1.5, 0.35)
gradient(winStroke, C.acc2, C.acc, 90)
TweenService:Create(win, TweenInfo.new(0.4), { GroupTransparency = hubCfg.Transparency / 100 }):Play()

-- Заголовок
local header = new("Frame", { Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundTransparency = 1 }, win)
local title = label(header, '<font color="#c084fc">Hub</font>REZ', 20, C.txt, true)
title.Position, title.Size = UDim2.fromOffset(54, 6), UDim2.new(0.6, 0, 0, 26)
local logo = new("ImageLabel", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(12, 8), BackgroundTransparency = 1,
	Image = "", ScaleType = Enum.ScaleType.Fit }, header)
applyAsset(logo, "gameimages/logo.png")
local sub = label(header, "script hub  ·  mobile + PC", 11, C.mut, false)
sub.Position, sub.Size = UDim2.fromOffset(54, 30), UDim2.new(0.6, 0, 0, 14)
new("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.line, BorderSizePixel = 0 }, header)

local function headerBtn(text, index, hoverColor)
	local b = new("TextButton", { Text = text, TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = C.txt,
		BackgroundColor3 = C.card, AutoButtonColor = false,
		Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -(12 + 38 * index + 32), 0.5, -16) }, header)
	corner(b, 9)
	stroke(b, C.line, 1)
	b.MouseEnter:Connect(function() TweenService:Create(b, TI, { BackgroundColor3 = hoverColor }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(b, TI, { BackgroundColor3 = C.card }):Play() end)
	return b
end
local closeBtn = headerBtn("×", 0, C.red)
local bubbleBtn = headerBtn("–", 1, C.acc)
makeDraggable(header, root)

-- Тело
local body = new("Frame", { Position = UDim2.fromOffset(0, HEADER_H), Size = UDim2.new(1, 0, 1, -HEADER_H), BackgroundTransparency = 1 }, win)
local side = new("Frame", { Size = UDim2.new(0, 132, 1, 0), BackgroundTransparency = 1 }, body)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, side)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, side)
new("Frame", { Position = UDim2.new(0, 132, 0, 8), Size = UDim2.new(0, 1, 1, -16), BackgroundColor3 = C.line, BorderSizePixel = 0 }, body)
local content = new("Frame", { Position = UDim2.fromOffset(133, 0), Size = UDim2.new(1, -133, 1, 0), BackgroundTransparency = 1 }, body)

---------------------------------------------------------------- Страницы / вкладки
local pages, tabs = {}, {}
local function newPage(name)
	local p = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.acc, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), Visible = false, ScrollingDirection = Enum.ScrollingDirection.Y }, content)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, p)
	new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14) }, p)
	pages[name] = p
	return p
end
local function selectTab(name)
	local target = pages[name]
	local wasShown = target and target.Visible
	for n, p in pairs(pages) do p.Visible = (n == name) end
	if target and not wasShown then
		target.Position = UDim2.fromOffset(0, 12)
		TweenService:Create(target, TI, { Position = UDim2.new() }):Play()
	end
	for n, t in pairs(tabs) do
		local on = (n == name)
		TweenService:Create(t.btn, TI, { BackgroundTransparency = on and 0.75 or 1, TextColor3 = on and C.txt or C.mut }):Play()
		t.bar.Visible = on
	end
end
local function newTab(name, text)
	local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.acc, BackgroundTransparency = 1,
		Text = text, TextColor3 = C.mut, TextSize = 13, TextWrapped = true, Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, LayoutOrder = nextOrder() }, side)
	corner(b, 10)
	new("UIPadding", { PaddingLeft = UDim.new(0, 16) }, b)
	local bar = new("Frame", { Size = UDim2.new(0, 3, 0.6, 0), Position = UDim2.new(0, -10, 0.2, 0), BackgroundColor3 = C.acc2, BorderSizePixel = 0, Visible = false }, b)
	corner(bar, 2)
	b.MouseButton1Click:Connect(function() selectTab(name) end)
	tabs[name] = { btn = b, bar = bar }
	return b
end

local gamesPage = newPage("Games")
local favPage = newPage("Favorites")
local playerPage = newPage("Player")
local updatesPage = newPage("Updates")
local settingsPage = newPage("Settings")
local aboutPage = newPage("About")
newTab("Games", "Games")
newTab("Favorites", "Favorites")
newTab("Player", "Player")
newTab("Updates", "Updates")
newTab("Settings", "Settings")
newTab("About", "About the Hub")

-- профиль игрока внизу сайдбара
do
	local pc = new("Frame", { Position = UDim2.new(0, 10, 1, -58), Size = UDim2.fromOffset(112, 48),
		BackgroundColor3 = C.card, BorderSizePixel = 0 }, body)
	corner(pc, 12)
	stroke(pc, C.line, 1)
	local av = new("ImageLabel", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(7, 7), BackgroundColor3 = C.bg, BorderSizePixel = 0,
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150" }, pc)
	corner(av, 17)
	local nm = label(pc, player.DisplayName, 12, C.txt, true)
	nm.Position, nm.Size = UDim2.fromOffset(46, 8), UDim2.new(1, -50, 0, 16)
	nm.TextTruncate = Enum.TextTruncate.AtEnd
	local un = label(pc, "@" .. player.Name, 10, C.mut, false)
	un.Position, un.Size = UDim2.fromOffset(46, 25), UDim2.new(1, -50, 0, 14)
	un.TextTruncate = Enum.TextTruncate.AtEnd
end

---------------------------------------------------------------- Уведомления
local toast = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 60, 1, -12), Size = UDim2.fromOffset(280, 30),
	BackgroundColor3 = C.card, BackgroundTransparency = 1, TextTransparency = 1, TextColor3 = C.txt,
	Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 20,
}, win)
corner(toast, 10)
local toastId = 0
local function showToast(text, color)
	toastId += 1
	local id = toastId
	toast.Text, toast.TextColor3 = text, color or C.txt
	TweenService:Create(toast, TI, { BackgroundTransparency = 0.05, TextTransparency = 0 }):Play()
	task.delay(2.4, function()
		if id == toastId then
			TweenService:Create(toast, TI, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		end
	end)
end

---------------------------------------------------------------- Запуск скрипта
local suspended = false
local setSuspended = function() end -- задаётся ниже (прячет/возвращает хаб)

local function findGui(name)
	for _, c in ipairs(getContainers()) do
		local ok, g = pcall(function() return c:FindFirstChild(name) end)
		if ok and g then return g end
	end
end

local function runGame(g, btn)
	if btn:GetAttribute("busy") then return end
	if g.status == "updating" then
		showToast("Скрипт сейчас обновляется", C.gold)
		return
	end
	local url = g.url or (g.file and (GITHUB_RAW .. g.file))
	if not url or string.find(url, "YOUR_NAME", 1, true) then
		showToast("Не указана ссылка на скрипт", C.gold)
		return
	end
	if g.placeId and game.PlaceId ~= g.placeId then
		showToast("Ты не в этой игре — запускаю всё равно", C.gold)
	end
	btn:SetAttribute("busy", true)
	btn.Text = "Loading…"
	task.spawn(function()
		local ok, err = pcall(function()
			local src = game:HttpGet(nocache(url))
			local fn, e = loadstring(src)
			assert(fn, e)
			fn()
		end)
		if ok then
			btn.Text = "Executed"
			showToast(g.name .. " запущен", C.green)
			-- прячем хаб, пока открыт скрипт, и возвращаем, когда его закроют
			if g.guiName then
				task.spawn(function()
					local t0, found = tick(), nil
					repeat
						task.wait(0.2)
						found = findGui(g.guiName)
					until found or tick() - t0 > 8 or not gui.Parent
					if not gui.Parent then return end
					if not found then
						showToast("Окно скрипта не появилось", C.red)
						return
					end
					setSuspended(true)
					repeat task.wait(0.4) until not found.Parent or not gui.Parent
					if gui.Parent then setSuspended(false) end
				end)
			end
		else
			btn.Text = "Error"
			showToast("Ошибка запуска: " .. tostring(err):sub(1, 40), C.red)
		end
		task.wait(2)
		btn.Text = "Execute"
		btn:SetAttribute("busy", false)
	end)
end

---------------------------------------------------------------- Карточка игры
local starUpdaters = {}
local rebuildFavorites

local function favText(on)
	return '<font color="' .. (on and "#facc15" or "#80809c") .. '">★</font>  In Favorites'
end

local function loadIcon(g, img, ph)
	if g.icon then applyAsset(img, g.icon, function() ph.Visible = false end) end
end

local function buildCard(parent, g)
	local card = new("Frame", { Size = UDim2.new(1, 0, 0, CARD_H), BackgroundColor3 = C.card, BorderSizePixel = 0,
		ClipsDescendants = true, LayoutOrder = nextOrder() }, parent)
	corner(card, 12)
	local cardStroke = stroke(card, C.line, 1)
	card:SetAttribute("gname", string.lower(g.name))

	local head = new("TextButton", { Size = UDim2.new(1, 0, 0, CARD_H), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, card)
	head.MouseEnter:Connect(function() TweenService:Create(cardStroke, TI, { Color = C.acc }):Play() end)
	head.MouseLeave:Connect(function() TweenService:Create(cardStroke, TI, { Color = C.line }):Play() end)
	local icon = new("ImageLabel", { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(10, 9),
		BackgroundColor3 = C.bg, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop, Image = "" }, head)
	corner(icon, 9)
	stroke(icon, C.line, 1)
	local ph = label(icon, string.upper(string.sub(g.name, 1, 1)), 18, C.acc2, true)
	ph.Size, ph.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	loadIcon(g, icon, ph)

	local nameL = label(head, g.name, 14, C.txt, true)
	nameL.Position, nameL.Size = UDim2.fromOffset(62, 10), UDim2.new(1, -142, 0, 20)
	nameL.TextTruncate = Enum.TextTruncate.AtEnd
	local dot = (g.status == "updating") and "#facc15" or "#22c55e"
	local here = g.placeId ~= nil and g.placeId == game.PlaceId
	local subL = label(head, '<font color="' .. dot .. '">●</font>  ' .. (g.sub or "") .. (here and '  ·  <font color="#c084fc">Вы здесь</font>' or ""), 12, C.mut, false)
	subL.Position, subL.Size = UDim2.fromOffset(62, 32), UDim2.new(1, -142, 0, 16)
	subL.TextTruncate = Enum.TextTruncate.AtEnd
	local star = label(head, "★", 18, C.gold, true)
	star.TextXAlignment = Enum.TextXAlignment.Center
	star.Position, star.Size = UDim2.new(1, -66, 0.5, -12), UDim2.fromOffset(24, 24)
	local arrow = label(head, ">", 16, C.mut, true)
	arrow.TextXAlignment = Enum.TextXAlignment.Center
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position, arrow.Size = UDim2.new(1, -24, 0.5, 0), UDim2.fromOffset(24, 24)

	-- ряд кнопок
	local row = new("Frame", { Position = UDim2.fromOffset(12, CARD_H), Size = UDim2.new(1, -24, 0, 38), BackgroundTransparency = 1 }, card)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local function actionBtn(text, bg, idx)
		local b = new("TextButton", { Size = UDim2.new(1 / 3, -6, 1, 0), BackgroundColor3 = bg, AutoButtonColor = false,
			Text = text, TextColor3 = C.txt, Font = Enum.Font.GothamBold, TextSize = 12, RichText = true, LayoutOrder = idx }, row)
		corner(b, 9)
		return b
	end
	local execBtn = actionBtn("Execute", C.acc, 1)
	local favBtn = actionBtn(favText(false), C.off, 2)
	local aboutBtn = actionBtn("About", C.off, 3)

	-- About панель
	local aboutBox = new("Frame", { Position = UDim2.fromOffset(12, CARD_H + 48), Size = UDim2.new(1, -24, 0, 10),
		BackgroundColor3 = C.bg, BorderSizePixel = 0, Visible = false }, card)
	corner(aboutBox, 10)
	local aboutL = label(aboutBox, g.about or "Описание пока не добавлено.", 13, Color3.fromRGB(205, 205, 225), false)
	aboutL.TextWrapped = true
	aboutL.TextYAlignment = Enum.TextYAlignment.Top
	aboutL.Position, aboutL.Size = UDim2.fromOffset(10, 8), UDim2.new(1, -20, 1, -16)

	local open, aboutOpen = false, false
	local aboutH = 60

	local function targetHeight()
		if not open then return CARD_H end
		local h = CARD_H + 48
		if aboutOpen then h += aboutH + 10 end
		return h + 6
	end
	local function resize()
		TweenService:Create(card, TI, { Size = UDim2.new(1, 0, 0, targetHeight()) }):Play()
	end

	head.MouseButton1Click:Connect(function()
		open = not open
		if not open then aboutOpen = false aboutBox.Visible = false end
		TweenService:Create(arrow, TI, { Rotation = open and 90 or 0 }):Play()
		resize()
	end)

	aboutBtn.MouseButton1Click:Connect(function()
		aboutOpen = not aboutOpen
		if aboutOpen then
			local width = math.max(200, card.AbsoluteSize.X / uiScale.Scale - 24 - 20)
			local sz = TextService:GetTextSize(aboutL.Text:gsub("<[^>]+>", ""), 13, Enum.Font.Gotham, Vector2.new(width, 10000))
			aboutH = sz.Y + 16
			aboutBox.Size = UDim2.new(1, -24, 0, aboutH)
			aboutBox.Visible = true
		end
		TweenService:Create(aboutBtn, TI, { BackgroundColor3 = aboutOpen and C.acc or C.off }):Play()
		resize()
		if not aboutOpen then
			task.delay(0.28, function() if not aboutOpen then aboutBox.Visible = false end end)
		end
	end)

	execBtn.MouseButton1Click:Connect(function() runGame(g, execBtn) end)

	local function updateStar()
		local on = Favs[g.name] == true
		star.Visible = on
		favBtn.Text = favText(on)
		TweenService:Create(favBtn, TI, { BackgroundColor3 = on and Color3.fromRGB(64, 54, 20) or C.off }):Play()
	end
	updateStar()
	starUpdaters[#starUpdaters + 1] = { card = card, fn = updateStar }

	favBtn.MouseButton1Click:Connect(function()
		if Favs[g.name] then Favs[g.name] = nil else Favs[g.name] = true end
		saveFavs()
		for i = #starUpdaters, 1, -1 do
			local u = starUpdaters[i]
			if u.card.Parent then u.fn() else table.remove(starUpdaters, i) end
		end
		showToast(Favs[g.name] and "Добавлено в избранное" or "Убрано из избранного", Favs[g.name] and C.gold or C.mut)
		task.delay(0.15, rebuildFavorites)
	end)

	return card
end

---------------------------------------------------------------- Заполнение страниц
local function section(parent, text)
	local l = label(parent, text, 11, C.mut, true)
	l.Size = UDim2.new(1, 0, 0, 18)
	l.LayoutOrder = nextOrder()
	return l
end

local function reportError(where, err)
	warn("[HubREZ] " .. where .. ": " .. tostring(err))
	local l = label(gamesPage, "⚠ " .. where .. ": " .. tostring(err), 12, C.red, false)
	l.Size = UDim2.new(1, 0, 0, 44)
	l.TextWrapped = true
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.LayoutOrder = nextOrder()
end

section(gamesPage, "ДОСТУПНЫЕ ИГРЫ  —  " .. #GAMES)
do
	local search = new("TextBox", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.card, Text = "", PlaceholderText = "Поиск игры…",
		PlaceholderColor3 = C.mut, TextColor3 = C.txt, Font = Enum.Font.Gotham, TextSize = 13, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, LayoutOrder = nextOrder() }, gamesPage)
	corner(search, 10)
	stroke(search, C.line, 1)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12) }, search)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		local q = string.lower(search.Text)
		for _, ch in ipairs(gamesPage:GetChildren()) do
			local n = ch:GetAttribute("gname")
			if n then ch.Visible = (q == "" or string.find(n, q, 1, true) ~= nil) end
		end
	end)
end
for _, g in ipairs(GAMES) do
	local ok, err = pcall(buildCard, gamesPage, g)
	if not ok then reportError("Карточка «" .. tostring(g.name) .. "»", err) end
end

local favHolder
rebuildFavorites = function()
	for _, ch in ipairs(favPage:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	section(favPage, "ИЗБРАННОЕ")
	local any = false
	for _, g in ipairs(GAMES) do
		if Favs[g.name] then
			any = true
			local ok, err = pcall(buildCard, favPage, g)
			if not ok then warn("[HubREZ] Избранное, карточка «" .. tostring(g.name) .. "»: " .. tostring(err)) end
		end
	end
	if not any then
		local e = label(favPage, "Пока пусто.\nОткрой игру в Games и нажми In Favorites.", 13, C.mut, false)
		e.Size = UDim2.new(1, 0, 0, 50)
		e.TextWrapped = true
		e.TextXAlignment = Enum.TextXAlignment.Center
		e.LayoutOrder = nextOrder()
	end
end
do
	local ok, err = pcall(rebuildFavorites)
	if not ok then reportError("Избранное", err) end
end
---------------------------------------------------------------- About the Hub
do
	local ok, err = pcall(function()
	local ABOUT_TEXT = "HubREZ — коллекция скриптов для Roblox, созданная в 2026 году.\n\n"
		.. "Возможности:\n"
		.. "• Отдельные скрипты для каждой поддерживаемой игры, у каждого своё меню\n"
		.. "• Избранное для быстрого доступа к нужным играм\n"
		.. "• Вкладка Player: скорость, прыжок, полёт и ноуклип в любой игре\n"
		.. "• Работа на мобильных устройствах и ПК, сворачиваемое окно\n"
		.. "• Регулярные обновления и расширение списка игр\n\n"
		.. "Скрипты регулярно проходят проверку и обновляются при изменениях в играх. "
		.. "Использование осуществляется на ваш страх и риск: защита от блокировки аккаунта не гарантируется."

	section(aboutPage, "О ХАБЕ")
	local box = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = nextOrder() }, aboutPage)
	corner(box, 12)
	stroke(box, C.line, 1)
	new("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, box)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, box)
	local t = label(box, '<font color="#c084fc">Hub</font>REZ  <font color="#80809c" size="12">v' .. VERSION .. '</font>', 20, C.txt, true)
	t.Size, t.LayoutOrder = UDim2.new(1, 0, 0, 26), 1
	local body = label(box, ABOUT_TEXT, 13, Color3.fromRGB(205, 205, 225), false)
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.LayoutOrder = 2
	end)
	if not ok then reportError("About the Hub", err) end
end

---------------------------------------------------------------- Updates / Settings / водяной знак
local CHANGELOG = {
	{ v = "v1.4", date = "Ноябрь 2026", items = {
		"Новая вкладка Player: скорость бега и сила прыжка с ползунками",
		"Fly: полёт со своей скоростью, на телефоне есть кнопки «Вверх» и «Вниз»",
		"Noclip: проход сквозь стены",
		"Кнопки вкладок в сайдбаре стали чуть ниже, чтобы поместилась новая",
	} },
	{ v = "v1.3", date = "Ноябрь 2026", items = {
		"BabftREZ: автофарм с фиксированными быстрыми настройками, остался только выбор «забирать сундук»",
		"BabftREZ: счётчик намайненного золота, таймер и оценка золота в час",
		"BabftREZ: исправлен сундук после смены карты (пути ищутся заново на каждом шаге)",
	} },
	{ v = "v1.2", date = "Ноябрь 2026", items = {
		"Игра, в которой ты находишься, показывается первой с меткой «Вы здесь»",
		"Запасной список игр синхронизирован с основным",
		"Стабильность: сбой одной карточки не ломает избранное",
		"BabftREZ: переписан автофарм (авто-сброс, защита от зависаний), убраны Fun, ESP и Troll",
		"The Button: добавлен PlaceId для метки «Вы здесь»",
	} },
	{ v = "v1.1", date = "Ноябрь 2026", items = {
		"Новый логотип и обновлённый интерфейс",
		"Профиль игрока, поиск по списку игр",
		"Вкладки Updates и Settings",
		"Метки состояния скриптов",
	} },
	{ v = "v1.0", date = "Ноябрь 2026", items = {
		"Запуск хаба",
		"Игры: The Button, Build A Boat For Treasure",
		"Избранное, описание игр, сворачивание в кружок",
	} },
}

do
	local ok, err = pcall(function()
		section(updatesPage, "ИСТОРИЯ ОБНОВЛЕНИЙ")
		for _, e in ipairs(CHANGELOG) do
			local box = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = nextOrder() }, updatesPage)
			corner(box, 12)
			stroke(box, C.line, 1)
			new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, box)
			new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, box)
			local t = label(box, '<font color="#c084fc">' .. e.v .. '</font>  <font color="#80809c" size="12">' .. e.date .. '</font>', 15, C.txt, true)
			t.Size, t.LayoutOrder = UDim2.new(1, 0, 0, 20), 1
			local lines = {}
			for _, it in ipairs(e.items) do lines[#lines + 1] = "• " .. it end
			local body2 = label(box, table.concat(lines, "\n"), 13, Color3.fromRGB(205, 205, 225), false)
			body2.Size, body2.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
			body2.TextWrapped, body2.TextYAlignment, body2.LayoutOrder = true, Enum.TextYAlignment.Top, 2
		end
	end)
	if not ok then reportError("Updates", err) end
end

local isPress, card, Toggle, Slider, Button -- помощники интерфейса (задаются в блоке Settings)
local watermark = new("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(320, 16),
	BackgroundTransparency = 1, Text = string.format("HubREZ v%s  ·  %s", VERSION, player.DisplayName), TextColor3 = Color3.new(1, 1, 1),
	TextTransparency = 0.5, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3,
	Visible = hubCfg.Watermark }, gui)

do
	local ok, err = pcall(function()
		function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
		function card(page, h)
			local f = new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = nextOrder() }, page)
			corner(f, 12)
			local st = stroke(f, C.line, 1)
			f.MouseEnter:Connect(function() TweenService:Create(st, TI, { Color = C.acc }):Play() end)
			f.MouseLeave:Connect(function() TweenService:Create(st, TI, { Color = C.line }):Play() end)
			return f
		end
		function Toggle(page, text, subtext, default, cb)
			local row = card(page, 54)
			local t = label(row, text, 14, C.txt, true)
			t.Position, t.Size = UDim2.fromOffset(14, 9), UDim2.new(1, -76, 0, 18)
			local s = label(row, subtext, 12, C.mut, false)
			s.Position, s.Size = UDim2.fromOffset(14, 28), UDim2.new(1, -76, 0, 16)
			local sw = new("TextButton", { Size = UDim2.fromOffset(46, 26), Position = UDim2.new(1, -60, 0.5, -13), Text = "", AutoButtonColor = false, BackgroundColor3 = C.off }, row)
			corner(sw, 13)
			local knob = new("Frame", { Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = Color3.fromRGB(154, 154, 181), BorderSizePixel = 0 }, sw)
			corner(knob, 10)
			local state = default
			local function render(anim)
				local info = anim and TI or TweenInfo.new(0)
				TweenService:Create(sw, info, { BackgroundColor3 = state and C.acc or C.off }):Play()
				TweenService:Create(knob, info, { Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
					BackgroundColor3 = state and Color3.new(1, 1, 1) or Color3.fromRGB(154, 154, 181) }):Play()
			end
			render(false)
			sw.MouseButton1Click:Connect(function()
				state = not state
				render(true)
				cb(state)
			end)
		end
		function Slider(page, text, min, max, default, suffix, cb)
			local row = card(page, 62)
			local t = label(row, text, 14, C.txt, true)
			t.Position, t.Size = UDim2.fromOffset(14, 8), UDim2.new(0.6, 0, 0, 18)
			local v = label(row, "", 13, C.acc2, true)
			v.TextXAlignment = Enum.TextXAlignment.Right
			v.Position, v.Size = UDim2.new(0.5, 0, 0, 8), UDim2.new(0.5, -14, 0, 18)
			local trackF = new("Frame", { Position = UDim2.new(0, 14, 0, 42), Size = UDim2.new(1, -28, 0, 6), BackgroundColor3 = C.off, BorderSizePixel = 0 }, row)
			corner(trackF, 3)
			local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.acc, BorderSizePixel = 0 }, trackF)
			corner(fill, 3)
			gradient(fill, C.acc, C.acc2)
			local knob = new("Frame", { Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
				BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2 }, trackF)
			corner(knob, 9)
			stroke(knob, C.acc, 2)
			local hit = new("TextButton", { Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "", ZIndex = 3 }, row)
			local value = default
			local function render()
				local a = (value - min) / (max - min)
				fill.Size = UDim2.new(a, 0, 1, 0)
				knob.Position = UDim2.new(a, 0, 0.5, 0)
				v.Text = tostring(value) .. suffix
			end
			local dragging = false
			local sf = page:FindFirstAncestorOfClass("ScrollingFrame") or page
			local function setX(x)
				local a = math.clamp((x - trackF.AbsolutePosition.X) / trackF.AbsoluteSize.X, 0, 1)
				value = math.floor(min + (max - min) * a + 0.5)
				render()
				cb(value)
			end
			hit.InputBegan:Connect(function(i)
				if isPress(i) then dragging = true; sf.ScrollingEnabled = false; setX(i.Position.X) end
			end)
			track(UserInputService.InputChanged:Connect(function(i)
				if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then setX(i.Position.X) end
			end))
			track(UserInputService.InputEnded:Connect(function(i)
				if dragging and isPress(i) then dragging = false; sf.ScrollingEnabled = true end
			end))
			render()
		end
		function Button(page, text, subtext, btnText, cb)
			local row = card(page, 54)
			local t = label(row, text, 14, C.txt, true)
			t.Position, t.Size = UDim2.fromOffset(14, 9), UDim2.new(1, -110, 0, 18)
			local s = label(row, subtext, 12, C.mut, false)
			s.Position, s.Size = UDim2.fromOffset(14, 28), UDim2.new(1, -110, 0, 16)
			local b = new("TextButton", { Size = UDim2.fromOffset(80, 30), Position = UDim2.new(1, -94, 0.5, -15), Text = btnText,
				TextColor3 = C.txt, Font = Enum.Font.GothamBold, TextSize = 12, BackgroundColor3 = C.acc, AutoButtonColor = false }, row)
			corner(b, 9)
			b.MouseButton1Click:Connect(function() cb(b) end)
		end

		section(settingsPage, "ИНТЕРФЕЙС")
		Toggle(settingsPage, "Водяной знак", "Название хаба в углу экрана", hubCfg.Watermark, function(v)
			hubCfg.Watermark = v
			watermark.Visible = v
		end)
		Slider(settingsPage, "Прозрачность меню", 0, 60, hubCfg.Transparency, "%", function(v)
			hubCfg.Transparency = v
			win.GroupTransparency = v / 100
		end)
		section(settingsPage, "ХАБ")
		Button(settingsPage, "Копировать загрузчик", "Строка запуска хаба в буфер обмена", "Copy", function()
			if setclipboard then
				setclipboard('loadstring(game:HttpGet("' .. GITHUB_RAW .. 'HubREZ.lua"))()')
				showToast("Строка скопирована", C.green)
			else
				showToast("Буфер обмена не поддерживается", C.gold)
			end
		end)
		Button(settingsPage, "Выгрузить хаб", "Полностью закрыть HubREZ", "Unload", function() closeHub() end)
	end)
	if not ok then reportError("Settings", err) end
end

---------------------------------------------------------------- Player (скорость, прыжок, полёт, ноуклип)
do
	local ok, err = pcall(function()
		local P = { Speed = false, SpeedValue = 50, Jump = false, JumpValue = 100, Fly = false, FlySpeed = 60, Noclip = false }
		local weak = { __mode = "k" }
		local origWalk, origJump, origUse, origCollide = setmetatable({}, weak), setmetatable({}, weak), setmetatable({}, weak), setmetatable({}, weak)
		local upHeld, downHeld = false, false
		local flyBV, flyBG, controls

		local function getChar()
			local ch = player.Character
			local hum = ch and ch:FindFirstChildOfClass("Humanoid")
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			return ch, hum, hrp
		end

		-- вектор движения игрока в системе камеры (x вправо, z назад): работает и с WASD, и с джойстиком на телефоне
		local function findControls()
			if controls then return end
			pcall(function()
				local ps = player:FindFirstChild("PlayerScripts")
				local pm = ps and ps:FindFirstChild("PlayerModule")
				if pm then controls = require(pm):GetControls() end
			end)
		end
		local function getMoveVector(hum)
			if controls then
				local ok2, v = pcall(function() return controls:GetMoveVector() end)
				if ok2 and typeof(v) == "Vector3" then return v end
			end
			local cam = workspace.CurrentCamera
			if cam and hum then
				local v = cam.CFrame:VectorToObjectSpace(hum.MoveDirection)
				return Vector3.new(v.X, 0, v.Z)
			end
			return Vector3.zero
		end

		local function restoreSpeed()
			local _, hum = getChar()
			if hum and origWalk[hum] then hum.WalkSpeed = origWalk[hum] end
		end
		local function restoreJump()
			local _, hum = getChar()
			if hum and origJump[hum] then
				hum.UseJumpPower = origUse[hum]
				hum.JumpPower = origJump[hum]
			end
		end
		local function restoreCollide()
			local ch = player.Character
			if not ch then return end
			for _, p in ipairs(ch:GetDescendants()) do
				if p:IsA("BasePart") and origCollide[p] ~= nil then p.CanCollide = origCollide[p] end
			end
		end
		local function flyStop()
			if flyBV then flyBV:Destroy() end
			if flyBG then flyBG:Destroy() end
			flyBV, flyBG = nil, nil
			local _, hum = getChar()
			if hum then
				hum.PlatformStand = false
				pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
			end
		end

		-- кнопки «Вверх» / «Вниз» для телефона (видны только пока включён Fly)
		local flyBtns = {}
		if UserInputService.TouchEnabled then
			local function holdBtn(text, yOff, setter)
				local b = new("TextButton", { Size = UDim2.fromOffset(64, 44), AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -16, 0.5, yOff), Text = text, TextSize = 13, Font = Enum.Font.GothamBold,
					TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = C.acc, BackgroundTransparency = 0.25,
					AutoButtonColor = false, Visible = false, ZIndex = 40 }, gui)
				corner(b, 14)
				stroke(b, Color3.new(1, 1, 1), 1.5, 0.6)
				b.InputBegan:Connect(function(i)
					if isPress(i) then
						setter(true)
						i.Changed:Connect(function()
							if i.UserInputState == Enum.UserInputState.End then setter(false) end
						end)
					end
				end)
				flyBtns[#flyBtns + 1] = b
			end
			holdBtn("Вверх", -28, function(v) upHeld = v end)
			holdBtn("Вниз", 28, function(v) downHeld = v end)
		end
		local function showFlyBtns(v)
			for _, b in ipairs(flyBtns) do b.Visible = v end
		end

		-- основной цикл: скорость, прыжок, полёт
		track(RunService.Heartbeat:Connect(function()
			local ch, hum, hrp = getChar()
			if not hum then return end
			if P.Speed then
				if origWalk[hum] == nil then origWalk[hum] = hum.WalkSpeed end
				hum.WalkSpeed = P.SpeedValue
			end
			if P.Jump then
				if origJump[hum] == nil then origJump[hum], origUse[hum] = hum.JumpPower, hum.UseJumpPower end
				hum.UseJumpPower = true
				hum.JumpPower = P.JumpValue
			end
			if P.Fly and hrp and hum.Health > 0 then
				local cam = workspace.CurrentCamera
				if not cam then return end
				if not flyBV or flyBV.Parent ~= hrp then
					if flyBV then flyBV:Destroy() end
					if flyBG then flyBG:Destroy() end
					flyBV = new("BodyVelocity", { Name = "HubREZ_FlyBV", MaxForce = Vector3.new(9e9, 9e9, 9e9), Velocity = Vector3.zero }, hrp)
					flyBG = new("BodyGyro", { Name = "HubREZ_FlyBG", MaxTorque = Vector3.new(9e9, 9e9, 9e9), P = 9e4, D = 500, CFrame = cam.CFrame }, hrp)
				end
				hum.PlatformStand = true
				local mv = getMoveVector(hum)
				local cf = cam.CFrame
				local dir = cf.LookVector * -mv.Z + cf.RightVector * mv.X
				local up = (upHeld or UserInputService:IsKeyDown(Enum.KeyCode.Space)) and 1 or 0
				local down = (downHeld or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)) and 1 or 0
				dir = dir + Vector3.new(0, up - down, 0)
				if dir.Magnitude > 0 then dir = dir.Unit end
				flyBV.Velocity = dir * P.FlySpeed
				flyBG.CFrame = cf
			end
		end))

		-- ноуклип: перед каждым шагом физики отключаем столкновения частей персонажа
		track(RunService.Stepped:Connect(function()
			if not P.Noclip then return end
			local ch = player.Character
			if not ch then return end
			for _, p in ipairs(ch:GetDescendants()) do
				if p:IsA("BasePart") then
					if origCollide[p] == nil then origCollide[p] = p.CanCollide end
					if p.CanCollide then p.CanCollide = false end
				end
			end
		end))

		playerCleanup = function()
			local wasSpeed, wasJump, wasFly, wasNoclip = P.Speed, P.Jump, P.Fly or flyBV ~= nil, P.Noclip
			P.Speed, P.Jump, P.Fly, P.Noclip = false, false, false, false
			if wasSpeed then pcall(restoreSpeed) end
			if wasJump then pcall(restoreJump) end
			if wasFly then pcall(flyStop) end
			if wasNoclip then pcall(restoreCollide) end
			pcall(showFlyBtns, false)
		end

		-- остатки полёта от старой копии хаба (если она была запущена до обновления)
		do
			local ch0, hum0 = getChar()
			if ch0 then
				local found = false
				for _, d in ipairs(ch0:GetDescendants()) do
					if d.Name == "HubREZ_FlyBV" or d.Name == "HubREZ_FlyBG" then found = true; d:Destroy() end
				end
				if found and hum0 then hum0.PlatformStand = false end
			end
		end

		section(playerPage, "БЕГ И ПРЫЖОК")
		Toggle(playerPage, "Скорость", "Быстрый бег по земле", false, function(v)
			P.Speed = v
			if not v then restoreSpeed() end
		end)
		Slider(playerPage, "Скорость бега", 16, 200, P.SpeedValue, "", function(v) P.SpeedValue = v end)
		Toggle(playerPage, "Прыжок", "Высокий прыжок", false, function(v)
			P.Jump = v
			if not v then restoreJump() end
		end)
		Slider(playerPage, "Сила прыжка", 50, 300, P.JumpValue, "", function(v) P.JumpValue = v end)

		section(playerPage, "ПОЛЁТ И СТЕНЫ")
		Toggle(playerPage, "Fly", "Полёт в сторону камеры", false, function(v)
			P.Fly = v
			if v then
				task.spawn(findControls)
				showFlyBtns(true)
			else
				upHeld, downHeld = false, false
				showFlyBtns(false)
				flyStop()
			end
		end)
		Slider(playerPage, "Скорость полёта", 10, 250, P.FlySpeed, "", function(v) P.FlySpeed = v end)
		Toggle(playerPage, "Noclip", "Проход сквозь стены", false, function(v)
			P.Noclip = v
			if not v then restoreCollide() end
		end)

		local hint = label(playerPage, "Fly: вперёд — туда, куда смотрит камера. Вверх и вниз: Space и Shift на ПК, кнопки справа на телефоне. "
			.. "Чтобы лететь сквозь стены, включи ещё и Noclip. Использование на свой риск.", 12, C.mut, false)
		hint.Size, hint.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
		hint.TextWrapped, hint.TextYAlignment, hint.LayoutOrder = true, Enum.TextYAlignment.Top, nextOrder()
	end)
	if not ok then reportError("Player", err) end
end

task.delay(0.8, function()
	if gui.Parent then local cur = GAMES[1] and GAMES[1].placeId == game.PlaceId and GAMES[1] or nil
		showToast(cur and ("Ты в игре: " .. cur.name) or ("Добро пожаловать, " .. player.DisplayName .. "!  Игр: " .. #GAMES), C.txt) end
end)

selectTab("Games")

---------------------------------------------------------------- Свернуть / закрыть
local hidden = false
local bubble = new("TextButton", { Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0, 16, 0.5, -27),
	Text = "H", TextSize = 24, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = C.acc, AutoButtonColor = false, Visible = false, ZIndex = 50 }, gui)
corner(bubble, 27)
stroke(bubble, Color3.new(1, 1, 1), 1.5, 0.6)
do
	local bi = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Fit, ZIndex = 51 }, bubble)
	corner(bi, 27)
	applyAsset(bi, "gameimages/logo.png", function() bubble.Text = ""; bubble.BackgroundTransparency = 1 end)
end

local function setHidden(v)
	if suspended then return end
	hidden = v
	if v then
		TweenService:Create(win, TI, { GroupTransparency = 1 }):Play()
		task.delay(0.28, function() if hidden then root.Visible = false; bubble.Visible = true end end)
	else
		bubble.Visible = false
		root.Visible = true
		TweenService:Create(win, TI, { GroupTransparency = hubCfg.Transparency / 100 }):Play()
	end
end
setSuspended = function(v)
	suspended = v
	bubble.Visible = false
	if v then
		TweenService:Create(win, TI, { GroupTransparency = 1 }):Play()
		task.delay(0.28, function() if suspended then root.Visible = false end end)
	else
		hidden = false
		root.Visible = true
		TweenService:Create(win, TI, { GroupTransparency = hubCfg.Transparency / 100 }):Play()
	end
end
makeDraggable(bubble, bubble, function() setHidden(false) end)
bubbleBtn.MouseButton1Click:Connect(function() setHidden(true) end)
closeHub = function()
	genv.HubREZ_Unload = nil
	pcall(playerCleanup)
	for _, c in ipairs(conns) do c:Disconnect() end
	TweenService:Create(win, TI, { GroupTransparency = 1 }):Play()
	bubble.Visible = false
	task.delay(0.3, function() gui:Destroy() end)
end
closeBtn.MouseButton1Click:Connect(function() closeHub() end)
genv.HubREZ_Unload = function()
	pcall(playerCleanup)
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(function() gui:Destroy() end)
end
track(UserInputService.InputBegan:Connect(function(i, gp)
	if not gp and i.KeyCode == Enum.KeyCode.RightShift then setHidden(not hidden) end
end))

TweenService:Create(win, TweenInfo.new(0.4), { GroupTransparency = hubCfg.Transparency / 100 }):Play()
