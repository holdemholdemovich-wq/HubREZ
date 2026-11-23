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
	Delay = 150,       -- пауза между нажатиями клавиш (мс)
	ThinkTime = 800,   -- пауза перед началом ответа (мс)
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

-- текст без тегов, лишних пробелов, в нижнем регистре
local function norm(t)
	t = tostring(t or ""):gsub("<[^>]->", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	return lowerRu(t)
end

-- по чему тапать: ближайшая кнопка (или сам объект — тап идёт по координатам)
local function tapTarget(o)
	local cur = o
	while cur and cur ~= pg do
		if cur:IsA("GuiButton") then return cur end
		cur = cur.Parent
	end
	return o
end

local function pathOf(o)
	local p = o:GetFullName()
	return (p:gsub("^.-PlayerGui%.", ""))
end

-- клавиатура: одиночные русские буквы, собранные в один контейнер (≥20 штук); нужная буква — одиночная буква ВНЕ клавиатуры
local function scan()
	local singles, enter, erase, eraseAll = {}, nil, nil, nil
	local stat = { texts = 0, single = 0, hidden = 0, hiddenSamples = {} }
	for _, o in ipairs(pg:GetDescendants()) do
		if o:IsA("TextLabel") or o:IsA("TextButton") then
			local ok, clean = pcall(norm, o.Text)
			if ok and clean ~= "" then
				stat.texts += 1
				local n = utf8.len(clean)
				local isVis = visible(o)
				if isVis then
					if clean == "ввод" then enter = tapTarget(o)
					elseif clean == "стереть всё" or clean == "стереть все" then eraseAll = tapTarget(o)
					elseif clean == "стереть" then erase = tapTarget(o) end
				end
				if n and n <= 3 then
					local letter, cnt = nil, 0
					for _, cp in utf8.codes(clean) do if isCyr(cp) then cnt += 1 letter = utf8.char(cp) end end
					if cnt == 1 then
						stat.single += 1
						if isVis then singles[#singles + 1] = { obj = o, letter = letter }
						else
							stat.hidden += 1
							if #stat.hiddenSamples < 5 then stat.hiddenSamples[#stat.hiddenSamples + 1] = letter .. " @ " .. pathOf(o) end
						end
					end
				end
			end
		end
	end

	-- контейнер клавиатуры: самый глубокий предок, под которым ≥20 одиночных букв
	local counts, depth = {}, {}
	for _, s in ipairs(singles) do
		local cur, d = s.obj.Parent, 0
		local chain = {}
		while cur and cur ~= pg do chain[#chain + 1] = cur cur = cur.Parent end
		for i, anc in ipairs(chain) do
			counts[anc] = (counts[anc] or 0) + 1
			depth[anc] = #chain - i
		end
	end
	local container, bestDepth = nil, -1
	for anc, c in pairs(counts) do
		if c >= 20 and depth[anc] > bestDepth then container, bestDepth = anc, depth[anc] end
	end

	local keys, nKeys, target, best = {}, 0, nil, -1
	for _, s in ipairs(singles) do
		local inside = (container == nil) or s.obj:IsDescendantOf(container)
		if inside then
			local cur = keys[s.letter]
			if not cur or s.obj.AbsoluteSize.Magnitude > cur.AbsoluteSize.Magnitude then
				if not cur then nKeys += 1 end
				keys[s.letter] = s.obj
			end
		else
			local size = s.obj:IsA("TextLabel") and s.obj.TextSize or s.obj.AbsoluteSize.Y
			if size > best then best, target = size, s.letter end
		end
	end
	for l, o in pairs(keys) do keys[l] = tapTarget(o) end
	return { keys = keys, nKeys = nKeys, enter = enter, erase = erase, eraseAll = eraseAll, letter = target, stat = stat, container = container }
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
	if s.eraseAll then tap(s.eraseAll) task.wait(Settings.Delay / 1000) end
	for _, ch in ipairs(chars(w)) do
		if not alive then return false end
		local key = s.keys[ch]
		if not key then return false end
		tap(key)
		task.wait(Settings.Delay / 1000)
	end
	task.wait(Settings.Delay / 1000)
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
				task.wait(Settings.ThinkTime / 1000)
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

---------------------------------------------------------------- GUI (как у остальных меню REZ)
local WIN_W, WIN_H, HEADER_H = 540, 370, 50
local GUI_NAME = "WordGameREZ"
local function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
local order = 0
local function nextOrder() order += 1 return order end
local function gradient(obj, c1, c2, rot) return new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rot or 0 }, obj) end

local function containers()
	local list = {}
	pcall(function() if gethui then list[#list + 1] = gethui() end end)
	pcall(function() list[#list + 1] = game:GetService("CoreGui") end)
	list[#list + 1] = pg
	return list
end
for _, c in ipairs(containers()) do pcall(function() local o = c:FindFirstChild(GUI_NAME) if o then o:Destroy() end end) end

local gui = new("ScreenGui", { Name = GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999 }, nil)
pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
do
	local ok = pcall(function() if gethui then gui.Parent = gethui() else error("x") end end)
	if not (ok and gui.Parent) then
		ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
		if not (ok and gui.Parent) then gui.Parent = pg end
	end
end

local root = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundTransparency = 1 }, gui)
local uiScale = new("UIScale", {}, root)
local function updateScale()
	local vp = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(vp.X * 0.94 / WIN_W, vp.Y * 0.9 / WIN_H), 0.45, 1.15)
end
updateScale()
track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))

local win = new("CanvasGroup", { Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundColor3 = C.bg, BorderSizePixel = 0, GroupTransparency = 1 }, root)
corner(win, 16)
local winBg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, win)
gradient(winBg, C.bg2, C.bg, 55)
local winStroke = stroke(win, C.acc, 1.5, 0.35)
gradient(winStroke, C.acc2, C.acc, 90)
TweenService:Create(win, TweenInfo.new(0.4), { GroupTransparency = 0 }):Play()

-- Заголовок
local header = new("Frame", { Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundTransparency = 1 }, win)
local title = label(header, '<font color="#c084fc">WordGame</font>REZ', 18, C.txt, true)
title.Position, title.Size = UDim2.fromOffset(54, 6), UDim2.new(0.6, 0, 0, 24)
local logo = new("ImageLabel", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(12, 8), BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Fit }, header)
applyAsset(logo, "gameimages/logo.png")
local sub = label(header, "Word Game [RU]  ·  mobile + PC", 11, C.mut, false)
sub.Position, sub.Size = UDim2.fromOffset(54, 28), UDim2.new(0.6, 0, 0, 16)
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
	local pc = new("Frame", { Position = UDim2.new(0, 10, 1, -58), Size = UDim2.fromOffset(112, 48), BackgroundColor3 = C.card, BorderSizePixel = 0 }, body)
	corner(pc, 12) stroke(pc, C.line, 1)
	local av = new("ImageLabel", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(7, 7), BackgroundColor3 = C.bg, BorderSizePixel = 0,
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150" }, pc)
	corner(av, 17)
	local nm = label(pc, player.DisplayName, 12, C.txt, true)
	nm.Position, nm.Size, nm.TextTruncate = UDim2.fromOffset(46, 8), UDim2.new(1, -50, 0, 16), Enum.TextTruncate.AtEnd
	local un = label(pc, "@" .. player.Name, 10, C.mut, false)
	un.Position, un.Size, un.TextTruncate = UDim2.fromOffset(46, 25), UDim2.new(1, -50, 0, 14), Enum.TextTruncate.AtEnd
end

-- Страницы / вкладки
local pages, tabs = {}, {}
local function newPage(name)
	local p = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.acc,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false, ScrollingDirection = Enum.ScrollingDirection.Y }, content)
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
	local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.acc, BackgroundTransparency = 1, Text = text, TextColor3 = C.mut, TextSize = 14,
		Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, LayoutOrder = nextOrder() }, side)
	corner(b, 10)
	new("UIPadding", { PaddingLeft = UDim.new(0, 16) }, b)
	local bar = new("Frame", { Size = UDim2.new(0, 3, 0.6, 0), Position = UDim2.new(0, -10, 0.2, 0), BackgroundColor3 = C.acc2, BorderSizePixel = 0, Visible = false }, b)
	corner(bar, 2)
	b.MouseButton1Click:Connect(function() selectTab(name) end)
	tabs[name] = { btn = b, bar = bar }
end

-- Компоненты
local function section(parent, text)
	local l = label(parent, text, 11, C.mut, true)
	l.Size, l.LayoutOrder = UDim2.new(1, 0, 0, 18), nextOrder()
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

local function newToggle(parent, text, subtext, key)
	local row = card(parent, 54)
	local t = label(row, text, 14, C.txt, true)
	t.Position, t.Size = UDim2.fromOffset(14, 9), UDim2.new(1, -76, 0, 18)
	local s = label(row, subtext, 12, C.mut, false)
	s.Position, s.Size = UDim2.fromOffset(14, 28), UDim2.new(1, -76, 0, 16)
	local sw = new("TextButton", { Size = UDim2.fromOffset(46, 26), Position = UDim2.new(1, -60, 0.5, -13), Text = "", AutoButtonColor = false, BackgroundColor3 = C.off }, row)
	corner(sw, 13)
	local knob = new("Frame", { Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = Color3.fromRGB(154, 154, 181), BorderSizePixel = 0 }, sw)
	corner(knob, 10)
	local state = Settings[key]
	local function render(anim)
		local info = anim and TI or TweenInfo.new(0)
		TweenService:Create(sw, info, { BackgroundColor3 = state and C.acc or C.off }):Play()
		TweenService:Create(knob, info, { Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
			BackgroundColor3 = state and Color3.new(1, 1, 1) or Color3.fromRGB(154, 154, 181) }):Play()
	end
	render(false)
	sw.MouseButton1Click:Connect(function() state = not state Settings[key] = state render(true) end)
	return row
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
	local knob = new("Frame", { Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2 }, trackF)
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
	local sf = parent:FindFirstAncestorOfClass("ScrollingFrame") or parent
	local function setX(x)
		local a = math.clamp((x - trackF.AbsolutePosition.X) / trackF.AbsoluteSize.X, 0, 1)
		Settings[key] = math.floor((min + (max - min) * a) / 10 + 0.5) * 10
		render()
	end
	hit.InputBegan:Connect(function(i)
		if isPress(i) then
			dragging = true
			if sf:IsA("ScrollingFrame") then sf.ScrollingEnabled = false end
			setX(i.Position.X)
		end
	end)
	track(UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then setX(i.Position.X) end
	end))
	track(UserInputService.InputEnded:Connect(function(i)
		if dragging and isPress(i) then
			dragging = false
			if sf:IsA("ScrollingFrame") then sf.ScrollingEnabled = true end
		end
	end))
	render()
	return row
end

---------------------------------------------------------------- Страницы
local mainPage = newPage("Auto-Win")
local debugPage = newPage("Debug")
newTab("Auto-Win", "Auto-Win")
newTab("Debug", "Debug")

section(mainPage, "АВТО-ОТВЕТ")
newToggle(mainPage, "Auto-Win", "Сам пишет слово на нужную букву", "AutoWin")
newSlider(mainPage, "Скорость нажатий (пауза)", "Delay", 20, 600, " мс")
newSlider(mainPage, "Пауза перед ответом", "ThinkTime", 0, 4000, " мс")
newToggle(mainPage, "Трудные окончания", "Слова на щ, ц, ф, э, ю, ё, ж, х", "HardEnds")
section(mainPage, "СТАТУС")
local stCard = card(mainPage, 50)
local stLabel = label(stCard, "Словарь: загрузка…", 12, C.mut, false)
stLabel.Position, stLabel.Size = UDim2.fromOffset(14, 4), UDim2.new(1, -28, 1, -8)
stLabel.TextWrapped = true
stLabel.TextYAlignment = Enum.TextYAlignment.Center
status = function(text, color)
	stLabel.Text = text
	stLabel.TextColor3 = color or C.mut
end

section(debugPage, "ПРОВЕРКА ИГРЫ")
local scanCard = card(debugPage, 54)
local sT = label(scanCard, "Scan", 14, C.txt, true)
sT.Position, sT.Size = UDim2.fromOffset(14, 9), UDim2.new(1, -110, 0, 18)
local sS = label(scanCard, "Ищет клавиши, «Ввод», «Стереть», букву", 12, C.mut, false)
sS.Position, sS.Size = UDim2.fromOffset(14, 28), UDim2.new(1, -110, 0, 16)
local scanBtn = new("TextButton", { Text = "Scan", TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = C.acc, AutoButtonColor = false,
	Size = UDim2.fromOffset(70, 30), Position = UDim2.new(1, -84, 0.5, -15) }, scanCard)
corner(scanBtn, 9)
local outCard = card(debugPage, 190)
local outLabel = label(outCard, "Открой клавиатуру в игре (когда твой ход) и нажми Scan. Результат копируется в буфер.", 11, C.mut, false)
outLabel.Position, outLabel.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -24, 1, -16)
outLabel.TextWrapped, outLabel.TextYAlignment = true, Enum.TextYAlignment.Top

scanBtn.MouseButton1Click:Connect(function()
	local ok, s = pcall(scan)
	if not ok then outLabel.Text = "Ошибка Scan: " .. tostring(s) return end
	local letters = {}
	for k in pairs(s.keys) do letters[#letters + 1] = k end
	table.sort(letters)
	local lines = {
		string.format("Клавиш найдено: %d", s.nKeys),
		"Ввод: " .. tostring(s.enter ~= nil) .. "  Стереть: " .. tostring(s.erase ~= nil) .. "  Стереть всё: " .. tostring(s.eraseAll ~= nil),
		"Нужная буква: " .. tostring(s.letter),
		"Буквы: " .. table.concat(letters, " "),
		string.format("Текстов на экране: %d, одиночных букв: %d (скрыто: %d)", s.stat.texts, s.stat.single, s.stat.hidden),
		"Контейнер клавиатуры: " .. (s.container and pathOf(s.container) or "не определён"),
	}
	if s.stat.hidden > 0 then
		lines[#lines + 1] = "Скрытые буквы (клавиатура могла быть закрыта):"
		for _, h in ipairs(s.stat.hiddenSamples) do lines[#lines + 1] = "  " .. h end
	end
	local text = table.concat(lines, "\n")
	outLabel.Text = text
	outLabel.TextColor3 = s.nKeys >= 20 and C.txt or C.gold
	pcall(function() if setclipboard then setclipboard(text) end end)
end)

task.spawn(function()
	loadWords()
	status("Слов в словаре: " .. wordCount .. (wordCount < 500 and " (мини-список: нет words/ru_words.txt)" or ""))
end)

selectTab("Auto-Win")

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

local bubble = new("TextButton", { Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0, 16, 0.5, -27), Text = "W", TextSize = 24, Font = Enum.Font.GothamBold,
	TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = C.acc, AutoButtonColor = false, Visible = false, ZIndex = 50 }, gui)
corner(bubble, 27)
stroke(bubble, Color3.new(1, 1, 1), 1.5, 0.6)
do
	local bi = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Fit, ZIndex = 51 }, bubble)
	corner(bi, 27)
	applyAsset(bi, "gameimages/logo.png", function() bubble.Text = "" bubble.BackgroundTransparency = 1 end)
end

local function setHidden(v)
	hidden = v
	if v then
		TweenService:Create(win, TI, { GroupTransparency = 1 }):Play()
		task.delay(0.25, function() if hidden then root.Visible = false bubble.Visible = true end end)
	else
		bubble.Visible = false
		root.Visible = true
		TweenService:Create(win, TI, { GroupTransparency = 0 }):Play()
	end
end
makeDraggable(bubble, bubble, function() setHidden(false) end)
bubbleBtn.MouseButton1Click:Connect(function() setHidden(true) end)

local function unload()
	alive = false
	Settings.AutoWin = false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(function() gui:Destroy() end)
end
closeBtn.MouseButton1Click:Connect(function()
	TweenService:Create(win, TI, { GroupTransparency = 1 }):Play()
	bubble.Visible = false
	task.delay(0.3, unload)
end)
genv.WordGameREZ_Unload = unload

track(UserInputService.InputBegan:Connect(function(i, gp)
	if not gp and i.KeyCode == Enum.KeyCode.RightShift then setHidden(not hidden) end
end))
