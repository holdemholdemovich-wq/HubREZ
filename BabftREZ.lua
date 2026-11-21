-- ============================================================
-- BabftREZ — Build A Boat For Treasure
-- Auto Farm / Quests / Auto Build (копирование баз) / Player
-- Телефон + ПК. Запускать из HubREZ или напрямую в исполнителе.
-- ============================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera or workspace:WaitForChild("Camera")

local cfg = { AutoFarm = false, ClaimChest = true }

---------------------------------------------------------------- Тема и помощники
local C = {
	bg = Color3.fromRGB(14, 14, 22), bg2 = Color3.fromRGB(24, 18, 42),
	card = Color3.fromRGB(23, 23, 36), line = Color3.fromRGB(40, 40, 62),
	txt = Color3.fromRGB(235, 235, 247), mut = Color3.fromRGB(128, 128, 158),
	acc = Color3.fromRGB(139, 92, 246), acc2 = Color3.fromRGB(192, 132, 252),
	off = Color3.fromRGB(44, 44, 66), green = Color3.fromRGB(34, 197, 94),
	red = Color3.fromRGB(239, 68, 68), gold = Color3.fromRGB(250, 204, 21),
}
local WIN_W, WIN_H, HEADER_H = 540, 390, 50
local TI = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local conns, cleanups = {}, {}
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
local function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end

local function makeDraggable(handle, target, onTap)
	local dragging, moved, startPos, startMouse = false, false, nil, nil
	handle.InputBegan:Connect(function(input)
		if isPress(input) then
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

---------------------------------------------------------------- GUI
local GUI_NAME = "BabftREZ"
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
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999 }, nil)
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

local header = new("Frame", { Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundTransparency = 1 }, win)
local title = label(header, '<font color="#c084fc">Babft</font>REZ', 20, C.txt, true)
title.Position, title.Size = UDim2.fromOffset(54, 6), UDim2.new(0.6, 0, 0, 26)
local logo = new("ImageLabel", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(12, 8), BackgroundTransparency = 1,
	Image = "", ScaleType = Enum.ScaleType.Fit }, header)
applyAsset(logo, "gameimages/logo.png")
local sub = label(header, "Build A Boat For Treasure", 11, C.mut, false)
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

---------------------------------------------------------------- Мини-библиотека интерфейса
local pages, tabs = {}, {}
local function selectTab(name)
	for n, p in pairs(pages) do p.Visible = (n == name) end
	for n, t in pairs(tabs) do
		local on = (n == name)
		TweenService:Create(t.btn, TI, { BackgroundTransparency = on and 0.75 or 1, TextColor3 = on and C.txt or C.mut }):Play()
		t.bar.Visible = on
	end
end
local function Tab(name)
	local p = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.acc, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), Visible = false, ScrollingDirection = Enum.ScrollingDirection.Y }, content)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, p)
	new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14) }, p)
	pages[name] = p

	local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.acc, BackgroundTransparency = 1,
		Text = name, TextColor3 = C.mut, TextSize = 14, Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, LayoutOrder = nextOrder() }, side)
	corner(b, 10)
	new("UIPadding", { PaddingLeft = UDim.new(0, 16) }, b)
	local bar = new("Frame", { Size = UDim2.new(0, 3, 0.6, 0), Position = UDim2.new(0, -10, 0.2, 0), BackgroundColor3 = C.acc2, BorderSizePixel = 0, Visible = false }, b)
	corner(bar, 2)
	b.MouseButton1Click:Connect(function() selectTab(name) end)
	tabs[name] = { btn = b, bar = bar }
	return p
end
local function Section(page, text)
	local l = label(page, text, 11, C.mut, true)
	l.Size = UDim2.new(1, 0, 0, 18)
	l.LayoutOrder = nextOrder()
end
local function card(page, h)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = nextOrder() }, page)
	corner(f, 12)
	local st = stroke(f, C.line, 1)
	f.MouseEnter:Connect(function() TweenService:Create(st, TI, { Color = C.acc }):Play() end)
	f.MouseLeave:Connect(function() TweenService:Create(st, TI, { Color = C.line }):Play() end)
	return f
end
local function Toggle(page, text, subtext, default, cb)
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
local function Slider(page, text, min, max, default, suffix, cb)
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
local function Button(page, text, subtext, btnText, cb)
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
local function Status(page, text)
	local row = card(page, 40)
	local l = label(row, text, 13, C.acc2, true)
	l.Position, l.Size = UDim2.fromOffset(14, 0), UDim2.new(1, -28, 1, 0)
	return function(t) l.Text = t end
end

local function Progress(page, text)
	local row = card(page, 56)
	local t = label(row, text, 14, C.txt, true)
	t.Position, t.Size = UDim2.fromOffset(14, 8), UDim2.new(0.6, 0, 0, 18)
	local pct = label(row, "0%", 13, C.acc2, true)
	pct.TextXAlignment = Enum.TextXAlignment.Right
	pct.Position, pct.Size = UDim2.new(0.5, 0, 0, 8), UDim2.new(0.5, -14, 0, 18)
	local tr = new("Frame", { Position = UDim2.new(0, 14, 0, 36), Size = UDim2.new(1, -28, 0, 8), BackgroundColor3 = C.off, BorderSizePixel = 0 }, row)
	corner(tr, 4)
	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.acc, BorderSizePixel = 0 }, tr)
	corner(fill, 4)
	gradient(fill, C.acc, C.acc2)
	return function(p)
		p = math.clamp(p, 0, 100)
		fill.Size = UDim2.new(p / 100, 0, 1, 0)
		pct.Text = math.floor(p) .. "%"
	end
end

-- Выпадающий список: getOptions() -> { {label=, value=}, ... }
local function Dropdown(page, text, getOptions, cb)
	local HEAD = 54
	local box = new("Frame", { Size = UDim2.new(1, 0, 0, HEAD), BackgroundColor3 = C.card, BorderSizePixel = 0,
		ClipsDescendants = true, LayoutOrder = nextOrder() }, page)
	corner(box, 12)
	stroke(box, C.line, 1)
	local head = new("TextButton", { Size = UDim2.new(1, 0, 0, HEAD), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, box)
	local t = label(head, text, 14, C.txt, true)
	t.Position, t.Size = UDim2.fromOffset(14, 9), UDim2.new(1, -60, 0, 18)
	local valueL = label(head, "Не выбрано", 12, C.acc2, false)
	valueL.Position, valueL.Size = UDim2.fromOffset(14, 28), UDim2.new(1, -60, 0, 16)
	local arrow = label(head, ">", 16, C.mut, true)
	arrow.TextXAlignment = Enum.TextXAlignment.Center
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position, arrow.Size = UDim2.new(1, -24, 0.5, 0), UDim2.fromOffset(24, 24)
	local list = new("ScrollingFrame", { Position = UDim2.fromOffset(10, HEAD), Size = UDim2.new(1, -20, 0, 0), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = C.acc, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new() }, box)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local open = false
	local function setOpen(v)
		open = v
		local n = 0
		if v then
			for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
			local opts = getOptions()
			for i, o in ipairs(opts) do
				local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.bg, Text = o.label, TextColor3 = C.txt,
					Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, LayoutOrder = i }, list)
				corner(b, 8)
				b.MouseButton1Click:Connect(function()
					valueL.Text = o.label
					cb(o.value)
					setOpen(false)
				end)
			end
			n = #opts
		end
		local listH = math.min(n * 34, 136)
		list.Size = UDim2.new(1, -20, 0, listH)
		TweenService:Create(box, TI, { Size = UDim2.new(1, 0, 0, v and (HEAD + listH + 8) or HEAD) }):Play()
		TweenService:Create(arrow, TI, { Rotation = v and 90 or 0 }):Play()
	end
	head.MouseButton1Click:Connect(function() setOpen(not open) end)
end

local toast = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 60, 1, -12), Size = UDim2.fromOffset(300, 30),
	BackgroundColor3 = C.card, BackgroundTransparency = 1, TextTransparency = 1, TextColor3 = C.txt,
	Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 20,
}, win)
corner(toast, 10)
local toastId = 0
local function notify(text, color)
	toastId += 1
	local id = toastId
	toast.Text, toast.TextColor3 = text, color or C.txt
	TweenService:Create(toast, TI, { BackgroundTransparency = 0.05, TextTransparency = 0 }):Play()
	task.delay(2.6, function()
		if id == toastId then TweenService:Create(toast, TI, { BackgroundTransparency = 1, TextTransparency = 1 }):Play() end
	end)
end

---------------------------------------------------------------- Пути игры и персонаж
local blockData, blocksFolder, OtherData, Stages, ChestTrigger, ClaimRemote, StartQuest
local function refreshPaths()
	blockData = player:FindFirstChild("Data")
	blocksFolder = workspace:FindFirstChild("Blocks")
	OtherData = player:FindFirstChild("OtherData")
	local bs = workspace:FindFirstChild("BoatStages")
	Stages = bs and bs:FindFirstChild("NormalStages")
	local te = Stages and Stages:FindFirstChild("TheEnd")
	local gc = te and te:FindFirstChild("GoldenChest")
	ChestTrigger = gc and gc:FindFirstChild("Trigger")
	ClaimRemote = workspace:FindFirstChild("ClaimRiverResultsGold")
	StartQuest = workspace:FindFirstChild("QuestMakerEvent")
	return (blockData and blocksFolder and OtherData and Stages and ChestTrigger and ClaimRemote and StartQuest) and true or false
end
local function needGame()
	if refreshPaths() then return true end
	notify("Ты не в BABFT или игра изменилась", C.red)
	return false
end

local character, humanoid, HRP
local function bindChar(c)
	character = c
	humanoid = c and c:FindFirstChildOfClass("Humanoid")
	HRP = c and c:FindFirstChild("HumanoidRootPart")
end
bindChar(player.Character)

---------------------------------------------------------------- AUTO FARM (улучшенная версия)
-- Параметры зафиксированы (самые быстрые из проверенных): игрок только включает/выключает фарм
-- и решает, забирать ли сундук. Один главный цикл: не бывает двух фармов сразу и «зависшего» состояния.
-- Каждый этап с таймаутом: при зависании — повтор, затем сброс персонажа и новый круг.
-- Все пути (этапы, сундук, награда) ищутся заново на каждом шаге, поэтому смена карты их не ломает.
local FARM = { StartStage = 2, ChestStage = 5, ChestDelay = 1, StageTimeout = 3 }
local setStatus = function() end
local setStats = function() end
local farmId = 0
local Heartbeat = RunService.Heartbeat

local function isAlive(hum) return hum ~= nil and hum.Parent ~= nil and hum.Health > 0 end
local function active(id) return cfg.AutoFarm and farmId == id end

---------------------------------------------------------------- Счётчик золота и таймер
local session = { gained = 0, last = nil, startT = 0, endT = 0, running = false }
local goldObj, goldTry = nil, 0

local function findGoldObj()
	local best
	local function check(o)
		if o:IsA("IntValue") or o:IsA("NumberValue") then
			local n = string.lower(o.Name)
			if n == "gold" then return o end
			if not best and string.find(n, "gold", 1, true) then best = o end
		end
	end
	for _, o in ipairs(player:GetChildren()) do
		local r = check(o)
		if r then return r end
	end
	for _, name in ipairs({ "Data", "leaderstats", "OtherData" }) do
		local root = player:FindFirstChild(name)
		if root then
			for _, o in ipairs(root:GetDescendants()) do
				local r = check(o)
				if r then return r end
			end
		end
	end
	return best
end

local function readGold()
	if not (goldObj and goldObj.Parent) then
		if os.clock() - goldTry < 3 then return nil end
		goldTry = os.clock()
		goldObj = findGoldObj()
	end
	return goldObj and goldObj.Value or nil
end

local function fmtTime(sec)
	sec = math.floor(sec)
	local h, m, s = math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60
	if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
	return string.format("%02d:%02d", m, s)
end

local function statsText()
	local t = (session.running and os.clock() or session.endT) - session.startT
	if t < 0 then t = 0 end
	local gold = goldObj and ("+" .. session.gained) or "счётчик не найден"
	local rate = (goldObj and t >= 30) and ("  ·  ~" .. math.floor(session.gained / t * 3600) .. "/час") or ""
	return "Золото: " .. gold .. "  ·  Время: " .. fmtTime(t) .. rate
end

---------------------------------------------------------------- Пути (всегда свежие)
local function farmRefs()
	refreshPaths()
	return Stages ~= nil and OtherData ~= nil
end

local chestCache
local function findChestTrigger()
	refreshPaths()
	if ChestTrigger and ChestTrigger.Parent then return ChestTrigger end
	if chestCache and chestCache.Parent then return chestCache end
	local bs = workspace:FindFirstChild("BoatStages")
	if bs then
		for _, o in ipairs(bs:GetDescendants()) do
			if o.Name == "GoldenChest" then
				local tr = o:FindFirstChild("Trigger")
				if tr and tr:IsA("BasePart") then chestCache = tr return tr end
			end
		end
	end
end

local function fireClaim()
	pcall(function()
		local r = workspace:FindFirstChild("ClaimRiverResultsGold")
		if r then r:FireServer() end
	end)
end

local function zeroVelocity(char)
	for _, p in ipairs(char:GetChildren()) do
		if p:IsA("BasePart") then
			p.AssemblyLinearVelocity = Vector3.zero
			p.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

-- ждёт живого персонажа (после респавна)
local function waitCharacter(id)
	while active(id) do
		local c = player.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if c and c.Parent and h and r and h.Health > 0 then return c, h end
		Heartbeat:Wait()
	end
end

-- надёжный сброс: Health = 0 + BreakJoints, с проверкой и повтором
local function resetCharacter(char, hum)
	for _ = 1, 4 do
		if not isAlive(hum) then return true end
		hum.Health = 0
		pcall(function() char:BreakJoints() end)
		local t0 = os.clock()
		while os.clock() - t0 < 1.5 do
			if not isAlive(hum) then return true end
			Heartbeat:Wait()
		end
	end
	return not isAlive(hum)
end

-- проход одного этапа. Возвращает: "ok" | "missing" | "timeout" | "dead" | "stopped"
local function collectStage(n, id, char, hum)
	farmRefs()
	local stage = Stages and Stages:FindFirstChild("CaveStage" .. n)
	local collect = stage and stage:FindFirstChild("DarknessPart")
	if not collect then return "missing" end
	local data = OtherData and OtherData:FindFirstChild("Stage" .. (n - 1))
	local t0 = os.clock()
	while true do
		Heartbeat:Wait()
		if not active(id) then return "stopped" end
		if not isAlive(hum) or not char.Parent then return "dead" end
		char:PivotTo(collect.CFrame * CFrame.new(0, 0, -20))
		zeroVelocity(char)
		data = data or (OtherData and OtherData:FindFirstChild("Stage" .. (n - 1)))
		local t = os.clock() - t0
		if data then
			if data.Value ~= "" then return "ok" end
		elseif t > 0.5 then
			return "ok" -- значения этапа нет в игре: не зависаем, идём дальше
		end
		if t > FARM.StageTimeout then return "timeout" end
	end
end

-- забор сундука: триггер каждый кадр ищется заново (после смены карты старый объект пропадает)
local chestBusy = false
local function touchChest(id, char, hum)
	local t0, frames = os.clock(), 0
	pcall(function()
		repeat
			local trig = findChestTrigger()
			if trig and char.Parent then
				local old = trig.CFrame
				trig.CFrame = char:GetPivot()
				local root = char:FindFirstChild("HumanoidRootPart")
				if root and firetouchinterest then
					pcall(firetouchinterest, root, trig, 0)
					Heartbeat:Wait()
					pcall(firetouchinterest, root, trig, 1)
				else
					Heartbeat:Wait()
				end
				pcall(function() trig.CFrame = old end)
			else
				Heartbeat:Wait()
			end
			frames += 1
			local od = player:FindFirstChild("OtherData")
			local e = od and od:FindFirstChild("End")
			if frames >= 6 and e and e.Value ~= "" then break end
		until not isAlive(hum) or not active(id) or os.clock() - t0 > 5
	end)
end

-- один круг. Возвращает true, если персонажа нужно сбросить (круг пройден или завис)
local function runCycle(id, char, hum)
	if not farmRefs() then
		setStatus("Жду загрузки игры…")
		task.wait(1)
		return false
	end
	chestBusy = false
	local stuck, n = 0, FARM.StartStage
	while n <= 10 do
		if not active(id) or not isAlive(hum) then return false end
		setStatus("Этап " .. n .. " / 10")
		local res = collectStage(n, id, char, hum)
		if res == "stopped" or res == "dead" then return false end
		if res == "timeout" then
			stuck += 1
			if stuck >= 3 then
				setStatus("Этап завис — перезапуск круга")
				return true
			end
			setStatus("Этап " .. n .. " завис, повтор " .. stuck)
		else
			stuck = 0
			if n ~= FARM.ChestStage then
				fireClaim()
			elseif cfg.ClaimChest then
				chestBusy = true
				task.spawn(function()
					task.wait(FARM.ChestDelay)
					if active(id) and isAlive(hum) then touchChest(id, char, hum) end
					chestBusy = false
				end)
			end
			n += 1
		end
	end
	-- круг пройден: дожидаемся сундука, удерживая персонажа на месте (чтобы не упал в воду)
	local hold, t0 = char:GetPivot(), os.clock()
	while chestBusy and active(id) and isAlive(hum) and os.clock() - t0 < 6 do
		Heartbeat:Wait()
		char:PivotTo(hold)
		zeroVelocity(char)
	end
	return true
end

local function farmLoop(id)
	while active(id) do
		local ok, err = pcall(function()
			local char, hum = waitCharacter(id)
			if not char then return end
			local needReset = runCycle(id, char, hum)
			if needReset and active(id) and isAlive(hum) then
				setStatus("Сброс персонажа…")
				resetCharacter(char, hum)
			end
			if active(id) then setStatus("Ждём респавн…") end
		end)
		if not ok then
			warn("[BabftREZ] AutoFarm: " .. tostring(err))
			setStatus("Ошибка, перезапуск…")
			task.wait(1)
		end
	end
end

local function setAutoFarm(v)
	cfg.AutoFarm = v
	farmId += 1
	if v then
		session.gained, session.last = 0, readGold()
		session.startT, session.running = os.clock(), true
		setStatus("Запуск…")
		if not refreshPaths() then notify("Ты не в BABFT или игра изменилась", C.red) end
		task.spawn(farmLoop, farmId)
	else
		if session.running then session.running, session.endT = false, os.clock() end
		setStatus("Выключен")
	end
	setStats(statsText())
end
cleanups[#cleanups + 1] = function()
	cfg.AutoFarm = false
	farmId += 1
	session.running = false
end

---------------------------------------------------------------- QUESTS (логика из BbaftoREZ)
local function GetZone() return workspace[player.TeamColor.Name .. "Zone"] end
local function GetQuest() return GetZone():WaitForChild("Quest") end

local function Place(Name, Pos)
	local BTool = player.Backpack:FindFirstChild("BuildingTool") or player.Character:FindFirstChild("BuildingTool")
	if not BTool then return end
	if BTool.Parent ~= player.Character then BTool.Parent = player.Character end
	task.spawn(function()
		BTool.RF:InvokeServer(Name, player.Data[Name].Value, nil, nil, false, Pos, false)
	end)
end

local Quests = {
	function()
		local Quest = GetQuest()
		Quest:WaitForChild("Cloud"):WaitForChild("Part1").CFrame = player.Character:GetPivot()
	end,
	function()
		local Quest = GetQuest()
		local Target = Quest:WaitForChild("Target")
		local Done = false
		repeat
			for _, Part in Target:GetChildren() do
				if Part.Name == "Part" and Part:FindFirstChildOfClass("Script") then
					Done = true
					Part.CFrame = player.Character:GetPivot()
					break
				end
			end
			task.wait()
		until Done
	end,
	function()
		local Quest = GetQuest()
		local Ramp = Quest:WaitForChild("Ramp")
		local Done = false
		repeat
			for _, Part in Ramp:GetChildren() do
				if Part.Name == "Part" and Part:FindFirstChildOfClass("TouchTransmitter") then
					Done = true
					Part.CFrame = player.Character:GetPivot()
					break
				end
			end
			task.wait()
		until Done
	end,
	function()
		local Quest = GetQuest()
		local Zone = GetZone()
		repeat
			task.wait()
			if not Quest then break end
			local Butter = Quest:FindFirstChild("Butter")
			if not Butter then continue end
			local Part = Butter:FindFirstChild("PPart")
			if not Part then continue end
			local Click = Part:FindFirstChildOfClass("ClickDetector")
			if not Click then continue end
			fireclickdetector(Click)
		until not Zone:FindFirstChild("Quest")
	end,
	function() end,
	function()
		local Zone = GetZone()
		local Quest = GetQuest()
		local MBox = Quest:WaitForChild("MBox")
		if not MBox then return end
		local PPart = MBox:WaitForChild("PPart")
		if not PPart then return end
		Place("Seat", PPart.CFrame * CFrame.new(2, 0, 0))
		local Finished = false
		blocksFolder[player.Name].ChildAdded:Once(function(SeatModel)
			local Char = player.Character
			local Hum = Char.Humanoid
			SeatModel:WaitForChild("Seat"):Sit(Hum)
			repeat task.wait() until Hum.Sit
			Zone.VoteLaunchRE:FireServer()
			task.wait(.5)
			Char:PivotTo(ChestTrigger.CFrame * CFrame.new(0, 0, 0))
			task.wait(5)
			Finished = true
		end)
		repeat task.wait() until Finished
	end,
	function() end,
	function() end,
	function()
		local Collect = Stages.CaveStage1.DarknessPart
		local StageData = OtherData.Stage0
		local Char = player.Character
		if not Char then return end
		local Hum = Char:FindFirstChildOfClass("Humanoid")
		if not Hum then return end
		repeat
			task.wait()
			if not Char then continue end
			Char:PivotTo(Collect.CFrame * CFrame.new(0, -60, -10))
			zeroVelocity(Char)
		until StageData.Value ~= "" or not Char or not Hum or Hum.Health <= 0
		player.Character:PivotTo(ChestTrigger.CFrame)
	end,
}

local Questing = false
local function completeQuests()
	local Zone = GetZone()
	if Zone:FindFirstChild("Quest") then
		StartQuest:FireServer(0)
		repeat task.wait() until not Zone:FindFirstChild("Quest")
		task.wait(1)
	end
	for Num, Callback in pairs(Quests) do
		if Num == 7 then Num = 8 end
		if OtherData:FindFirstChild("Q" .. Num) or Num == 5 or Num == 8 then continue end
		StartQuest:FireServer(Num)
		Callback()
		local Z = GetZone()
		repeat task.wait() until not Z:FindFirstChild("Quest")
		task.wait(1)
	end
end

---------------------------------------------------------------- BUILDING: копирование баз (логика из BbaftoREZ)
local usedList = {}
local ignoreAnchored = true
local clipboard, selectedBase = nil, nil
local pastePercent = 0
local pasting = false

local function getBlockID(name)
	return blockData:FindFirstChild(name) and blockData:FindFirstChild(name).Value or 9
end

local function setTransparency(transparencyWanted, block)
	if not block then return end
	if block.PPart.Transparency == transparencyWanted then return end
	local calls = transparencyWanted / 0.25
	local tool = character:FindFirstChild("PropertiesTool") or player.Backpack:FindFirstChild("PropertiesTool")
	if tool.Parent ~= character then humanoid:EquipTool(tool) task.wait() end
	local args = { "Transparency", { block } }
	task.spawn(function()
		for i = 1, calls do tool.SetPropertieRF:InvokeServer(unpack(args)) end
	end)
end

local function rescaleBlock(block, newPos, newSize)
	if not block then return end
	local tool = character:FindFirstChild("ScalingTool") or player.Backpack:FindFirstChild("ScalingTool")
	if tool.Parent ~= character then humanoid:EquipTool(tool) task.wait() end
	task.spawn(function() tool.RF:InvokeServer(block, newSize, newPos) end)
end

local function getPlayerZone(p)
	local teamColor = p.TeamColor
	for _, v in pairs(workspace:GetChildren()) do
		if v:FindFirstChild("TeamColor") and v.TeamColor.Value == teamColor then return v end
	end
end

local function placeBlock(name, pos, relativeTo, Anchored)
	local tool = character:FindFirstChild("BuildingTool") or player.Backpack:FindFirstChild("BuildingTool")
	if tool.Parent ~= character then humanoid:EquipTool(tool) task.wait() end
	if not relativeTo then relativeTo = getPlayerZone(player) end
	local args = { name, getBlockID(name), relativeTo,
		relativeTo and relativeTo.CFrame:ToObjectSpace(pos) or CFrame.new(),
		ignoreAnchored and true or Anchored, pos, false }
	task.spawn(function() tool.RF:InvokeServer(unpack(args)) end)
end

local function paintBlock(block, color)
	if not block or not block:FindFirstChild("PPart") then return end
	if block.PPart.Color == color then return end
	local tool = character:FindFirstChild("PaintingTool") or player.Backpack:FindFirstChild("PaintingTool")
	if tool.Parent ~= character then humanoid:EquipTool(tool) task.wait() end
	task.spawn(function() tool.RF:InvokeServer({ { block, color } }) end)
end

local function getJoint(model)
	for _, v in pairs(model.PPart:GetChildren()) do
		if v:IsA("Snap") or v:IsA("Weld") then
			if v.Part1 and not (v.Part1.Parent == model) then return v.Part1 end
		end
	end
	return getPlayerZone(player)
end

local function getNewBlockPos(hisBase, block, myBase)
	if not block or not block:FindFirstChild("PPart") then return CFrame.new() end
	if not hisBase or not myBase then return block.PPart.CFrame end
	return myBase.CFrame * hisBase.CFrame:ToObjectSpace(block.PPart.CFrame)
end

local function copyBuild(blocks)
	usedList = {} -- сброс счётчика блоков перед каждым копированием
	local t = {}
	local myBase = getPlayerZone(player)
	local hisBase = getPlayerZone(Players:FindFirstChild(blocks.Name))
	for _, block in ipairs(blocks:GetChildren()) do
		if block:FindFirstChild("PPart") then
			if not (getBlockID(block.Name) == 0 or (usedList[block.Name] or 0) > getBlockID(block.Name)) then
				local relative = getJoint(block)
				relative = relative == hisBase and myBase or relative
				usedList[block.Name] = (usedList[block.Name] or 0) + 1
				table.insert(t, {
					Name = block.Name,
					Pos = getNewBlockPos(hisBase, block, myBase),
					Relative = getPlayerZone(player),
					Transparency = block.PPart.Transparency,
					Anchored = block.PPart.Anchored,
					Size = block.PPart.Size,
					Color = block.PPart.Color,
				})
			end
		end
	end
	return t
end

local function getBlock(expected, createdList)
	local best, bestDist = nil, math.huge
	for _, b in ipairs(createdList) do
		if b and b:FindFirstChild("PPart") and b.Name == expected.Name then
			local dist = (b.PPart.Position - expected.Pos.Position).Magnitude
			if dist < bestDist then bestDist = dist; best = b end
		end
	end
	return best
end

local function getPlayerBase()
	for _, child in pairs(blocksFolder:GetChildren()) do
		if child.Name == player.Name then return child end
	end
end

local function pasteBuild(t, folder)
	pastePercent = 0
	local c
	local tCount = math.max(#t, 1)
	local lastPlaced = tick()
	c = folder.ChildAdded:Connect(function() lastPlaced = tick() end)
	for i, v in ipairs(t) do
		placeBlock(v.Name, v.Pos, v.Relative, v.Anchored)
		pastePercent += 50 / tCount
		if i % 20 == 0 then task.wait(0.05) end
	end
	repeat task.wait(0.1) until tick() - lastPlaced > 5
	local playerBaseList = folder:GetChildren()
	for i, v in ipairs(t) do
		local b = getBlock(v, playerBaseList)
		rescaleBlock(b, v.Pos, v.Size)
		paintBlock(b, v.Color)
		setTransparency(v.Transparency, b)
		if i % 20 == 0 then task.wait(0.05) end
		pastePercent += 50 / tCount
	end
	c:Disconnect()
	pastePercent = 0
end

local function playerOptions()
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		out[#out + 1] = { label = p.DisplayName .. "  (@" .. p.Name .. ")", value = p.Name }
	end
	return out
end

---------------------------------------------------------------- Персонаж и Anti-AFK
track(player.CharacterAdded:Connect(function(c)
	c:WaitForChild("Humanoid")
	c:WaitForChild("HumanoidRootPart")
	bindChar(c)
end))

-- Anti-AFK всегда включён: фарм не кикает за бездействие
track(player.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end))

---------------------------------------------------------------- Вкладки
-- Auto Farm
local farmPage = Tab("Auto Farm")
Section(farmPage, "АВТОФАРМ ЗОЛОТА")
setStatus = Status(farmPage, "Выключен")
setStats = Status(farmPage, statsText())
Toggle(farmPage, "Auto Farm", "Проходит этапы и забирает золото", false, setAutoFarm)
Toggle(farmPage, "Claim Chest", "Забирать сундук в конце", true, function(v) cfg.ClaimChest = v end)
task.spawn(function()
	while gui.Parent do
		if session.running then
			local g = readGold()
			if g then
				if session.last and g > session.last then session.gained += g - session.last end
				session.last = g
			end
		end
		pcall(setStats, statsText())
		task.wait(0.25)
	end
end)

-- Quests
local questPage = Tab("Quests")
Section(questPage, "КВЕСТЫ")
Button(questPage, "Complete Quests", "Выполняет все доступные квесты", "Start", function(b)
	if Questing then return end
	if not needGame() then return end
	Questing = true
	b.Text = "Running…"
	task.spawn(function()
		local ok = pcall(completeQuests)
		Questing = false
		b.Text = "Start"
		notify(ok and "Квесты выполнены" or "Ошибка при выполнении квестов", ok and C.green or C.red)
	end)
end)

-- Building
local buildPage = Tab("Auto Build")
Section(buildPage, "AUTO BUILD — КОПИРОВАНИЕ БАЗ")
Dropdown(buildPage, "Выбрать игрока", playerOptions, function(name)
	selectedBase = nil
	refreshPaths()
	if blocksFolder then
		for _, folder in ipairs(blocksFolder:GetChildren()) do
			if folder.Name == name then selectedBase = folder end
		end
	end
	if not selectedBase then notify("У игрока нет базы", C.gold) end
end)
Button(buildPage, "Copy Base", "Скопировать базу выбранного игрока", "Copy", function()
	if not needGame() then return end
	if not selectedBase then notify("Сначала выбери игрока", C.gold) return end
	local ok, res = pcall(copyBuild, selectedBase)
	if ok then
		clipboard = res
		notify("Скопировано блоков: " .. #res, C.green)
	else
		notify("Ошибка копирования", C.red)
	end
end)
Button(buildPage, "Paste Base", "Построить скопированную базу у себя", "Paste", function()
	if not needGame() then return end
	if not clipboard then notify("Сначала скопируй базу", C.gold) return end
	if pasting then notify("Уже строится…", C.gold) return end
	pasting = true
	task.spawn(function()
		local ok = pcall(function() pasteBuild(clipboard, getPlayerBase()) end)
		pasting = false
		pastePercent = 0
		notify(ok and "База построена" or "Ошибка постройки", ok and C.green or C.red)
	end)
end)
local setProgress = Progress(buildPage, "Auto Build Progress")
task.spawn(function()
	while gui.Parent do
		setProgress(pastePercent)
		task.wait(0.2)
	end
end)
Section(buildPage, "AUTO BUILD SETTINGS")
Button(buildPage, "Place Wood Block", "Поставить деревянный блок под собой", "Place", function()
	if not needGame() then return end
	pcall(placeBlock, "WoodBlock", HRP.CFrame, nil, true)
end)
local rescaleClick = false
Toggle(buildPage, "Rescale Block (click)", "Клик по блоку — размер 4×4×4", false, function(v) rescaleClick = v end)
do
	local mouse = player:GetMouse()
	track(mouse.Button1Down:Connect(function()
		if rescaleClick and mouse.Target then
			pcall(rescaleBlock, mouse.Target.Parent, mouse.Target.CFrame, Vector3.new(4, 4, 4))
		end
	end))
end
Toggle(buildPage, "Ignore Anchored State", "Не учитывать закрепление блоков", true, function(v) ignoreAnchored = v end)

---------------------------------------------------------------- Player (скорость, прыжок, полёт, ноуклип)
do
	local ok, err = pcall(function()
		local P = { Speed = false, SpeedValue = 50, Jump = false, JumpValue = 100, Fly = false, FlySpeed = 60, Noclip = false }
		local playerCleanup
		local genv = (getgenv and getgenv()) or _G
		if typeof(genv["BabftREZ_PlayerUnload"]) == "function" then pcall(genv["BabftREZ_PlayerUnload"]) end
		genv["BabftREZ_PlayerUnload"] = nil

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
					flyBV = new("BodyVelocity", { Name = "BabftREZ_FlyBV", MaxForce = Vector3.new(9e9, 9e9, 9e9), Velocity = Vector3.zero }, hrp)
					flyBG = new("BodyGyro", { Name = "BabftREZ_FlyBG", MaxTorque = Vector3.new(9e9, 9e9, 9e9), P = 9e4, D = 500, CFrame = cam.CFrame }, hrp)
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
			if genv["BabftREZ_PlayerUnload"] == playerCleanup then genv["BabftREZ_PlayerUnload"] = nil end
		end
		genv["BabftREZ_PlayerUnload"] = playerCleanup

		-- остатки полёта от прошлой копии этого скрипта
		do
			local ch0, hum0 = getChar()
			if ch0 then
				local found = false
				for _, d in ipairs(ch0:GetDescendants()) do
					if d.Name == "BabftREZ_FlyBV" or d.Name == "BabftREZ_FlyBG" then found = true; d:Destroy() end
				end
				if found and hum0 then hum0.PlatformStand = false end
			end
		end
		local playerPage = Tab("Player")
		Section(playerPage, "БЕГ И ПРЫЖОК")
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

		Section(playerPage, "ПОЛЁТ И СТЕНЫ")
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
			.. "Чтобы лететь сквозь стены, включи ещё и Noclip. Не включай Fly во время Auto Farm. Использование на свой риск.", 12, C.mut, false)
		hint.Size, hint.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
		hint.TextWrapped, hint.TextYAlignment, hint.LayoutOrder = true, Enum.TextYAlignment.Top, nextOrder()
		cleanups[#cleanups + 1] = function() playerCleanup() end
	end)
	if not ok then
		warn("[BabftREZ] Player: " .. tostring(err))
		pcall(notify, "Player: ошибка, см. консоль", C.red)
	end
end

selectTab("Auto Farm")

---------------------------------------------------------------- Свернуть / закрыть
local hidden = false
local bubble = new("TextButton", { Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0, 16, 0.5, -27),
	Text = "B", TextSize = 24, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = C.acc, AutoButtonColor = false, Visible = false, ZIndex = 50 }, gui)
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
		task.delay(0.25, function() if hidden then root.Visible = false; bubble.Visible = true end end)
	else
		bubble.Visible = false
		root.Visible = true
		TweenService:Create(win, TI, { GroupTransparency = 0 }):Play()
	end
end
makeDraggable(bubble, bubble, function() setHidden(false) end)
bubbleBtn.MouseButton1Click:Connect(function() setHidden(true) end)
closeBtn.MouseButton1Click:Connect(function()
	for _, f in ipairs(cleanups) do pcall(f) end
	for _, c in ipairs(conns) do c:Disconnect() end
	TweenService:Create(win, TI, { GroupTransparency = 1 }):Play()
	bubble.Visible = false
	task.delay(0.3, function() gui:Destroy() end)
end)
track(UserInputService.InputBegan:Connect(function(i, gp)
	if not gp and i.KeyCode == Enum.KeyCode.RightShift then setHidden(not hidden) end
end))

TweenService:Create(win, TweenInfo.new(0.4), { GroupTransparency = 0 }):Play()
