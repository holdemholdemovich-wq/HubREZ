-- ============================================================
-- BabftREZ — Build A Boat For Treasure (Auto Farm / Fun / ESP)
-- Телефон + ПК. Запускать из HubREZ или напрямую в исполнителе.
-- ============================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera or workspace:WaitForChild("Camera")

local PALETTE = {
	Color3.fromRGB(139, 92, 246), Color3.fromRGB(34, 211, 238), Color3.fromRGB(244, 114, 182),
	Color3.fromRGB(74, 222, 128), Color3.fromRGB(251, 146, 60), Color3.fromRGB(248, 250, 252),
}

local cfg = {
	AutoFarm = false, AutoClaim = true, ClaimChest = true,
	StartStage = 2, ChestClaimStage = 2, ChestClaimDelay = 1,
	WalkSpeed = 16, JumpPower = 50, Noclip = false, Fly = false, FlySpeed = 60, AntiAFK = true,
	ESP = false, ESPNames = true, ESPColor = PALETTE[1],
}

---------------------------------------------------------------- Тема и помощники
local C = {
	bg = Color3.fromRGB(14, 14, 22), bg2 = Color3.fromRGB(24, 18, 42),
	card = Color3.fromRGB(23, 23, 36), line = Color3.fromRGB(40, 40, 62),
	txt = Color3.fromRGB(235, 235, 247), mut = Color3.fromRGB(128, 128, 158),
	acc = Color3.fromRGB(139, 92, 246), acc2 = Color3.fromRGB(192, 132, 252),
	off = Color3.fromRGB(44, 44, 66), green = Color3.fromRGB(34, 197, 94),
	red = Color3.fromRGB(239, 68, 68), gold = Color3.fromRGB(250, 204, 21),
}
local WIN_W, WIN_H, HEADER_H = 520, 340, 50
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
title.Position, title.Size = UDim2.fromOffset(18, 6), UDim2.new(0.6, 0, 0, 26)
local sub = label(header, "Build A Boat For Treasure", 11, C.mut, false)
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

local body = new("Frame", { Position = UDim2.fromOffset(0, HEADER_H), Size = UDim2.new(1, 0, 1, -HEADER_H), BackgroundTransparency = 1 }, win)
local side = new("Frame", { Size = UDim2.new(0, 120, 1, 0), BackgroundTransparency = 1 }, body)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, side)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, side)
new("Frame", { Position = UDim2.new(0, 120, 0, 8), Size = UDim2.new(0, 1, 1, -16), BackgroundColor3 = C.line, BorderSizePixel = 0 }, body)
local content = new("Frame", { Position = UDim2.fromOffset(121, 0), Size = UDim2.new(1, -121, 1, 0), BackgroundTransparency = 1 }, body)

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

	local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.acc, BackgroundTransparency = 1,
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
	stroke(f, C.line, 1)
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

---------------------------------------------------------------- AUTO FARM
local setStatus = function() end
local farming, farmConn = false, nil

local function getPaths()
	local bs = workspace:FindFirstChild("BoatStages")
	local stages = bs and bs:FindFirstChild("NormalStages")
	local od = player:FindFirstChild("OtherData")
	local theEnd = stages and stages:FindFirstChild("TheEnd")
	local gc = theEnd and theEnd:FindFirstChild("GoldenChest")
	local chest = gc and gc:FindFirstChild("Trigger")
	local claim = workspace:FindFirstChild("ClaimRiverResultsGold")
	return stages, od, chest, claim
end

local function zeroVelocity(char)
	for _, p in ipairs(char:GetChildren()) do
		if p:IsA("BasePart") then
			p.AssemblyLinearVelocity = Vector3.zero
			p.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function collectStage(n, stages, od)
	local stage = stages:FindFirstChild("CaveStage" .. n)
	local collect = stage and stage:FindFirstChild("DarknessPart")
	if not collect then return end
	local data = od:FindFirstChild("Stage" .. (n - 1))
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	repeat
		task.wait()
		char = player.Character
		if not char or not char.Parent then break end
		char:PivotTo(collect.CFrame * CFrame.new(0, 0, -20))
		zeroVelocity(char)
	until (data and data.Value ~= "") or hum.Health <= 0 or not cfg.AutoFarm
end

local function touchChest(chest, od)
	task.spawn(function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		repeat
			local old = chest.CFrame
			chest.CFrame = char:GetPivot()
			task.wait()
			chest.CFrame = old
		until (od:FindFirstChild("End") and od.End.Value ~= "") or hum.Health <= 0 or not cfg.AutoFarm
	end)
end

local function farm()
	if farming or not cfg.AutoFarm then return end
	local stages, od, chest, claim = getPaths()
	if not (stages and od and chest and claim) then
		notify("Ты не в BABFT или игра изменилась", C.red)
		return
	end
	local char = player.Character or player.CharacterAdded:Wait()
	local hum = char:WaitForChild("Humanoid")
	farming = true
	for n = cfg.StartStage, 10 do
		if not cfg.AutoFarm or hum.Health <= 0 then break end
		setStatus("Этап " .. n .. " / 10")
		local done = false
		task.spawn(function() collectStage(n, stages, od); done = true end)
		repeat task.wait() until done or hum.Health <= 0 or not cfg.AutoFarm
		if n ~= cfg.ChestClaimStage then
			if cfg.AutoClaim then claim:FireServer() end
		elseif cfg.ClaimChest then
			task.spawn(function()
				task.wait(cfg.ChestClaimDelay)
				touchChest(chest, od)
			end)
		end
	end
	farming = false
	if cfg.AutoFarm and hum.Health > 0 then
		setStatus("Сброс персонажа…")
		char:BreakJoints()
	else
		setStatus(cfg.AutoFarm and "Ждём респавн…" or "Выключен")
	end
end

local function setAutoFarm(v)
	cfg.AutoFarm = v
	if v then
		if farmConn then farmConn:Disconnect() end
		farmConn = player.CharacterAdded:Connect(function() task.spawn(farm) end)
		setStatus("Запуск…")
		task.spawn(farm)
	else
		if farmConn then farmConn:Disconnect() farmConn = nil end
		setStatus("Выключен")
	end
end
cleanups[#cleanups + 1] = function()
	cfg.AutoFarm = false
	if farmConn then farmConn:Disconnect() end
end

---------------------------------------------------------------- FUN: скорость, прыжок, noclip, fly
local function getHum()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function applyMove()
	local h = getHum()
	if h then
		h.WalkSpeed = cfg.WalkSpeed
		h.UseJumpPower = true
		h.JumpPower = cfg.JumpPower
	end
end

local flyBV, flyBG
local function stopFly()
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
end
local function startFly()
	stopFly()
	local root = getRoot()
	if not root then return end
	flyBV = new("BodyVelocity", { MaxForce = Vector3.one * 9e9, Velocity = Vector3.zero }, root)
	flyBG = new("BodyGyro", { MaxTorque = Vector3.one * 9e9, P = 9e4, CFrame = root.CFrame }, root)
end
local function setFly(v)
	cfg.Fly = v
	if v then startFly() else stopFly() end
end

track(RunService.RenderStepped:Connect(function()
	-- полёт: на телефоне джойстик + наклон камеры, на ПК WASD + Space/Shift
	if cfg.Fly and flyBV and flyBV.Parent then
		local hum = getHum()
		local cam = workspace.CurrentCamera
		if hum and cam then
			local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
			local fl, fr = Vector3.new(look.X, 0, look.Z), Vector3.new(right.X, 0, right.Z)
			if fl.Magnitude > 0.001 then fl = fl.Unit end
			if fr.Magnitude > 0.001 then fr = fr.Unit end
			local md = hum.MoveDirection
			local move = look * md:Dot(fl) + right * md:Dot(fr)
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.new(0, 1, 0) end
			if move.Magnitude > 1 then move = move.Unit end
			flyBV.Velocity = move * cfg.FlySpeed
			flyBG.CFrame = cam.CFrame
		end
	end
end))

track(RunService.Stepped:Connect(function()
	if cfg.Noclip then
		local c = player.Character
		if c then
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = false end
			end
		end
	end
end))

track(player.CharacterAdded:Connect(function(c)
	c:WaitForChild("Humanoid")
	task.wait(0.3)
	applyMove()
	if cfg.Fly then startFly() end
end))
cleanups[#cleanups + 1] = stopFly

track(player.Idled:Connect(function()
	if cfg.AntiAFK then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end
end))

---------------------------------------------------------------- ESP (подсветка + ники)
local function clearESP()
	for _, plr in ipairs(Players:GetPlayers()) do
		local c = plr.Character
		if c then
			local hl = c:FindFirstChild("REZ_ESP")
			if hl then hl:Destroy() end
			local head = c:FindFirstChild("Head")
			local bb = head and head:FindFirstChild("REZ_NAME")
			if bb then bb:Destroy() end
		end
	end
end
local function refreshESP()
	for _, plr in ipairs(Players:GetPlayers()) do
		local c = plr ~= player and plr.Character
		if c then
			local hl = c:FindFirstChild("REZ_ESP")
			if cfg.ESP then
				if not hl then
					hl = new("Highlight", { Name = "REZ_ESP", FillTransparency = 0.6, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, c)
				end
				hl.FillColor, hl.OutlineColor = cfg.ESPColor, cfg.ESPColor
			elseif hl then
				hl:Destroy()
			end
			local head = c:FindFirstChild("Head")
			local bb = head and head:FindFirstChild("REZ_NAME")
			if cfg.ESP and cfg.ESPNames and head then
				if not bb then
					bb = new("BillboardGui", { Name = "REZ_NAME", AlwaysOnTop = true, Size = UDim2.fromOffset(140, 20), StudsOffset = Vector3.new(0, 2.5, 0) }, head)
					new("TextLabel", { Name = "T", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
						TextSize = 14, TextStrokeTransparency = 0.3 }, bb)
				end
				bb.T.Text = plr.DisplayName
				bb.T.TextColor3 = cfg.ESPColor
			elseif bb then
				bb:Destroy()
			end
		end
	end
end
task.spawn(function()
	while gui.Parent do
		pcall(refreshESP)
		task.wait(0.5)
	end
end)
cleanups[#cleanups + 1] = clearESP

---------------------------------------------------------------- Вкладки
local farmPage = Tab("Auto Farm")
Section(farmPage, "АВТОФАРМ ЗОЛОТА")
setStatus = Status(farmPage, "Выключен")
Toggle(farmPage, "Auto Farm", "Проходит этапы и забирает золото", false, setAutoFarm)
Slider(farmPage, "Стартовый этап", 1, 10, cfg.StartStage, "", function(v) cfg.StartStage = v end)
Slider(farmPage, "Этап сундука", 1, 10, cfg.ChestClaimStage, "", function(v) cfg.ChestClaimStage = v end)
Slider(farmPage, "Задержка сундука", 0, 5, cfg.ChestClaimDelay, " сек", function(v) cfg.ChestClaimDelay = v end)
Toggle(farmPage, "Auto Claim Gold", "Забирать золото после этапов", true, function(v) cfg.AutoClaim = v end)
Toggle(farmPage, "Claim Chest", "Забирать сундук в конце", true, function(v) cfg.ClaimChest = v end)

local funPage = Tab("Fun")
Section(funPage, "ДВИЖЕНИЕ")
Slider(funPage, "Скорость", 16, 200, cfg.WalkSpeed, "", function(v) cfg.WalkSpeed = v; applyMove() end)
Slider(funPage, "Прыжок", 50, 300, cfg.JumpPower, "", function(v) cfg.JumpPower = v; applyMove() end)
Toggle(funPage, "Noclip", "Проходить сквозь стены", false, function(v) cfg.Noclip = v end)
Toggle(funPage, "Fly", "Телефон: джойстик + камера. ПК: WASD, Space/Shift", false, setFly)
Slider(funPage, "Скорость полёта", 20, 300, cfg.FlySpeed, "", function(v) cfg.FlySpeed = v end)
Section(funPage, "ПРОЧЕЕ")
Toggle(funPage, "Anti-AFK", "Не даёт кикнуть за бездействие", true, function(v) cfg.AntiAFK = v end)
Button(funPage, "Reset Character", "Перезайти персонажем", "Reset", function()
	local h = getHum()
	if h then h.Health = 0 end
end)

local espPage = Tab("ESP")
Section(espPage, "ИГРОКИ")
Toggle(espPage, "ESP", "Подсветка игроков сквозь стены", false, function(v) cfg.ESP = v; refreshESP() end)
Toggle(espPage, "Ники", "Имя над головой", true, function(v) cfg.ESPNames = v; refreshESP() end)
do
	local idx = 1
	Button(espPage, "Цвет", "Нажми, чтобы сменить", "Сменить", function(b)
		idx = idx % #PALETTE + 1
		cfg.ESPColor = PALETTE[idx]
		b.BackgroundColor3 = PALETTE[idx]
		refreshESP()
	end)
end

selectTab("Auto Farm")

---------------------------------------------------------------- Свернуть / закрыть
local hidden = false
local bubble = new("TextButton", { Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0, 16, 0.5, -27),
	Text = "B", TextSize = 24, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = C.acc, AutoButtonColor = false, Visible = false, ZIndex = 50 }, gui)
corner(bubble, 27)
stroke(bubble, Color3.new(1, 1, 1), 1.5, 0.6)

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
