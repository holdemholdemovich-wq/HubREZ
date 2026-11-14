-- ============================================================
-- HubREZ — хаб скриптов (Games / Favorites / Execute / About)
-- Запускать в исполнителе (Delta и др.). Телефон + ПК.
-- ============================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera or workspace:WaitForChild("Camera")

---------------------------------------------------------------- НАСТРОЙКИ ХАБА
-- 1) Залей скрипты на GitHub и впиши СВОЙ ник и репозиторий:
local GITHUB_RAW = "https://raw.githubusercontent.com/holdemholdemovich-wq/HubREZ/main/"

-- 2) (по желанию) ссылка на файл со списком игр, чтобы добавлять игры без правки хаба.
--    Файл должен возвращать такую же таблицу, как GAMES ниже: return { {...}, {...} }
local GAMES_LIST_URL = GITHUB_RAW .. "games.lua"  -- список игр лежит в репозитории

-- 3) Список игр. Чтобы добавить новую — просто добавь ещё один блок { ... }
local GAMES = {
	{
		name = "The Button",
		sub = "TheButtonREZ  ·  ESP",
		file = "TheButtonREZ_menu.lua",  -- имя файла в репозитории
		icon = "thebutton.jpg",          -- картинка игры (лежит в репозитории)
		guiName = "TheButtonREZ",        -- имя окна скрипта: хаб прячется, пока оно открыто
		placeId = nil, -- сюда можно вписать PlaceId игры, тогда хаб предупредит, если ты не в ней
		about = "TheButtonREZ — меню для игры The Button.\n\nЧто умеет:\n• ESP: боксы, трейсеры, ники, здоровье, дистанция, скелет\n• Стрелки-указатели на игроков за экраном\n• Настройка цветов, толщины линий и дальности\n• Работает на телефоне и ПК, сворачивается в кружок\n\nМеню открывается после нажатия Execute.",
	},
}

-- уникальный параметр, чтобы GitHub отдавал свежий файл, а не кэш
local function nocache(u) return u .. (u:find("?", 1, true) and "&" or "?") .. "t=" .. os.time() end

if GAMES_LIST_URL then
	local ok, res = pcall(function() return loadstring(game:HttpGet(nocache(GAMES_LIST_URL)))() end)
	if ok and typeof(res) == "table" then GAMES = res end
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

---------------------------------------------------------------- Тема и помощники
local C = {
	bg = Color3.fromRGB(14, 14, 22), bg2 = Color3.fromRGB(24, 18, 42),
	card = Color3.fromRGB(23, 23, 36), line = Color3.fromRGB(40, 40, 62),
	txt = Color3.fromRGB(235, 235, 247), mut = Color3.fromRGB(128, 128, 158),
	acc = Color3.fromRGB(139, 92, 246), acc2 = Color3.fromRGB(192, 132, 252),
	off = Color3.fromRGB(44, 44, 66), green = Color3.fromRGB(34, 197, 94),
	red = Color3.fromRGB(239, 68, 68), gold = Color3.fromRGB(250, 204, 21),
}
local WIN_W, WIN_H, HEADER_H, CARD_H = 520, 340, 50, 60
local TI = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

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
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, moved = true, false
			startMouse, startPos = input.Position, target.Position
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
				target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
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

-- Заголовок
local header = new("Frame", { Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundTransparency = 1 }, win)
local title = label(header, '<font color="#c084fc">Hub</font>REZ', 20, C.txt, true)
title.Position, title.Size = UDim2.fromOffset(18, 6), UDim2.new(0.6, 0, 0, 26)
local sub = label(header, "script hub  ·  mobile + PC", 11, C.mut, false)
sub.Position, sub.Size = UDim2.fromOffset(18, 30), UDim2.new(0.6, 0, 0, 14)
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
local side = new("Frame", { Size = UDim2.new(0, 120, 1, 0), BackgroundTransparency = 1 }, body)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, side)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, side)
new("Frame", { Position = UDim2.new(0, 120, 0, 8), Size = UDim2.new(0, 1, 1, -16), BackgroundColor3 = C.line, BorderSizePixel = 0 }, body)
local content = new("Frame", { Position = UDim2.fromOffset(121, 0), Size = UDim2.new(1, -121, 1, 0), BackgroundTransparency = 1 }, body)

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
	for n, p in pairs(pages) do p.Visible = (n == name) end
	for n, t in pairs(tabs) do
		local on = (n == name)
		TweenService:Create(t.btn, TI, { BackgroundTransparency = on and 0.75 or 1, TextColor3 = on and C.txt or C.mut }):Play()
		t.bar.Visible = on
	end
end
local function newTab(name, text)
	local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.acc, BackgroundTransparency = 1,
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
local aboutPage = newPage("About")
newTab("Games", "Games")
newTab("Favorites", "Favorites")
newTab("About", "About the Hub")

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

-- Иконки игр: качаем картинку из репозитория, сохраняем файл и показываем через getcustomasset
local iconCache = {}
local function loadIcon(g, img, ph)
	if not g.icon then return end
	task.spawn(function()
		local ok, asset = pcall(function()
			if iconCache[g.icon] then return iconCache[g.icon] end
			local path = "HubREZ_" .. g.icon
			if not (isfile and isfile(path)) then
				writefile(path, game:HttpGet(GITHUB_RAW .. g.icon))
			end
			local a = (getcustomasset or getsynasset)(path)
			iconCache[g.icon] = a
			return a
		end)
		if ok and asset and img.Parent then
			img.Image = asset
			ph.Visible = false
		end
	end)
end

local function buildCard(parent, g)
	local card = new("Frame", { Size = UDim2.new(1, 0, 0, CARD_H), BackgroundColor3 = C.card, BorderSizePixel = 0,
		ClipsDescendants = true, LayoutOrder = nextOrder() }, parent)
	corner(card, 12)
	stroke(card, C.line, 1)

	local head = new("TextButton", { Size = UDim2.new(1, 0, 0, CARD_H), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, card)
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
	local subL = label(head, g.sub or "", 12, C.mut, false)
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

section(gamesPage, "ДОСТУПНЫЕ ИГРЫ")
for _, g in ipairs(GAMES) do buildCard(gamesPage, g) end

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
			buildCard(favPage, g)
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
rebuildFavorites()
---------------------------------------------------------------- About the Hub
do
	local ABOUT_TEXT = "HubREZ — коллекция скриптов для Roblox, созданная в 2026 году.\n\n"
		.. "Возможности:\n"
		.. "• Отдельные скрипты для каждой поддерживаемой игры, у каждого своё меню\n"
		.. "• Избранное для быстрого доступа к нужным играм\n"
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
	local t = label(box, '<font color="#c084fc">Hub</font>REZ  <font color="#80809c" size="12">v1.0</font>', 20, C.txt, true)
	t.Size, t.LayoutOrder = UDim2.new(1, 0, 0, 26), 1
	local body = label(box, ABOUT_TEXT, 13, Color3.fromRGB(205, 205, 225), false)
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.LayoutOrder = 2
end

selectTab("Games")

---------------------------------------------------------------- Свернуть / закрыть
local hidden = false
local bubble = new("TextButton", { Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0, 16, 0.5, -27),
	Text = "H", TextSize = 24, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = C.acc, AutoButtonColor = false, Visible = false, ZIndex = 50 }, gui)
corner(bubble, 27)
stroke(bubble, Color3.new(1, 1, 1), 1.5, 0.6)

local function setHidden(v)
	if suspended then return end
	hidden = v
	if v then
		TweenService:Create(win, TI, { GroupTransparency = 1 }):Play()
		task.delay(0.28, function() if hidden then root.Visible = false; bubble.Visible = true end end)
	else
		bubble.Visible = false
		root.Visible = true
		TweenService:Create(win, TI, { GroupTransparency = 0 }):Play()
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
		TweenService:Create(win, TI, { GroupTransparency = 0 }):Play()
	end
end
makeDraggable(bubble, bubble, function() setHidden(false) end)
bubbleBtn.MouseButton1Click:Connect(function() setHidden(true) end)
closeBtn.MouseButton1Click:Connect(function()
	for _, c in ipairs(conns) do c:Disconnect() end
	TweenService:Create(win, TI, { GroupTransparency = 1 }):Play()
	bubble.Visible = false
	task.delay(0.3, function() gui:Destroy() end)
end)
track(UserInputService.InputBegan:Connect(function(i, gp)
	if not gp and i.KeyCode == Enum.KeyCode.RightShift then setHidden(not hidden) end
end))

TweenService:Create(win, TweenInfo.new(0.4), { GroupTransparency = 0 }):Play()
