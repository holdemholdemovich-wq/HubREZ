-- WordGameREZ — меню для Word Game [RU]: Auto-Win (сам отвечает словами на нужную букву, нажимая экранные клавиши).
-- Запускать в исполнителе (Delta и др.) внутри игры. Телефон + ПК.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera or workspace:WaitForChild("Camera")

local genv = (getgenv and getgenv()) or _G
if typeof(genv.WordGameREZ_Unload) == "function" then pcall(genv.WordGameREZ_Unload) end
genv.WordGameREZ_Unload = nil

---------------------------------------------------------------- Настройки
local GITHUB_RAW = "https://raw.githubusercontent.com/holdemholdemovich-wq/HubREZ/main/"
local WORDS_FILE = "words/ru_words.txt" -- словарь: одно слово в строке, русские существительные/слова

local Settings = {
	AutoWin = false,
	Delay = 0.15,      -- пауза между нажатиями клавиш (сек)
	ThinkTime = 0.8,   -- пауза перед началом ответа (сек)
	HardEnds = true,   -- выбирать слова, заканчивающиеся на «трудные» буквы
}

---------------------------------------------------------------- Помощники
local C = {
	bg = Color3.fromRGB(14, 14, 22), bg2 = Color3.fromRGB(24, 18, 42), card = Color3.fromRGB(23, 23, 36),
	line = Color3.fromRGB(40, 40, 62), txt = Color3.fromRGB(235, 235, 247), mut = Color3.fromRGB(128, 128, 158),
	acc = Color3.fromRGB(139, 92, 246), acc2 = Color3.fromRGB(192, 132, 252), off = Color3.fromRGB(44, 44, 66),
	green = Color3.fromRGB(34, 197, 94), red = Color3.fromRGB(239, 68, 68), gold = Color3.fromRGB(250, 204, 21),
}
local TI = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local conns = {}
local function track(c) conns[#conns + 1] = c return c end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function stroke(o, color, t, tr)
	return new("UIStroke", { Color = color, Thickness = t or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function label(parent, text, size, color, bold)
	return new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color,
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, RichText = true }, parent)
end

local function applyAsset(img, rel, onOk)
	task.spawn(function()
		local ok, a = pcall(function()
			local path = "HubREZ_" .. rel:gsub("[/\\]", "_")
			if not (isfile and isfile(path)) then writefile(path, game:HttpGet(GITHUB_RAW .. rel)) end
			return (getcustomasset or getsynasset)(path)
		end)
		if ok and a and img.Parent then img.Image = a if onOk then onOk() end end
	end)
end

local function makeDraggable(handle, target, onTap)
	local dragging, moved, startPos, startMouse, dragInput = false, false, nil, nil, nil
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, moved, dragInput = true, false, input
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
		local mine = input.UserInputType == Enum.UserInputType.MouseMovement or (input.UserInputType == Enum.UserInputType.Touch and input == dragInput)
		if dragging and mine then
			local d = input.Position - startMouse
			if d.Magnitude > 6 then moved = true end
			if moved then target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end
		end
	end))
end

---------------------------------------------------------------- Русские буквы (Luau не умеет lower() для UTF-8)
local function lowerRu(s)
	local out = {}
	for _, cp in utf8.codes(s) do
		if cp >= 0x410 and cp <= 0x42F then cp += 32 elseif cp == 0x401 then cp = 0x451 end
		out[#out + 1] = utf8.char(cp)
	end
	return table.concat(out)
end
local function isCyr(cp) return (cp >= 0x430 and cp <= 0x44F) or cp == 0x451 end
local function firstLetter(w) return utf8.char(utf8.codepoint(w, 1)) end
local function chars(w) local t = {} for _, cp in utf8.codes(w) do t[#t + 1] = utf8.char(cp) end return t end

---------------------------------------------------------------- Словарь
local byLetter, wordCount = {}, 0
local function addWord(w)
	w = lowerRu((w:gsub("[%s%c]", "")))
	local n = utf8.len(w)
	if not n or n < 3 or n > 14 then return end
	for _, cp in utf8.codes(w) do if not isCyr(cp) then return end end
	local l = firstLetter(w)
	byLetter[l] = byLetter[l] or {}
	table.insert(byLetter[l], w)
	wordCount += 1
end
local FALLBACK = "дом море енот тигр рыба аист торт тоннель лиса арбуз зебра апельсин нос слон нора ананас сок кот табурет тюлень нитка автобус сад дождь ёж жираф финик конь ёлка автомат тетрадь дерево облако окно ножницы собака арка аквариум мяч человек конфета ананас стол лимон носорог хлеб бабочка"
local function loadWords()
	local ok, txt = pcall(function()
		local path = "HubREZ_" .. WORDS_FILE:gsub("[/\\]", "_")
		if not (isfile and isfile(path)) then writefile(path, game:HttpGet(GITHUB_RAW .. WORDS_FILE)) end
		return readfile(path)
	end)
	if ok and txt and #txt > 100 then
		for w in txt:gmatch("[^\r\n]+") do addWord(w) end
	end
	if wordCount < 500 then for w in FALLBACK:gmatch("%S+") do addWord(w) end end
end

---------------------------------------------------------------- Поиск элементов игры на экране
local pg = player:WaitForChild("PlayerGui")

local function visible(o)
	local cur = o
	while cur and cur ~= pg do
		if cur:IsA("GuiObject") and not cur.Visible then return false end
		if cur:IsA("ScreenGui") and not cur.Enabled then return false end
		cur = cur.Parent
	end
	return o.AbsoluteSize.X > 2 and o.AbsoluteSize.Y > 2
end

local function textOf(o)
	if o:IsA("TextButton") or o:IsA("TextLabel") then return o.Text end
	return nil
end

local function trimText(t) return (lowerRu((t or ""):gsub("<[^>]->", ""):gsub("^%s+", ""):gsub("%s+$", ""))) end

-- клавиатура: все кнопки с одной русской буквой + служебные («Ввод», «Стереть», «Стереть всё»)
local function scan()
	local keys, enter, erase, eraseAll, keyParent = {}, nil, nil, nil, nil
	local others = {}
	for _, o in ipairs(pg:GetDescendants()) do
		local t = textOf(o)
		if t and t ~= "" and visible(o) then
			local clean = trimText(t)
			local btn = o:IsA("TextButton") and o or (o.Parent and o.Parent:IsA("GuiButton") and o.Parent) or nil
			if btn then
				if utf8.len(clean) == 1 and isCyr(utf8.codepoint(clean, 1)) then
					if not keys[clean] then keys[clean] = btn end
				elseif clean == "ввод" then enter = btn
				elseif clean == "стереть всё" or clean == "стереть все" then eraseAll = btn
				elseif clean == "стереть" then erase = btn end
			end
			if utf8.len(clean) == 1 and isCyr(utf8.codepoint(clean, 1)) then others[#others + 1] = { obj = o, letter = clean } end
		end
	end
	local nKeys = 0
	for _, b in pairs(keys) do nKeys += 1 keyParent = keyParent or b.Parent end
	-- нужная буква: одиночная русская буква ВНЕ клавиатуры (большой квадрат над персонажем)
	local target, best = nil, -1
	for _, c in ipairs(others) do
		local inKeyboard = false
		for _, b in pairs(keys) do
			if c.obj == b or c.obj:IsDescendantOf(b) then inKeyboard = true break end
		end
		if not inKeyboard then
			local size = c.obj:IsA("TextLabel") and c.obj.TextSize or c.obj.AbsoluteSize.Y
			if size > best then best, target = size, c.letter end
		end
	end
	return { keys = keys, nKeys = nKeys, enter = enter, erase = erase, eraseAll = eraseAll, letter = target }
end

---------------------------------------------------------------- Нажатие на кнопку (тап по экрану, запасной вариант — сигналы)
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local function tap(btn)
	if not btn or not btn.Parent then return false end
	local done = false
	if VIM then
		pcall(function()
			local pos, size = btn.AbsolutePosition, btn.AbsoluteSize
			local sg = btn:FindFirstAncestorOfClass("ScreenGui")
			local inset = (sg and sg.IgnoreGuiInset) and Vector2.zero or GuiService:GetGuiInset()
			local x, y = pos.X + size.X / 2 + inset.X, pos.Y + size.Y / 2 + inset.Y
			VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
			task.wait(0.03)
			VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
			done = true
		end)
	end
	if not done then
		pcall(function()
			for _, sig in ipairs({ "MouseButton1Down", "MouseButton1Click", "Activated", "MouseButton1Up" }) do
				if getconnections then
					for _, c in ipairs(getconnections(btn[sig])) do pcall(function() c:Fire() end) end
				elseif firesignal then
					firesignal(btn[sig])
				end
			end
			done = true
		end)
	end
	return done
end

---------------------------------------------------------------- Логика Auto-Win
local used, bad = {}, {}
local HARD = { ["щ"] = true, ["ц"] = true, ["ф"] = true, ["э"] = true, ["ю"] = true, ["ё"] = true, ["ж"] = true, ["х"] = true }
local status = function() end
local alive = true

local function pickWord(letter)
	local list = byLetter[letter]
	if not list then return nil end
	local fallbackW
	for _ = 1, 400 do
		local w = list[math.random(1, #list)]
		if not used[w] and not bad[w] then
			fallbackW = fallbackW or w
			if not Settings.HardEnds then return w end
			local chs = chars(w)
			if HARD[chs[#chs]] then return w end
		end
	end
	return fallbackW
end

local function typeWord(w, s)
	if s.eraseAll then tap(s.eraseAll) task.wait(Settings.Delay) end
	for _, ch in ipairs(chars(w)) do
		if not alive then return false end
		local key = s.keys[ch]
		if not key then return false end
		tap(key)
		task.wait(Settings.Delay)
	end
	task.wait(Settings.Delay)
	tap(s.enter)
	return true
end

local lastLetter, lastTime, lastWord = nil, 0, nil
local busy = false
task.spawn(function()
	while alive do
		task.wait(0.25)
		if Settings.AutoWin and not busy then
			local ok, err = pcall(function()
				local s = scan()
				if s.nKeys < 20 or not s.enter then status("Жду клавиатуру…") return end
				local L = s.letter
				if not L then status("Не вижу нужную букву (кнопка Scan)") return end
				local now = tick()
				if L == lastLetter and now - lastTime < 4 then return end
				-- та же буква и 4 сек прошло: прошлое слово не приняли
				if L == lastLetter and lastWord then bad[lastWord] = true used[lastWord] = nil end
				busy = true
				status("Буква «" .. L .. "» — думаю…")
				task.wait(Settings.ThinkTime)
				s = scan()
				local w = pickWord(L)
				if not w then status("Нет слов на «" .. L .. "»", C.red) busy = false lastLetter, lastTime = L, tick() return end
				status("Отвечаю: " .. w)
				used[w] = true
				lastLetter, lastTime, lastWord = L, tick(), w
				if not typeWord(w, s) then status("Не нашёл клавишу для «" .. w .. "»", C.red) bad[w] = true end
				lastTime = tick()
				busy = false
			end)
			if not ok then busy = false status("Ошибка: " .. tostring(err):sub(1, 40), C.red) end
		end
	end
end)

---------------------------------------------------------------- GUI
local GUI_NAME = "WordGameREZ"
local function containers()
	local list = {}
	pcall(function() if gethui then list[#list + 1] = gethui() end end)
	pcall(function() list[#list + 1] = game:GetService("CoreGui") end)
	list[#list + 1] = pg
	return list
end
for _, c in ipairs(containers()) do pcall(function() local o = c:FindFirstChild(GUI_NAME) if o then o:Destroy() end end) end

local gui = new("ScreenGui", { Name = GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 998 }, nil)
pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
do
	local ok = pcall(function() if gethui then gui.Parent = gethui() else error("x") end end)
	if not (ok and gui.Parent) then
		ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
		if not (ok and gui.Parent) then gui.Parent = pg end
	end
end

local W, H = 300, 300
local root = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.35), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1 }, gui)
local uiScale = new("UIScale", {}, root)
local function updateScale()
	local vp = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(vp.X * 0.9 / W, vp.Y * 0.8 / H), 0.5, 1.1)
end
updateScale()
track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))

local win = new("CanvasGroup", { Size = UDim2.fromOffset(W, H), BackgroundColor3 = C.bg, BorderSizePixel = 0 }, root)
corner(win, 16)
stroke(win, C.acc, 1.5, 0.35)

local header = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1 }, win)
local logo = new("ImageLabel", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(12, 8), BackgroundTransparency = 1, Image = "" }, header)
corner(logo, 8)
applyAsset(logo, "gameimages/logo.png")
local title = label(header, '<font color="#c084fc">WordGame</font>REZ', 18, C.txt, true)
title.Position, title.Size = UDim2.fromOffset(54, 6), UDim2.new(1, -110, 0, 24)
local sub = label(header, "Word Game [RU]", 11, C.mut, false)
sub.Position, sub.Size = UDim2.fromOffset(54, 30), UDim2.new(1, -110, 0, 14)
new("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.line, BorderSizePixel = 0 }, header)

local function headerBtn(text, index, hover)
	local b = new("TextButton", { Text = text, TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = C.txt, BackgroundColor3 = C.card, AutoButtonColor = false,
		Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -(12 + 38 * index + 32), 0.5, -16) }, header)
	corner(b, 9) stroke(b, C.line, 1)
	b.MouseEnter:Connect(function() TweenService:Create(b, TI, { BackgroundColor3 = hover }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(b, TI, { BackgroundColor3 = C.card }):Play() end)
	return b
end
local closeBtn = headerBtn("×", 0, C.red)
local bubbleBtn = headerBtn("–", 1, C.acc)
makeDraggable(header, root)

local body = new("Frame", { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50), BackgroundTransparency = 1 }, win)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, body)

local ord = 0
local function row(h)
	ord += 1
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = ord }, body)
	corner(f, 10) stroke(f, C.line, 1)
	return f
end

local function toggle(text, key, onChange)
	local f = row(38)
	local l = label(f, text, 13, C.txt, true)
	l.Position, l.Size = UDim2.fromOffset(12, 0), UDim2.new(1, -70, 1, 0)
	local sw = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(40, 22), Position = UDim2.new(1, -52, 0.5, -11), BackgroundColor3 = Settings[key] and C.acc or C.off }, f)
	corner(sw, 11)
	local knob = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = Settings[key] and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3), BackgroundColor3 = C.txt, BorderSizePixel = 0 }, sw)
	corner(knob, 8)
	sw.MouseButton1Click:Connect(function()
		Settings[key] = not Settings[key]
		local on = Settings[key]
		TweenService:Create(sw, TI, { BackgroundColor3 = on and C.acc or C.off }):Play()
		TweenService:Create(knob, TI, { Position = on and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3) }):Play()
		if onChange then onChange(on) end
	end)
end

local function slider(text, key, min, max, step, fmt)
	local f = row(54)
	local l = label(f, text, 13, C.txt, true)
	l.Position, l.Size = UDim2.fromOffset(12, 6), UDim2.new(1, -80, 0, 18)
	local v = label(f, "", 12, C.acc2, true)
	v.Position, v.Size, v.TextXAlignment = UDim2.new(1, -72, 0, 6), UDim2.fromOffset(60, 18), Enum.TextXAlignment.Right
	local bar = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.new(0, 12, 0, 34), Size = UDim2.new(1, -24, 0, 6), BackgroundColor3 = C.off }, f)
	corner(bar, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.acc, BorderSizePixel = 0 }, bar)
	corner(fill, 3)
	local function set(val)
		val = math.clamp(math.floor(val / step + 0.5) * step, min, max)
		Settings[key] = val
		fill.Size = UDim2.fromScale((val - min) / (max - min), 1)
		v.Text = string.format(fmt, val)
	end
	set(Settings[key])
	local dragging = false
	local function fromX(x) set(min + (max - min) * math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)) end
	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true fromX(i.Position.X) end
	end)
	track(UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end
	end))
	track(UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end))
end

toggle("Auto-Win", "AutoWin")
slider("Скорость нажатий (пауза)", "Delay", 0.03, 0.6, 0.01, "%.2f с")
slider("Пауза перед ответом", "ThinkTime", 0, 4, 0.1, "%.1f с")
toggle("Трудные окончания слов", "HardEnds")

local stRow = row(36)
local stLabel = label(stRow, "Словарь: загрузка…", 12, C.mut, false)
stLabel.Position, stLabel.Size = UDim2.fromOffset(12, 0), UDim2.new(1, -84, 1, 0)
stLabel.TextTruncate = Enum.TextTruncate.AtEnd
local scanBtn = new("TextButton", { Text = "Scan", TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = C.txt, BackgroundColor3 = C.acc, AutoButtonColor = false,
	Size = UDim2.fromOffset(56, 24), Position = UDim2.new(1, -66, 0.5, -12) }, stRow)
corner(scanBtn, 8)

status = function(text, color)
	stLabel.Text = text
	stLabel.TextColor3 = color or C.mut
end

scanBtn.MouseButton1Click:Connect(function()
	local s = scan()
	local letters = {}
	for k in pairs(s.keys) do letters[#letters + 1] = k end
	table.sort(letters)
	local info = string.format("клавиш: %d, Ввод: %s, Стереть: %s, Стереть всё: %s, буква: %s",
		s.nKeys, tostring(s.enter ~= nil), tostring(s.erase ~= nil), tostring(s.eraseAll ~= nil), tostring(s.letter))
	status(info)
	pcall(function() if setclipboard then setclipboard(info .. "\n" .. table.concat(letters, " ")) end end)
end)

task.spawn(function()
	loadWords()
	status("Слов в словаре: " .. wordCount .. (wordCount < 500 and " (мини-список, нет words/ru_words.txt)" or ""))
end)

---------------------------------------------------------------- Свернуть / закрыть / выгрузка
local bubble = new("TextButton", { Size = UDim2.fromOffset(48, 48), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.08, 0.3), BackgroundColor3 = C.acc,
	Text = "W", TextColor3 = C.txt, Font = Enum.Font.GothamBold, TextSize = 20, AutoButtonColor = false, Visible = false }, gui)
corner(bubble, 24) stroke(bubble, C.acc2, 2)
local bi = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Crop }, bubble)
corner(bi, 24)
applyAsset(bi, "gameimages/logo.png", function() bubble.Text = "" bubble.BackgroundTransparency = 1 end)

local function setMin(m) root.Visible = not m bubble.Visible = m end
bubbleBtn.MouseButton1Click:Connect(function() setMin(true) end)
makeDraggable(bubble, bubble, function() setMin(false) end)

local function unload()
	alive = false
	Settings.AutoWin = false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(function() gui:Destroy() end)
end
closeBtn.MouseButton1Click:Connect(unload)
genv.WordGameREZ_Unload = unload
