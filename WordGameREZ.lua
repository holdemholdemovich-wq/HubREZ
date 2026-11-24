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
	WatchWorld = true, -- читать слова противника с экрана и из мира
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
local seenW = {}
-- 0 = принято, 1 = не только русские буквы, 2 = длина не 3–20, 3 = повтор
local function addWord(w)
	w = lowerRu((w:gsub("[%s%c]", "")))
	local n = utf8.len(w)
	if not n then return 1 end
	for _, cp in utf8.codes(w) do if not isCyr(cp) then return 1 end end
	if n < 3 or n > 20 then return 2 end
	if seenW[w] then return 3 end
	seenW[w] = true
	local l = firstLetter(w)
	byLetter[l] = byLetter[l] or {}
	table.insert(byLetter[l], w)
	wordCount += 1
	return 0
end
local FALLBACK = "дом море енот тигр рыба аист торт тоннель лиса арбуз зебра апельсин нос слон нора ананас сок кот табурет тюлень нитка автобус сад дождь ёж жираф финик конь ёлка автомат тетрадь дерево облако окно ножницы собака арка аквариум мяч человек конфета ананас стол лимон носорог хлеб бабочка"
local function loadWords()
	local st = { source = "нет", lines = 0, ok = 0, badChars = 0, badLen = 0, dup = 0 }
	local path = "HubREZ_" .. (WORDS_FILE:gsub("[/\\]", "_"))
	local txt
	-- 1) свой файл в папке исполнителя (приоритет), 2) свежий с GitHub, 3) кэш прошлого запуска
	pcall(function() if isfile and isfile("WordGameREZ_words.txt") then txt = readfile("WordGameREZ_words.txt") st.source = "локальный файл" end end)
	if not txt then
		local okNet, fresh = pcall(function() return game:HttpGet(GITHUB_RAW .. WORDS_FILE .. "?t=" .. os.time()) end)
		if okNet and type(fresh) == "string" and #fresh > 100 then
			txt, st.source = fresh, "GitHub"
			pcall(function() writefile(path, fresh) end)
		else
			pcall(function() if isfile and isfile(path) then txt = readfile(path) st.source = "кэш" end end)
		end
	end
	if txt and #txt > 100 then
		for w in txt:gmatch("[^\r\n]+") do
			st.lines += 1
			local r = addWord(w)
			if r == 0 then st.ok += 1 elseif r == 1 then st.badChars += 1 elseif r == 2 then st.badLen += 1 else st.dup += 1 end
		end
	end
	if wordCount < 500 then for w in FALLBACK:gmatch("%S+") do addWord(w) end st.source = st.source .. " + мини-список" end
	return st
end

---------------------------------------------------------------- Журнал
local logLines = {}
local onLog = function() end
local function log(msg)
	logLines[#logLines + 1] = os.date("%H:%M:%S") .. "  " .. msg
	if #logLines > 14 then table.remove(logLines, 1) end
	onLog()
end

---------------------------------------------------------------- Поиск элементов игры на экране
local pg = player:WaitForChild("PlayerGui")
local selfGui = nil -- наше меню (чтобы не читать его тексты)

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

-- по чему тапать: ближайшая кнопка (или сам объект: тап идёт по координатам)
local function tapTarget(o)
	local cur = o
	while cur and cur ~= pg do
		if cur:IsA("GuiButton") then return cur end
		cur = cur.Parent
	end
	return o
end

local function pathOf(o)
	return (o:GetFullName():gsub("^.-PlayerGui%.", ""))
end

local function isWordLike(clean)
	local n = utf8.len(clean)
	if not n or n < 3 or n > 16 then return false end
	for _, cp in utf8.codes(clean) do if not isCyr(cp) then return false end end
	return true
end

-- Один проход по экрану: клавиатура (одинаковые по размеру кнопки-буквы), «Ввод/Стереть», поле со словом (буквы в строку), слова на экране
local function scan()
	local singles, words, texts = {}, {}, {}
	local enter, erase, eraseAll
	local stat = { texts = 0, single = 0, hidden = 0, hiddenSamples = {} }
	for _, o in ipairs(pg:GetDescendants()) do
		if (o:IsA("TextLabel") or o:IsA("TextButton")) and not (selfGui and o:IsDescendantOf(selfGui)) then
			local ok, clean = pcall(norm, o.Text)
			if ok and clean ~= "" then
				stat.texts += 1
				local isVis = visible(o)
				local n = utf8.len(clean)
				if isVis then
					if stat.texts < 400 and n and n <= 40 then texts[clean] = true end
					if clean == "ввод" then enter = tapTarget(o)
					elseif clean == "стереть всё" or clean == "стереть все" then eraseAll = tapTarget(o)
					elseif clean == "стереть" then erase = tapTarget(o)
					elseif isWordLike(clean) then words[#words + 1] = clean end
				end
				if n and n <= 3 then
					local letter, cnt = nil, 0
					for _, cp in utf8.codes(clean) do if isCyr(cp) then cnt += 1 letter = utf8.char(cp) end end
					if cnt == 1 then
						stat.single += 1
						if isVis then singles[#singles + 1] = { obj = o, letter = letter, isKey = false }
						else
							stat.hidden += 1
							if #stat.hiddenSamples < 5 then stat.hiddenSamples[#stat.hiddenSamples + 1] = letter .. " @ " .. pathOf(o) end
						end
					end
				end
			end
		end
	end

	-- клавиатура = самая большая группа букв одного размера (≥20 штук)
	local bestN, bestSz = 0, nil
	for _, a in ipairs(singles) do
		local c, sa = 0, a.obj.AbsoluteSize
		for _, b in ipairs(singles) do
			local sb = b.obj.AbsoluteSize
			if math.abs(sa.X - sb.X) <= 5 and math.abs(sa.Y - sb.Y) <= 5 then c += 1 end
		end
		if c > bestN then bestN, bestSz = c, sa end
	end
	local keys, nKeys, keyParent = {}, 0, nil
	if bestN >= 20 then
		for _, s in ipairs(singles) do
			local sz = s.obj.AbsoluteSize
			if math.abs(sz.X - bestSz.X) <= 5 and math.abs(sz.Y - bestSz.Y) <= 5 then
				s.isKey = true
				if not keys[s.letter] then keys[s.letter] = tapTarget(s.obj) nKeys += 1 keyParent = keyParent or s.obj.Parent end
			end
		end
	end

	-- поле со словом: остальные одиночные буквы, собранные в одну строку (по Y), слева направо
	local groups = {}
	for _, s in ipairs(singles) do
		if not s.isKey then
			local y = s.obj.AbsolutePosition.Y
			local g
			for _, gg in ipairs(groups) do if math.abs(gg.y - y) < 25 then g = gg break end end
			if not g then g = { y = y, items = {} } groups[#groups + 1] = g end
			g.items[#g.items + 1] = s
		end
	end
	local bestG
	for _, g in ipairs(groups) do
		if not bestG or #g.items > #bestG.items then bestG = g end
	end
	local row = ""
	if bestG then
		table.sort(bestG.items, function(a, b) return a.obj.AbsolutePosition.X < b.obj.AbsolutePosition.X end)
		local t, lastX, lastL = {}, -1e9, nil
		for _, s in ipairs(bestG.items) do
			local x = s.obj.AbsolutePosition.X
			if not (lastL == s.letter and math.abs(x - lastX) < 4) then t[#t + 1] = s.letter end -- дубль-обводка на том же месте
			lastX, lastL = x, s.letter
		end
		row = table.concat(t)
	end
	return { keys = keys, nKeys = nKeys, enter = enter, erase = erase, eraseAll = eraseAll, row = row, words = words, texts = texts, stat = stat, keyParent = keyParent }
end

---------------------------------------------------------------- Нажатие на кнопку (сам подбирает рабочий способ)
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local METHODS = { "vim_auto", "signal", "vim_raw", "vim_inset", "touch" }
local method, methodOk = 1, false

local function center(btn, mode)
	local pos, size = btn.AbsolutePosition, btn.AbsoluteSize
	local inset = Vector2.zero
	if mode == "inset" then
		inset = GuiService:GetGuiInset()
	elseif mode == "auto" then
		local sg = btn:FindFirstAncestorOfClass("ScreenGui")
		if not (sg and sg.IgnoreGuiInset) then inset = GuiService:GetGuiInset() end
	end
	return pos.X + size.X / 2 + inset.X, pos.Y + size.Y / 2 + inset.Y
end

local function tapWith(btn, m)
	if not btn or not btn.Parent then return false end
	local name = METHODS[m]
	local ok = pcall(function()
		if name == "signal" then
			assert(btn:IsA("GuiButton"), "not a button")
			local fired = false
			for _, sig in ipairs({ "MouseButton1Down", "MouseButton1Click", "Activated", "MouseButton1Up" }) do
				if getconnections then
					for _, c in ipairs(getconnections(btn[sig])) do pcall(function() c:Fire() end) fired = true end
				elseif firesignal then
					firesignal(btn[sig]) fired = true
				end
			end
			assert(fired, "no connections")
		elseif name == "touch" then
			local x, y = center(btn, "auto")
			VIM:SendTouchEvent(1, 0, x, y)
			task.wait(0.03)
			VIM:SendTouchEvent(1, 2, x, y)
		else
			local mode = name == "vim_auto" and "auto" or (name == "vim_inset" and "inset" or "raw")
			local x, y = center(btn, mode)
			VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
			task.wait(0.03)
			VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
		end
	end)
	return ok
end

---------------------------------------------------------------- Логика Auto-Win
local used, bad = {}, {}
local seenCount = 0
local function resetMemory(reason)
	used, bad, seenCount = {}, {}, 0
	log("память слов сброшена: " .. reason)
end
-- чем меньше слов начинается на эту букву, тем сложнее противнику ответить (й, ё, щ, э, ю — самые трудные)
local HARD = { ["ё"] = 6, ["э"] = 6, ["щ"] = 5, ["й"] = 5, ["ю"] = 5, ["ц"] = 3, ["ж"] = 3, ["ф"] = 3, ["х"] = 3, ["ш"] = 2 }
local status = function() end
local onScan = function() end
local alive = true
local busy = false

local function pickWord(letter)
	local list = byLetter[letter]
	if not list then return nil end
	local best, bestScore
	for _ = 1, 900 do
		local w = list[math.random(1, #list)]
		if not used[w] and not bad[w] then
			if not Settings.HardEnds then return w end
			local chs = chars(w)
			local score = HARD[chs[#chs]] or 0
			if not bestScore or score > bestScore then best, bestScore = w, score end
			if score >= 6 then break end
		end
	end
	if best then return best end
	for _, w in ipairs(list) do if not used[w] and not bad[w] then return w end end
	return nil
end

local function lcp(a, b)
	local i = 0
	while i < #a and i < #b and a[i + 1] == b[i + 1] do i += 1 end
	return i
end

local function waitRowChange(prevRow, timeout)
	local t0 = tick()
	while tick() - t0 < timeout do
		task.wait(0.07)
		local ok, s = pcall(scan)
		if ok and s.row ~= prevRow then return s end
	end
	return nil
end

-- набирает слово, глядя на поле: сверяет каждую букву, лишнее стирает, неверный способ нажатия меняет
local function typeWord(w, s0)
	local target = chars(w)
	local s = s0
	local fails, rotations, guard = 0, 0, 0
	while alive do
		guard += 1
		if guard > 70 then return false, "слишком много шагов" end
		if s.nKeys < 20 then return false, "клавиатура пропала" end
		local rc = chars(s.row)
		local p = lcp(rc, target)
		if #rc == #target and p == #target then return true, s end
		local btn, ch
		if #rc > p then
			if (#rc - p) >= 3 and s.eraseAll then btn = s.eraseAll else btn = s.erase or s.eraseAll end
			if not btn then return false, "нет кнопки «Стереть»" end
		else
			ch = target[p + 1]
			btn = s.keys[ch]
			if not btn then return false, "нет клавиши «" .. ch .. "»" end
		end
		tapWith(btn, method)
		local ns = waitRowChange(s.row, 0.7)
		local good = false
		if ns then
			local nrc = chars(ns.row)
			if ch then good = (lcp(nrc, target) > p and #nrc == #rc + 1) else good = (#nrc < #rc) end
			s = ns
		end
		if good then
			if not methodOk then log("способ нажатия: " .. METHODS[method]) end
			methodOk, fails = true, 0
			task.wait(Settings.Delay / 1000)
		else
			fails += 1
			if not methodOk then
				method = method % #METHODS + 1
				rotations += 1
				if rotations >= #METHODS * 2 then return false, "нажатия не срабатывают" end
			elseif fails >= 3 then
				return false, "нет реакции (не мой ход?)"
			end
		end
	end
	return false, "остановлено"
end

local ERR = { "нет такого", "не найден", "не существует", "уже был", "уже назван", "уже использ", "повтор", "ошибк", "неверн", "не принят", "не подход" }
local function isErrText(t)
	for _, p in ipairs(ERR) do if t:find(p, 1, true) then return true end end
	return false
end

-- один ход: слово → Ввод → если не засчитали, другое слово на ту же букву
local function playTurn(L, s)
	for attempt = 1, 6 do
		if not alive or not Settings.AutoWin then return "stopped" end
		local w = pickWord(L)
		if not w then
			status("Нет подходящих слов на «" .. L .. "»", C.red)
			log("нет слов на «" .. L .. "»")
			return "nowords"
		end
		used[w] = true
		status("Пишу: " .. w)
		log("пишу: " .. w)
		local ok, res = typeWord(w, s)
		if not ok then
			log("не набрал «" .. w .. "»: " .. tostring(res))
			status("Не смог набрать: " .. tostring(res), C.red)
			return "typefail"
		end
		s = res
		local before = s.texts
		tapWith(s.enter, method)
		local t0, rejected, changed, last = tick(), false, false, nil
		while tick() - t0 < 2.6 do
			task.wait(0.15)
			local sk, ns = pcall(scan)
			if sk then
				last = ns
				for t in pairs(ns.texts) do
					if not before[t] and not isErrText(t) and #t < 60 then log("новый текст: " .. t) end
					if not before[t] and isErrText(t) then rejected = true log("ошибка: " .. t) end
				end
				if rejected then break end
				if ns.row ~= w then changed = true break end
			end
		end
		if changed and not rejected then
			log("засчитано: " .. w)
			status("Засчитано: " .. w .. ". Жду противника…", C.green)
			return "ok"
		end
		bad[w] = true
		log("не засчитано: " .. w)
		status("Не засчитано: " .. w .. " — пробую другое", C.gold)
		s = last or scan()
		if s.nKeys < 20 then return "typefail" end
	end
	return "failed"
end

-- память слов сбрасывается сама: игра закончилась (клавиатура пропала), герой умер или встал из-за стола
local function resetMemory(reason)
	local n = 0
	for _ in pairs(used) do n += 1 end
	if n == 0 and seenCount == 0 then return end
	used, bad, seenCount = {}, {}, 0
	log("память слов сброшена: " .. reason)
end

local function hookCharacter(char)
	task.spawn(function()
		local hum = char:WaitForChild("Humanoid", 15)
		if not hum or not alive then return end
		track(hum.Died:Connect(function() resetMemory("герой умер") end))
		track(hum:GetPropertyChangedSignal("Sit"):Connect(function()
			if not hum.Sit then
				task.delay(0.5, function() if alive and not hum.Sit then resetMemory("встал из-за стола") end end)
			end
		end))
	end)
end
if player.Character then hookCharacter(player.Character) end
track(player.CharacterAdded:Connect(function(char)
	resetMemory("новый персонаж")
	hookCharacter(char)
end))

-- слова противника/свои с экрана и из мира (над головами) попадают в «использованные»
local function rememberWords(list)
	for _, w in ipairs(list) do
		if not used[w] then used[w] = true seenCount += 1 end
	end
end

task.spawn(function()
	local turn = { waitChange = false, lastL = nil, lastDone = 0 }
	local hadKb, kbLostAt = false, nil
	local kbSeen, kbLostAt = false, nil
	while alive do
		task.wait(0.4)
		local ok, err = pcall(function()
			local s = scan()
			if Settings.WatchWorld then rememberWords(s.words) end
			local kb = s.nKeys >= 20 and s.enter ~= nil
			if kb then
				kbSeen, kbLostAt = true, nil
			elseif kbSeen then
				kbLostAt = kbLostAt or tick()
				if tick() - kbLostAt >= 3 then
					kbSeen, kbLostAt = false, nil
					resetMemory("игра закончилась")
				end
			end
			onScan(s, kb)
			if kb then
				hadKb, kbLostAt = true, nil
			elseif hadKb then
				kbLostAt = kbLostAt or tick()
				if tick() - kbLostAt >= 4 then
					hadKb, kbLostAt = false, nil
					resetMemory("игра закончилась (клавиатура исчезла)")
				end
			end
			if not Settings.AutoWin or busy then return end
			if not kb then
				status("Жду клавиатуру — сядь за стол к игроку")
				turn.waitChange = false
				return
			end
			local rowN = utf8.len(s.row) or 0
			if rowN ~= 1 then
				turn.waitChange = false
				status("Жду свой ход…")
				return
			end
			local L = s.row
			if turn.waitChange and L == turn.lastL and tick() - turn.lastDone < 8 then return end
			busy = true
			status("Моя буква «" .. L .. "» — отвечаю…")
			log("мой ход, буква «" .. L .. "»")
			task.wait(Settings.ThinkTime / 1000)
			local res = playTurn(L, scan())
			turn.lastL, turn.lastDone, turn.waitChange = L, tick(), (res ~= "stopped")
			busy = false
		end)
		if not ok then busy = false status("Ошибка: " .. tostring(err):sub(1, 60), C.red) log("ошибка: " .. tostring(err):sub(1, 80)) end
	end
end)

local function hookChar(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	track(hum.Died:Connect(function() resetMemory("герой погиб") end))
	local wasSit = hum.Sit
	track(hum:GetPropertyChangedSignal("Sit"):Connect(function()
		if wasSit and not hum.Sit then resetMemory("герой встал") end
		wasSit = hum.Sit
	end))
end
if player.Character then task.spawn(hookChar, player.Character) end
track(player.CharacterAdded:Connect(function(c) resetMemory("респавн") task.spawn(hookChar, c) end))

-- слова в мире (BillboardGui/SurfaceGui над игроками), раз в пару секунд, без подвисаний
task.spawn(function()
	while alive do
		task.wait(2.5)
		if Settings.WatchWorld then
			pcall(function()
				local found, i = {}, 0
				for _, o in ipairs(workspace:GetDescendants()) do
					i += 1
					if i % 2500 == 0 then task.wait() end
					if o:IsA("TextLabel") and o.Visible then
						local ok, clean = pcall(norm, o.Text)
						if ok and isWordLike(clean) and (o:FindFirstAncestorWhichIsA("BillboardGui") or o:FindFirstAncestorWhichIsA("SurfaceGui")) then found[#found + 1] = clean end
					end
				end
				rememberWords(found)
			end)
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

selfGui = gui
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
newTab("Auto-Win", "Auto-Win")

section(mainPage, "АВТО-ОТВЕТ")
newToggle(mainPage, "Auto-Win", "Сам пишет слово на нужную букву", "AutoWin")
newSlider(mainPage, "Скорость нажатий (пауза)", "Delay", 20, 600, " мс")
newSlider(mainPage, "Пауза перед ответом", "ThinkTime", 0, 4000, " мс")
newToggle(mainPage, "Сложные слова", "Слова-ловушки на й, ё, щ, ю, ц, ж, ф, х", "HardEnds")
newToggle(mainPage, "Следить за словами", "Свои и чужие слова не повторяются", "WatchWorld")
section(mainPage, "СОСТОЯНИЕ")
local kbCard = card(mainPage, 50)
local kbLabel = label(kbCard, "Клавиатура: ищу…", 12, C.mut, false)
kbLabel.Position, kbLabel.Size = UDim2.fromOffset(14, 4), UDim2.new(1, -28, 1, -8)
kbLabel.TextWrapped = true
local stCard = card(mainPage, 50)
local stLabel = label(stCard, "Словарь: загрузка…", 12, C.mut, false)
stLabel.Position, stLabel.Size = UDim2.fromOffset(14, 4), UDim2.new(1, -28, 1, -8)
stLabel.TextWrapped = true
status = function(text, color)
	stLabel.Text = text
	stLabel.TextColor3 = color or C.mut
end
onScan = function(s, kb)
	if kb then
		kbLabel.Text = string.format("Клавиатура найдена: %d клавиш · в поле: «%s»\nСлов в памяти: %d (чужих/своих с экрана: %d)", s.nKeys, s.row, (function() local n = 0 for _ in pairs(used) do n += 1 end return n end)(), seenCount)
		kbLabel.TextColor3 = C.green
	else
		kbLabel.Text = "Клавиатура не найдена — сядь за стол к игроку, скрипт заметит её сам"
		kbLabel.TextColor3 = C.mut
	end
end

task.spawn(function()
	local st = loadWords()
	status("Слов в словаре: " .. wordCount .. " (" .. st.source .. ")")
	log(string.format("словарь: %d слов, источник: %s", wordCount, st.source))
	log(string.format("строк в файле: %d; принято: %d; не буквы: %d; длина не 3–20: %d; повторы: %d", st.lines, st.ok, st.badChars, st.badLen, st.dup))
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
