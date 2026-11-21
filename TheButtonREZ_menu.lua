-- TheButtonREZ menu v3: только интерфейс (GUI). Логики ESP здесь нет.
-- Работает в Roblox Studio и в исполнителях (Delta и др.): вставь целиком и запусти.
-- Фишки: автоподбор места для GUI (gethui/CoreGui/PlayerGui), адаптация под телефон (авто-масштаб, тач), свернуть в кружок,
-- свернуть в заголовок, закрыть, слайдеры, выбор цвета, RightShift.
-- Все изменения приходят в OnChanged(name, value), туда подключается твоя логика.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera or workspace:WaitForChild("Camera")

---------------------------------------------------------------- Настройки
local PALETTE = {
	Color3.fromRGB(139, 92, 246),
	Color3.fromRGB(34, 211, 238),
	Color3.fromRGB(244, 114, 182),
	Color3.fromRGB(74, 222, 128),
	Color3.fromRGB(251, 146, 60),
	Color3.fromRGB(248, 250, 252),
}

local Settings = {
	ESP = false,
	Boxes = true,
	Tracers = false,
	Names = true,
	Health = false,
	Distance = false,
	Skeleton = false,
	Arrows = false,
	Speed = false, SpeedValue = 50, Jump = false, JumpValue = 100, Fly = false, FlySpeed = 60, Noclip = false, -- вкладка Player
	MaxDistance = 1000,
	Thickness = 2,
	MenuTransparency = 0,
	Colors = {
		Boxes = PALETTE[1],
		Tracers = PALETTE[2],
		Names = PALETTE[6],
	},
}

local win -- окно (создаётся ниже)
local espCleanup = function() end -- заполняется движком ESP внизу файла

local function OnChanged(name, value)
	if name == "MenuTransparency" and win then
		win.GroupTransparency = value / 100
	end
	-- сюда подключай свою логику:
	-- print(name, value)
end

---------------------------------------------------------------- Тема и помощники
local C = {
	bg = Color3.fromRGB(14, 14, 22),
	bg2 = Color3.fromRGB(24, 18, 42),
	card = Color3.fromRGB(23, 23, 36),
	line = Color3.fromRGB(40, 40, 62),
	txt = Color3.fromRGB(235, 235, 247),
	mut = Color3.fromRGB(128, 128, 158),
	acc = Color3.fromRGB(139, 92, 246),
	acc2 = Color3.fromRGB(192, 132, 252),
	off = Color3.fromRGB(44, 44, 66),
	green = Color3.fromRGB(34, 197, 94),
	red = Color3.fromRGB(239, 68, 68),
}

local WIN_W, WIN_H, HEADER_H = 560, 380, 50
local TI = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

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

local GITHUB_RAW = "https://raw.githubusercontent.com/holdemholdemovich-wq/HubREZ/main/"
local function applyAsset(img, rel, onOk)
	task.spawn(function()
		local ok, a = pcall(function()
			local path = "HubREZ_" .. rel:gsub("[/\\]", "_")
			if not (isfile and isfile(path)) then writefile(path, game:HttpGet(GITHUB_RAW .. rel)) end
			return (getcustomasset or getsynasset)(path)
		end)
		if ok and a and img.Parent then
			img.Image = a
			if onOk then onOk() end
		end
	end)
end

---------------------------------------------------------------- GUI и окно
local GUI_NAME = "TheButtonREZ"

-- убрать старую копию, если скрипт запущен повторно
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

local gui = new("ScreenGui", {
	Name = GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
}, nil)

pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)

local function mount(g)
	local ok = pcall(function()
		if gethui then g.Parent = gethui() else error("no gethui") end
	end)
	if ok and g.Parent then return end
	ok = pcall(function() g.Parent = game:GetService("CoreGui") end)
	if ok and g.Parent then return end
	g.Parent = player:WaitForChild("PlayerGui")
end
mount(gui)

local root = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundTransparency = 1,
}, gui)

-- Авто-масштаб под экран (телефон/планшет/ПК)
local uiScale = new("UIScale", {}, root)
local function updateScale()
	local vp = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(vp.X * 0.94 / WIN_W, vp.Y * 0.9 / WIN_H), 0.45, 1.15)
end
updateScale()
track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))

win = new("CanvasGroup", {
	Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundColor3 = C.bg,
	BorderSizePixel = 0, GroupTransparency = 1,
}, root)
corner(win, 16)
-- (градиент нельзя вешать на CanvasGroup: он затемняет всё содержимое)
local winBg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, win)
gradient(winBg, C.bg2, C.bg, 55)
local winStroke = stroke(win, C.acc, 1.5, 0.35)
gradient(winStroke, C.acc2, C.acc, 90)

-- Заголовок
local header = new("Frame", { Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundTransparency = 1 }, win)
local title = label(header, '<font color="#c084fc">TheButton</font>REZ', 18, C.txt, true)
title.Position, title.Size = UDim2.fromOffset(54, 6), UDim2.new(0.6, 0, 0, 24)
local logo = new("ImageLabel", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(12, 8), BackgroundTransparency = 1,
	Image = "", ScaleType = Enum.ScaleType.Fit }, header)
applyAsset(logo, "gameimages/logo.png")
local sub = label(header, "v3.0  ·  mobile + PC", 11, C.mut, false)
sub.Position, sub.Size = UDim2.fromOffset(54, 28), UDim2.new(0.6, 0, 0, 16)
new("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.line, BorderSizePixel = 0 }, header)

local function headerBtn(text, index, hoverColor)
	local b = new("TextButton", {
		Text = text, TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = C.txt,
		BackgroundColor3 = C.card, AutoButtonColor = false,
		Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -(12 + 38 * index + 32), 0.5, -16),
	}, header)
	corner(b, 9)
	stroke(b, C.line, 1)
	b.MouseEnter:Connect(function() TweenService:Create(b, TI, { BackgroundColor3 = hoverColor }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(b, TI, { BackgroundColor3 = C.card }):Play() end)
	return b
end

local closeBtn = headerBtn("×", 0, C.red)
local bubbleBtn = headerBtn("–", 1, C.acc)
local rollBtn = headerBtn("^", 2, C.acc)

makeDraggable(header, root)

-- Тело
local body = new("Frame", { Position = UDim2.fromOffset(0, HEADER_H), Size = UDim2.new(1, 0, 1, -HEADER_H), BackgroundTransparency = 1 }, win)

local side = new("Frame", { Size = UDim2.new(0, 132, 1, 0), BackgroundTransparency = 1 }, body)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, side)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, side)
new("Frame", { Position = UDim2.new(0, 132, 0, 8), Size = UDim2.new(0, 1, 1, -16), BackgroundColor3 = C.line, BorderSizePixel = 0 }, body)

local content = new("Frame", { Position = UDim2.fromOffset(133, 0), Size = UDim2.new(1, -133, 1, 0), BackgroundTransparency = 1 }, body)

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

---------------------------------------------------------------- Страницы и вкладки
local pages, tabs = {}, {}

local function newPage(name)
	local p = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.acc,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, content)
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
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.acc, BackgroundTransparency = 1,
		Text = text, TextColor3 = C.mut, TextSize = 14, Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, LayoutOrder = nextOrder(),
	}, side)
	corner(b, 10)
	new("UIPadding", { PaddingLeft = UDim.new(0, 16) }, b)
	local bar = new("Frame", { Size = UDim2.new(0, 3, 0.6, 0), Position = UDim2.new(0, -10, 0.2, 0), BackgroundColor3 = C.acc2, BorderSizePixel = 0, Visible = false }, b)
	corner(bar, 2)
	b.MouseButton1Click:Connect(function() selectTab(name) end)
	tabs[name] = { btn = b, bar = bar }
	return b
end

---------------------------------------------------------------- Компоненты
local function section(parent, text)
	local l = label(parent, text, 11, C.mut, true)
	l.Size = UDim2.new(1, 0, 0, 18)
	l.LayoutOrder = nextOrder()
	return l
end

local function card(parent, h)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = nextOrder() }, parent)
	corner(f, 12)
	local st = stroke(f, C.line, 1)
	f.MouseEnter:Connect(function() TweenService:Create(st, TI, { Color = C.acc }):Play() end)
	f.MouseLeave:Connect(function() TweenService:Create(st, TI, { Color = C.line }):Play() end)
	return f
end

local function newToggle(parent, text, subtext, key, onToggle)
	local row = card(parent, 54)
	local hasColor = Settings.Colors[key] ~= nil
	local reserve = hasColor and 112 or 76

	local t = label(row, text, 14, C.txt, true)
	t.Position, t.Size = UDim2.fromOffset(14, 9), UDim2.new(1, -reserve, 0, 18)
	local s = label(row, subtext, 12, C.mut, false)
	s.Position, s.Size = UDim2.fromOffset(14, 28), UDim2.new(1, -reserve, 0, 16)

	local sw = new("TextButton", {
		Size = UDim2.fromOffset(46, 26), Position = UDim2.new(1, -60, 0.5, -13),
		Text = "", AutoButtonColor = false, BackgroundColor3 = C.off,
	}, row)
	corner(sw, 13)
	local knob = new("Frame", { Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = Color3.fromRGB(154, 154, 181), BorderSizePixel = 0 }, sw)
	corner(knob, 10)

	local state = Settings[key]
	local function render(anim)
		local info = anim and TI or TweenInfo.new(0)
		TweenService:Create(sw, info, { BackgroundColor3 = state and C.acc or C.off }):Play()
		TweenService:Create(knob, info, {
			Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
			BackgroundColor3 = state and Color3.new(1, 1, 1) or Color3.fromRGB(154, 154, 181),
		}):Play()
	end
	render(false)

	sw.MouseButton1Click:Connect(function()
		state = not state
		Settings[key] = state
		render(true)
		OnChanged(key, state)
		if onToggle then onToggle(state) end
	end)

	if hasColor then
		local idx = 1
		for i, c in ipairs(PALETTE) do if c == Settings.Colors[key] then idx = i end end
		local sq = new("TextButton", {
			Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -96, 0.5, -13),
			Text = "", AutoButtonColor = false, BackgroundColor3 = PALETTE[idx],
		}, row)
		corner(sq, 8)
		stroke(sq, Color3.new(1, 1, 1), 1, 0.7)
		sq.MouseButton1Click:Connect(function()
			idx = idx % #PALETTE + 1
			Settings.Colors[key] = PALETTE[idx]
			TweenService:Create(sq, TI, { BackgroundColor3 = PALETTE[idx] }):Play()
			OnChanged(key .. "Color", PALETTE[idx])
		end)
	end
	return row
end

local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function newSlider(parent, text, key, min, max, suffix)
	local row = card(parent, 62)
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
	local knob = new("Frame", {
		Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2,
	}, trackF)
	corner(knob, 9)
	stroke(knob, C.acc, 2)

	local hit = new("TextButton", { Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "", ZIndex = 3 }, row)

	local function render()
		local a = (Settings[key] - min) / (max - min)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		v.Text = tostring(Settings[key]) .. suffix
	end

	local dragging = false
	local sf = parent:FindFirstAncestorOfClass("ScrollingFrame")
	local function setX(x)
		local a = math.clamp((x - trackF.AbsolutePosition.X) / trackF.AbsoluteSize.X, 0, 1)
		Settings[key] = math.floor(min + (max - min) * a + 0.5)
		render()
		OnChanged(key, Settings[key])
	end

	hit.InputBegan:Connect(function(i)
		if isPress(i) then
			dragging = true
			if sf then sf.ScrollingEnabled = false end
			setX(i.Position.X)
		end
	end)
	track(UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			setX(i.Position.X)
		end
	end))
	track(UserInputService.InputEnded:Connect(function(i)
		if dragging and isPress(i) then
			dragging = false
			if sf then sf.ScrollingEnabled = true end
		end
	end))
	render()
	return row
end

---------------------------------------------------------------- Страница ESP
local espPage = newPage("ESP")
local miscPage = newPage("Misc")

local espTab = newTab("ESP", "ESP")
newTab("Misc", "Misc")

local espDot = new("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.new(1, -18, 0.5, -4), BackgroundColor3 = C.off, BorderSizePixel = 0 }, espTab)
corner(espDot, 4)

-- блок опций, который гаснет при выключенном ESP
local opts = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder() }, espPage)
local list = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, opts)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local cover = new("TextButton", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BackgroundTransparency = 0.55,
	Text = "", AutoButtonColor = false, ZIndex = 10,
}, opts)
corner(cover, 12)

local function setEspEnabled(v)
	cover.Visible = not v
	TweenService:Create(espDot, TI, { BackgroundColor3 = v and C.green or C.off }):Play()
end

-- главный тумблер (LayoutOrder меньше, чем у opts)
local master = newToggle(espPage, "Включить ESP", "Главный выключатель модуля", "ESP", setEspEnabled)
master.LayoutOrder = 0
master:FindFirstChildOfClass("UIStroke").Color = C.acc
gradient(master, Color3.fromRGB(44, 30, 80), C.card, 0)

section(list, "ЭЛЕМЕНТЫ")
newToggle(list, "Боксы", "Рамка вокруг игрока", "Boxes")
newToggle(list, "Трейсеры", "Линии к игрокам", "Tracers")
newToggle(list, "Ники", "Имя над головой", "Names")
newToggle(list, "Здоровье", "Полоска HP", "Health")
newToggle(list, "Дистанция", "Расстояние до игрока", "Distance")
newToggle(list, "Скелет", "Кости, суставы и голова", "Skeleton")
newToggle(list, "Стрелки", "Указатели на игроков за экраном", "Arrows")
section(list, "НАСТРОЙКИ")
newSlider(list, "Макс. дистанция", "MaxDistance", 100, 5000, " st")
newSlider(list, "Толщина линий", "Thickness", 1, 5, " px")

setEspEnabled(Settings.ESP)

---------------------------------------------------------------- Aim / Misc
section(miscPage, "ИНТЕРФЕЙС")
newSlider(miscPage, "Прозрачность меню", "MenuTransparency", 0, 60, "%")
local hint = label(miscPage, "RightShift — скрыть/показать меню.\nНа телефоне: кружок — открыть, – — свернуть.", 12, C.mut, false)
hint.Size = UDim2.new(1, 0, 0, 40)
hint.TextWrapped = true
hint.TextYAlignment = Enum.TextYAlignment.Top
hint.LayoutOrder = nextOrder()

---------------------------------------------------------------- Player (скорость, прыжок, полёт, ноуклип)
local playerCleanup = function() end -- заполняется ниже
do
	local ok, err = pcall(function()
		local P = Settings
		local genv = (getgenv and getgenv()) or _G
		if typeof(genv["TheButtonREZ_PlayerUnload"]) == "function" then pcall(genv["TheButtonREZ_PlayerUnload"]) end
		genv["TheButtonREZ_PlayerUnload"] = nil

		local RunService = game:GetService("RunService")
		local weak = { __mode = "k" }
		local origWalk, origJump, origUse, origCollide = setmetatable({}, weak), setmetatable({}, weak), setmetatable({}, weak), setmetatable({}, weak)
		local upHeld, downHeld = false, false
		local flyBV, flyBG, controls
		local pconns, flyBtns = {}, {}

		local function getChar()
			local ch = player.Character
			local hum = ch and ch:FindFirstChildOfClass("Humanoid")
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			return ch, hum, hrp
		end

		-- вектор движения игрока в системе камеры: работает и с WASD, и с джойстиком на телефоне
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
		pconns[#pconns + 1] = RunService.Heartbeat:Connect(function()
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
					flyBV = new("BodyVelocity", { Name = "TheButtonREZ_FlyBV", MaxForce = Vector3.new(9e9, 9e9, 9e9), Velocity = Vector3.zero }, hrp)
					flyBG = new("BodyGyro", { Name = "TheButtonREZ_FlyBG", MaxTorque = Vector3.new(9e9, 9e9, 9e9), P = 9e4, D = 500, CFrame = cam.CFrame }, hrp)
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
		end)

		-- ноуклип: перед каждым шагом физики отключаем столкновения частей персонажа
		pconns[#pconns + 1] = RunService.Stepped:Connect(function()
			if not P.Noclip then return end
			local ch = player.Character
			if not ch then return end
			for _, p in ipairs(ch:GetDescendants()) do
				if p:IsA("BasePart") then
					if origCollide[p] == nil then origCollide[p] = p.CanCollide end
					if p.CanCollide then p.CanCollide = false end
				end
			end
		end)

		playerCleanup = function()
			local wasSpeed, wasJump, wasFly, wasNoclip = P.Speed, P.Jump, P.Fly or flyBV ~= nil, P.Noclip
			P.Speed, P.Jump, P.Fly, P.Noclip = false, false, false, false
			upHeld, downHeld = false, false
			if wasSpeed then pcall(restoreSpeed) end
			if wasJump then pcall(restoreJump) end
			if wasFly then pcall(flyStop) end
			if wasNoclip then pcall(restoreCollide) end
			for _, b in ipairs(flyBtns) do pcall(function() b:Destroy() end) end
			for _, c in ipairs(pconns) do pcall(function() c:Disconnect() end) end
			pconns = {}
			if genv["TheButtonREZ_PlayerUnload"] == playerCleanup then genv["TheButtonREZ_PlayerUnload"] = nil end
		end
		genv["TheButtonREZ_PlayerUnload"] = playerCleanup

		-- остатки полёта от прошлой копии этого скрипта
		do
			local ch0, hum0 = getChar()
			if ch0 then
				local found = false
				for _, d in ipairs(ch0:GetDescendants()) do
					if d.Name == "TheButtonREZ_FlyBV" or d.Name == "TheButtonREZ_FlyBG" then found = true; d:Destroy() end
				end
				if found and hum0 then hum0.PlatformStand = false end
			end
		end
		local playerPage = newPage("Player")
		newTab("Player", "Player")
		section(playerPage, "БЕГ И ПРЫЖОК")
		newToggle(playerPage, "Скорость", "Быстрый бег по земле", "Speed", function(v)
			if not v then restoreSpeed() end
		end)
		newSlider(playerPage, "Скорость бега", "SpeedValue", 16, 200, "")
		newToggle(playerPage, "Прыжок", "Высокий прыжок", "Jump", function(v)
			if not v then restoreJump() end
		end)
		newSlider(playerPage, "Сила прыжка", "JumpValue", 50, 300, "")

		section(playerPage, "ПОЛЁТ И СТЕНЫ")
		newToggle(playerPage, "Fly", "Полёт в сторону камеры", "Fly", function(v)
			if v then
				task.spawn(findControls)
				showFlyBtns(true)
			else
				upHeld, downHeld = false, false
				showFlyBtns(false)
				flyStop()
			end
		end)
		newSlider(playerPage, "Скорость полёта", "FlySpeed", 10, 250, "")
		newToggle(playerPage, "Noclip", "Проход сквозь стены", "Noclip", function(v)
			if not v then restoreCollide() end
		end)

		local hint = label(playerPage, "Fly: вперёд — туда, куда смотрит камера. Вверх и вниз: Space и Shift на ПК, кнопки справа на телефоне. "
			.. "Чтобы лететь сквозь стены, включи ещё и Noclip. Использование на свой риск.", 12, C.mut, false)
		hint.Size, hint.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
		hint.TextWrapped, hint.TextYAlignment, hint.LayoutOrder = true, Enum.TextYAlignment.Top, nextOrder()
	end)
	if not ok then warn("[TheButtonREZ] Player: " .. tostring(err)) end
end

selectTab("ESP")

---------------------------------------------------------------- Свернуть / закрыть
local rolled, hidden = false, false

local function setRolled(v)
	rolled = v
	rollBtn.Text = v and "v" or "^"
	if v then
		TweenService:Create(win, TI, { Size = UDim2.fromOffset(WIN_W, HEADER_H) }):Play()
		task.delay(0.25, function() if rolled then body.Visible = false end end)
	else
		body.Visible = true
		TweenService:Create(win, TI, { Size = UDim2.fromOffset(WIN_W, WIN_H) }):Play()
	end
end
rollBtn.MouseButton1Click:Connect(function() setRolled(not rolled) end)

-- Плавающий кружок (его можно таскать, тап — открыть)
local bubble = new("TextButton", {
	Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0, 16, 0.5, -27),
	Text = "T", TextSize = 24, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = C.acc, AutoButtonColor = false, Visible = false, ZIndex = 50,
}, gui)
corner(bubble, 27)
stroke(bubble, Color3.new(1, 1, 1), 1.5, 0.6)
do
	local bi = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Fit, ZIndex = 51 }, bubble)
	corner(bi, 27)
	applyAsset(bi, "gameimages/logo.png", function() bubble.Text = ""; bubble.BackgroundTransparency = 1 end)
end

local function setHidden(v)
	hidden = v
	if v then
		TweenService:Create(win, TI, { GroupTransparency = 1 }):Play()
		task.delay(0.25, function()
			if hidden then
				root.Visible = false
				bubble.Visible = true
			end
		end)
	else
		bubble.Visible = false
		root.Visible = true
		TweenService:Create(win, TI, { GroupTransparency = Settings.MenuTransparency / 100 }):Play()
	end
end

makeDraggable(bubble, bubble, function() setHidden(false) end)
bubbleBtn.MouseButton1Click:Connect(function() setHidden(true) end)

closeBtn.MouseButton1Click:Connect(function()
	for _, c in ipairs(conns) do c:Disconnect() end
	espCleanup()
	playerCleanup()
	TweenService:Create(win, TI, { GroupTransparency = 1 }):Play()
	bubble.Visible = false
	task.delay(0.3, function() gui:Destroy() end)
end)

track(UserInputService.InputBegan:Connect(function(i, gp)
	if not gp and i.KeyCode == Enum.KeyCode.RightShift then
		setHidden(not hidden)
	end
end))

---------------------------------------------------------------- ESP (на Frame-ах: Drawing API не нужен, работает в любом исполнителе)
do
	local RunService = game:GetService("RunService")
	local TextService = game:GetService("TextService")
	local espLayer = new("Frame", { Name = "ESPLayer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0 }, gui)
	local objs = {}
	local BLACK = Color3.new(0, 0, 0)
	local WHITE = Color3.new(1, 1, 1)
	local STEP = "TheButtonREZ_ESP"

	-- скелет: точки (часть, доля высоты части) и рёбра между ними
	local R15 = {
		names = { "neck", "pelvis", "lsh", "lel", "lwr", "lhd", "rsh", "rel", "rwr", "rhd", "lhip", "lkn", "lan", "lft", "rhip", "rkn", "ran", "rft" },
		pts = {
			neck = { "UpperTorso", 0.9 }, pelvis = { "LowerTorso", 0 },
			lsh = { "LeftUpperArm", 0.85 }, lel = { "LeftLowerArm", 0.85 }, lwr = { "LeftHand", 0.7 }, lhd = { "LeftHand", -0.6 },
			rsh = { "RightUpperArm", 0.85 }, rel = { "RightLowerArm", 0.85 }, rwr = { "RightHand", 0.7 }, rhd = { "RightHand", -0.6 },
			lhip = { "LeftUpperLeg", 0.85 }, lkn = { "LeftLowerLeg", 0.85 }, lan = { "LeftFoot", 0.7 }, lft = { "LeftFoot", -0.6 },
			rhip = { "RightUpperLeg", 0.85 }, rkn = { "RightLowerLeg", 0.85 }, ran = { "RightFoot", 0.7 }, rft = { "RightFoot", -0.6 },
		},
		edges = {
			{ "neck", "pelvis" }, { "neck", "lsh" }, { "lsh", "lel" }, { "lel", "lwr" }, { "lwr", "lhd" },
			{ "neck", "rsh" }, { "rsh", "rel" }, { "rel", "rwr" }, { "rwr", "rhd" },
			{ "pelvis", "lhip" }, { "lhip", "lkn" }, { "lkn", "lan" }, { "lan", "lft" },
			{ "pelvis", "rhip" }, { "rhip", "rkn" }, { "rkn", "ran" }, { "ran", "rft" },
		},
	}
	local R6 = {
		names = { "neck", "pelvis", "lsh", "lhd", "rsh", "rhd", "lhip", "lft", "rhip", "rft" },
		pts = {
			neck = { "Torso", 0.9 }, pelvis = { "Torso", -0.9 },
			lsh = { "Left Arm", 0.9 }, lhd = { "Left Arm", -0.9 }, rsh = { "Right Arm", 0.9 }, rhd = { "Right Arm", -0.9 },
			lhip = { "Left Leg", 0.9 }, lft = { "Left Leg", -0.9 }, rhip = { "Right Leg", 0.9 }, rft = { "Right Leg", -0.9 },
		},
		edges = {
			{ "neck", "pelvis" }, { "neck", "lsh" }, { "lsh", "lhd" }, { "neck", "rsh" }, { "rsh", "rhd" },
			{ "pelvis", "lhip" }, { "lhip", "lft" }, { "pelvis", "rhip" }, { "rhip", "rft" },
		},
	}
	local MAXB, MAXJ = 18, 18

	-- примитивы
	local function rect(z)
		return new("Frame", { BorderSizePixel = 0, BackgroundColor3 = WHITE, ZIndex = z or 2, Visible = false }, espLayer)
	end
	local function lineFrame(z)
		local f = rect(z)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		corner(f, 3)
		return f
	end
	local function circle(size, z)
		local f = new("Frame", { BorderSizePixel = 0, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(size, size), ZIndex = z or 3, Visible = false }, espLayer)
		corner(f, 999)
		return f
	end
	local function pill(size)
		local l = new("TextLabel", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, Font = Enum.Font.GothamBold,
			TextSize = size, TextStrokeTransparency = 1, ZIndex = 4, Visible = false }, espLayer)
		corner(l, 5)
		return l
	end
	local function setPill(l, text, color, cx, y, tr)
		local sz = TextService:GetTextSize(text, l.TextSize, l.Font, Vector2.new(400, 50))
		l.Text, l.TextColor3 = text, color
		l.Size = UDim2.fromOffset(sz.X + 10, sz.Y + 2)
		l.Position = UDim2.fromOffset(cx - (sz.X + 10) / 2, y)
		l.TextTransparency = tr
		l.BackgroundTransparency = 0.45 + tr * 0.55
		l.Visible = true
	end
	local function setLine(f, ax, ay, bx, by, thick)
		local dx, dy = bx - ax, by - ay
		f.Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2)
		f.Size = UDim2.fromOffset(math.max(1, thick), math.sqrt(dx * dx + dy * dy))
		f.Rotation = math.deg(math.atan2(dy, dx)) + 90
		f.Visible = true
	end

	local function makeObj(plr)
		local t = {}
		t.fill = rect(1)
		t.boxOut = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2, Visible = false }, espLayer)
		new("UIStroke", { Color = BLACK, Thickness = 3, Transparency = 0.25 }, t.boxOut)
		t.box = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3, Visible = false }, espLayer)
		new("UIStroke", { Color = WHITE, Thickness = 1 }, t.box)
		t.tracer = lineFrame(2)
		t.tdot = circle(6, 3)
		t.tdot.BackgroundTransparency = 0
		t.name = pill(13)
		t.dist = pill(11)
		t.hpBg = rect(2)
		corner(t.hpBg, 3)
		t.hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
		new("UIStroke", { Color = BLACK, Thickness = 1 }, t.hpBg)
		t.hp = rect(3)
		corner(t.hp, 3)
		t.hpText = pill(10)
		t.head = circle(10, 3)
		new("UIStroke", { Color = WHITE, Thickness = 1.5 }, t.head)
		t.bones, t.joints = {}, {}
		for i = 1, MAXB do t.bones[i] = lineFrame(2) end
		for i = 1, MAXJ do
			local j = circle(5, 3)
			j.BackgroundTransparency = 0
			t.joints[i] = j
		end
		t.arrow = { lineFrame(5), lineFrame(5) }
		t.arrowText = pill(11)
		objs[plr] = t
		return t
	end

	local function destroyObj(plr)
		local t = objs[plr]
		if not t then return end
		for _, o in pairs(t) do
			if typeof(o) == "table" then
				for _, x in pairs(o) do x:Destroy() end
			else
				o:Destroy()
			end
		end
		objs[plr] = nil
	end

	local function hide(t)
		for _, o in pairs(t) do
			if typeof(o) == "table" then
				for _, x in pairs(o) do x.Visible = false end
			else
				o.Visible = false
			end
		end
	end

	-- стрелка к игроку, когда он вышел за экран или за спиной
	local function drawArrow(t, cam, vp, hrp, dist, col, name)
		local rel = cam.CFrame:PointToObjectSpace(hrp.Position)
		local dir = Vector2.new(rel.X, -rel.Y)
		if dir.Magnitude < 1e-3 then dir = Vector2.new(0, 1) end
		dir = dir.Unit
		local mx, my = vp.X / 2 - 46, vp.Y / 2 - 46
		local sx = math.abs(dir.X) > 1e-4 and mx / math.abs(dir.X) or math.huge
		local sy = math.abs(dir.Y) > 1e-4 and my / math.abs(dir.Y) or math.huge
		local p = Vector2.new(vp.X / 2, vp.Y / 2) + dir * math.min(sx, sy)
		local perp = Vector2.new(-dir.Y, dir.X)
		local tip, base = p + dir * 12, p - dir * 6
		local l, r = base + perp * 10, base - perp * 10
		for i, e in ipairs({ l, r }) do
			t.arrow[i].BackgroundColor3 = col
			t.arrow[i].BackgroundTransparency = 0
			setLine(t.arrow[i], tip.X, tip.Y, e.X, e.Y, 3)
		end
		local tp = p - dir * 30
		setPill(t.arrowText, name .. "  " .. math.floor(dist), col, tp.X, tp.Y - 8, 0)
	end

	local function skelPoint(ch, cam, def)
		local part = ch:FindFirstChild(def[1])
		if not part or not part:IsA("BasePart") then return nil end
		local w = part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y / 2 * def[2], 0))
		local p = cam:WorldToViewportPoint(w)
		if p.Z <= 0 then return nil end
		return p
	end

	local function update(plr, t, cam)
		if not Settings.ESP then return hide(t) end
		local ch = plr.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if not (hrp and hum and hum.Health > 0) then return hide(t) end

		local myChar = player.Character
		local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
		local dist = myHrp and (myHrp.Position - hrp.Position).Magnitude or (cam.CFrame.Position - hrp.Position).Magnitude
		if dist > Settings.MaxDistance then return hide(t) end

		local vp = cam.ViewportSize
		local head = ch:FindFirstChild("Head")
		local feetOff = hum.RigType == Enum.HumanoidRigType.R15 and (hum.HipHeight + hrp.Size.Y / 2) or 3
		local topW = (head and head.Position or hrp.Position + Vector3.new(0, 1.5, 0)) + Vector3.new(0, (head and head.Size.Y / 2 or 0) + 0.25, 0)
		local botW = hrp.Position - Vector3.new(0, feetOff, 0)
		local pos = cam:WorldToViewportPoint(hrp.Position)
		local top = cam:WorldToViewportPoint(topW)
		local bot = cam:WorldToViewportPoint(botW)
		local front = pos.Z > 0 and top.Z > 0 and bot.Z > 0

		local h = math.max(math.abs(bot.Y - top.Y), 10)
		local w = h * 0.55
		local x, y = pos.X - w / 2, math.min(top.Y, bot.Y)
		local boxCol = Settings.Colors.Boxes
		local outside = (not front) or x + w < 0 or x > vp.X or y + h < 0 or y > vp.Y

		hide(t)
		if outside then
			if Settings.Arrows then
				drawArrow(t, cam, vp, hrp, dist, boxCol, plr.DisplayName)
			end
			return
		end

		local th = Settings.Thickness
		local fade = math.clamp((dist / Settings.MaxDistance - 0.6) / 0.4, 0, 1) * 0.7

		-- боксы (чистая рамка с чёрной обводкой + лёгкая заливка)
		if Settings.Boxes then
			local bx, by, bw, bh = math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5)
			t.fill.Position, t.fill.Size = UDim2.fromOffset(bx, by), UDim2.fromOffset(bw, bh)
			t.fill.BackgroundColor3 = boxCol
			t.fill.BackgroundTransparency = 0.9 + fade * 0.1
			t.fill.Visible = true
			for _, f in ipairs({ t.box, t.boxOut }) do
				f.Position, f.Size = UDim2.fromOffset(bx, by), UDim2.fromOffset(bw, bh)
				f.Visible = true
			end
			local st = t.box:FindFirstChildOfClass("UIStroke")
			st.Color, st.Thickness, st.Transparency = boxCol, th, fade
			t.boxOut:FindFirstChildOfClass("UIStroke").Thickness = th + 2
		end

		-- трейсер
		if Settings.Tracers then
			local tc = Settings.Colors.Tracers
			t.tracer.BackgroundColor3, t.tracer.BackgroundTransparency = tc, fade
			setLine(t.tracer, vp.X / 2, vp.Y, pos.X, y + h, th)
			t.tdot.BackgroundColor3, t.tdot.BackgroundTransparency = tc, fade
			t.tdot.Position = UDim2.fromOffset(pos.X, y + h)
			t.tdot.Visible = true
		end

		-- ник
		if Settings.Names then
			setPill(t.name, plr.DisplayName, Settings.Colors.Names, pos.X, y - 20, fade)
		end

		-- здоровье
		if Settings.Health then
			local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
			local bw = math.max(4, th + 2)
			local bx = x - bw - 4
			t.hpBg.Position, t.hpBg.Size = UDim2.fromOffset(bx, y), UDim2.fromOffset(bw, h)
			t.hp.Position = UDim2.fromOffset(bx, y + h * (1 - ratio))
			t.hp.Size = UDim2.fromOffset(bw, h * ratio)
			local col = ratio > 0.5 and C.green:Lerp(Color3.fromRGB(250, 204, 21), (1 - ratio) * 2)
				or Color3.fromRGB(250, 204, 21):Lerp(C.red, (0.5 - ratio) * 2)
			t.hp.BackgroundColor3 = col
			t.hpBg.Visible, t.hp.Visible = true, true
			if ratio < 1 then
				setPill(t.hpText, tostring(math.floor(hum.Health)), col, bx - 12, y + h * (1 - ratio) - 7, 0)
			end
		end

		-- дистанция
		if Settings.Distance then
			setPill(t.dist, math.floor(dist) .. " st", Color3.fromRGB(210, 210, 235), pos.X, y + h + 3, fade)
		end

		-- скелет + кольцо на голове
		if Settings.Skeleton then
			local rig = hum.RigType == Enum.HumanoidRigType.R15 and R15 or R6
			local pts = {}
			for _, n in ipairs(rig.names) do pts[n] = skelPoint(ch, cam, rig.pts[n]) end
			local skCol = boxCol:Lerp(WHITE, 0.5)
			local lw = math.max(1, th - 0.5)
			for i, e in ipairs(rig.edges) do
				local pa, pb = pts[e[1]], pts[e[2]]
				if pa and pb then
					local l = t.bones[i]
					l.BackgroundColor3, l.BackgroundTransparency = skCol, fade
					setLine(l, pa.X, pa.Y, pb.X, pb.Y, lw)
				end
			end
			for i, n in ipairs(rig.names) do
				local p = pts[n]
				if p then
					local j = t.joints[i]
					local d = lw + 3
					j.Size, j.Position = UDim2.fromOffset(d, d), UDim2.fromOffset(p.X, p.Y)
					j.BackgroundColor3, j.BackgroundTransparency = WHITE, fade
					j.Visible = true
				end
			end
			if head then
				local hp = cam:WorldToViewportPoint(head.Position)
				local hpTop = cam:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y / 2, 0))
				if hp.Z > 0 and hpTop.Z > 0 then
					local d = math.max(6, math.abs(hpTop.Y - hp.Y) * 2)
					t.head.Size, t.head.Position = UDim2.fromOffset(d, d), UDim2.fromOffset(hp.X, hp.Y)
					local st = t.head:FindFirstChildOfClass("UIStroke")
					st.Color, st.Thickness, st.Transparency = skCol, math.max(1, lw), fade
					t.head.Visible = true
					-- линия шеи от низа головы к шее
					local neck = pts.neck
					if neck then
						local l = t.bones[MAXB]
						l.BackgroundColor3, l.BackgroundTransparency = skCol, fade
						setLine(l, hp.X, hp.Y + d / 2, neck.X, neck.Y, lw)
					end
				end
			end
		end
	end

	-- обновляем ПОСЛЕ камеры, чтобы ESP не отставал и не дрожал
	pcall(function() RunService:UnbindFromRenderStep(STEP) end)
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 1, function()
		local cam = workspace.CurrentCamera
		if not cam then return end
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then
				local t = objs[plr] or makeObj(plr)
				local ok = pcall(update, plr, t, cam)
				if not ok then hide(t) end
			end
		end
	end)

	track(Players.PlayerRemoving:Connect(destroyObj))

	espCleanup = function()
		pcall(function() RunService:UnbindFromRenderStep(STEP) end)
		for plr in pairs(objs) do destroyObj(plr) end
		espLayer:Destroy()
	end
end

-- Плавное появление
TweenService:Create(win, TweenInfo.new(0.4), { GroupTransparency = Settings.MenuTransparency / 100 }):Play()
