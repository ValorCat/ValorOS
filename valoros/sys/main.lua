
-- debug
local function d(...)
	for _, t in pairs({...}) do
		local v = t
		if type(t) == "table" then
			v = textutils.serialize(t)
		elseif type(t) == "function" then
			v = "[function]"
		end
		print("[DBG] ",type(t)," : '",v,"'")
		sleep(1.5)
	end
end

-- load apis
for _, file in pairs(fs.list("valoros/api/")) do
	os.loadAPI("valoros/api/"..file)
end
read = misc.read

-- setup system[]
local w, h = term.getSize()
system = {}
system.back_color = colors.black
system.display = term.isColor() and "color" or "basic"
system.fs_template = "default"
system.terminal = {width = w, height = h}
system.text_color = colors.white
system.version = "1.0"
w, h = nil

-- redefine default functions
assert = function(exp, msg, lvl)
  	lvl = tonumber(lvl) or 1
  	if not exp then
        error(msg or "assertion failed!", lvl + (lvl == 0 and 0 or 1))
  	end
  	return exp
end

local nMakeDir = fs.makeDir
fs.makeDir = function(p)
	nMakeDir(p)
	return fs.exists(p) and fs.isDir(p)
end

fs.makeBlank = function(p)
	local f = fs.open(p, "w")
	f.close()
end

fs.getDir = fs.getDir or function(p)
	p = p:sub(1, 1) == "/" and p:sub(2) or p
	for i = #p - 1, 1, -1 do
		if p:sub(i, i) == "/" then
			return p:sub(1, i - 1)
		end
	end
	return "/"
end

local nSetTextColor = term.setTextColor
term.setTextColor = function(c)
	nSetTextColor(c)
	system.text_color = c
end

local nSetBackgroundColor = term.setBackgroundColor
term.setBackgroundColor = function(c)
	nSetBackgroundColor(c)
	system.back_color = c
end

clear = function()
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.clear()
	term.setCursorPos(1, 1)
end

getVersion = function()
	return "ValorOS "..tostring(system.version)
end

valExists = function(tab, val)
	assert(type(tab) == "table", "Expected table, got "..type(tab), 2)
	for k, v in pairs(tab) do
		if v == val then
			return k
		end
	end
end

--[[
 + displays welcome screen and logo
 + @param _waitforuser waits for key press to continue
 + @param _hidetext hides title, subtitle, and version
]]
local function welcome(_waitforuser, _hidetext)
	local txt = {title = "V A L O R O S", sub = system.version, msg = "press any key ...", ver = os.version()}
	local col = {back = colors.cyan, border = colors.blue, logo = colors.red, bands = colors.blue,
				 title = colors.black, sub = colors.blue, msg = colors.gray, version = colors.gray}
	local w, h = system.terminal.width, system.terminal.height

	-- basic design
	clear()
	shape.fill(col.back)
	for i = 3, 6 do
		shape.circle(w / 2, h / 2, i, col.logo)
	end
	shape.circle(w / 2, h / 2, 11, col.bands)
	shape.circle(w / 2, h / 2, 12, col.bands)
	--shape.outline(1, 1, w, h, col.border)

	if not _hidetext then
		-- version
		shape.textbox(txt.ver, w - #txt.ver - 1, h, col.back, col.version)

		-- title and subtitle
		term.setTextColor(col.title)
		term.setCursorPos(math.ceil((w - #txt.title) / 2), 8)
		for n = 1, #txt.title do
			local c = string.sub(txt.title, n, n)
			term.setBackgroundColor(col.back)
			local loc = math.ceil((w - #txt.title) / 2) + n - 1
			local half = math.ceil(w / 2)
			if (loc == half - 7) or (loc == half - 5) or
				(loc == half + 3) or (loc == half + 5) then
				term.setBackgroundColor(col.logo)
			end
			term.write(c)
			sleep(0.1)
		end
		shape.textbox(txt.sub, math.ceil((w - #txt.sub) / 2), 10, col.back, col.sub)
	end

	-- wait for input
	if _waitforuser then
		shape.textbox(txt.msg, math.ceil((w - #txt.msg) / 2), h - 2, col.back, col.msg)
		os.pullEvent("key")
		clear()
	end
end

--[[
 + checks filesystem against custom template
 + recreates missing files and directories
 + @param _noregen skips file regen
 + @return missing paths
]]
local function checkfs(_noregen)
	local missing = {}
	for file, lpath in pairs(templates[system.fs_template]) do
		local path = templates[system.fs_template].prefix..lpath
		local dir = path:sub(-1) == "/"
		if not _noregen then
			-- missing file
			if not fs.exists(path) then
				if dir then
					fs.makeDir(path)
				elseif path:sub(-5) == ".conf" then
					local f = config.init(path, fs.getName(path))
					f:load()
					f:getString("pass", "") -- use get (instead of set) to add def val
					f:save()
				else
					fs.makeBlank(path)
				end
				table.insert(missing, file)
			-- wrong type
			elseif (dir and not fs.isDir(path)) or (not dir and fs.isDir(path)) then
				-- copy to /valoros/moved/
				local paths = {}
				local current = file
				while fs.getDir(current) do
					table.insert(paths, 1, fs.getDir(file))
					current = fs.getDir(current)
				end
				for _, p in pairs(paths) do
					if not fs.exists(p)	then
						fs.makeDir(templates[system.fs_template]..p)
					elseif not fs.isDir(p) then
						fs.move(p, fs.getName(p))
						fs.makeDir(templates[system.fs_template]..p)
					end
				end

				-- regen
				if dir then
					fs.makeDir(path)
				else
					fs.makeBlank(path)
				end
			end
		end
	end
	return unpack(missing)
end

--[[
 + displays welcome background w/o logo
 + requests user/pass to continue
 + can use arrow keys to cycle through users
 + @param _showusers blocks arrow key cycling
]]
local function login(_hideusers)
	local txt = {title = "SELECT A USER", user = "USER:", pass = "PASS:",
				 msg = "switch users with up and down", wrong = "Invalid user or pass."}
	local num = {boxsize = 17, userheight = 8, passheight = 12}
	local col = {back = colors.cyan, logo = colors.red, bands = colors.blue, border = colors.blue,
				 title = colors.black, tags = colors.blue, input = colors.white, msg = colors.gray, wrong = colors.red}
	local w, h = system.terminal.width, system.terminal.height

	-- basic design
	clear()
	shape.fill(col.back)
	for i = 3, 6 do
		--shape.circle(w / 2, h / 2, i, col.logo)
	end
	shape.circle(w / 2, h / 2, 11, col.bands)
	shape.circle(w / 2, h / 2, 12, col.bands)
	--shape.box(16, 3, 34, 15, col.back)
	shape.outline(1, 1, w, h, col.border)
	sleep(0.1) -- for read()

	-- text
	shape.textbox(txt.title, math.ceil((w - #txt.title) / 2), num.userheight - 2, col.back, col.title)
	shape.textbox(txt.user, math.floor((w - num.boxsize - #txt.user - 1) / 2), num.userheight, col.back, col.tags)
	shape.textbox(txt.pass, math.floor((w - num.boxsize - #txt.pass - 1) / 2), num.passheight, col.back, col.tags)
	if not _hideusers then
		shape.textbox(txt.msg, math.ceil((w - #txt.msg) / 2), num.userheight + 1, col.back, col.msg)
	end

	-- load users
	local userlist = {}
	local passlist = {}
	for _, user in pairs(fs.list(templates[system.fs_template].user)) do
		local datafile = templates[system.fs_template]["user_"..user.."_data"]
		if fs.exists(datafile) then
			table.insert(userlist, user)
			local udata = config.init(datafile, user)
			udata:load()
			passlist[user] = udata:getString("pass", "[null]")
			udata:save()
		end
	end
	table.sort(userlist)

	while true do
		-- draw boxes
		local ustart = math.ceil((w - num.boxsize + #txt.user + 1) / 2)
		local pstart = math.ceil((w - num.boxsize + #txt.pass + 1) / 2)
		shape.line(ustart, num.userheight, ustart + num.boxsize, num.userheight, col.input)
		shape.line(pstart, num.passheight, pstart + num.boxsize, num.passheight, col.input)

		-- handle input
		term.setTextColor(colors.black)
		term.setCursorPos(ustart, num.userheight)
		local uinput = read(nil, _hideusers and {} or userlist, num.boxsize + 1)
		if passlist[uinput] == "[null]" then
			break
		end
		term.setCursorPos(pstart, num.passheight)
		local pinput = read("*", {}, num.boxsize + 1)
		if passlist[uinput] == pinput then
			sleep(0.5)
			return
		else
			shape.textbox(txt.wrong, math.ceil((w - #txt.wrong) / 2), num.passheight + 2, col.back, col.wrong)
			shape.line(ustart, num.userheight, ustart + num.boxsize, num.userheight, colors.lightGray)
			shape.line(pstart, num.passheight, pstart + num.boxsize, num.passheight, colors.lightGray)
			sleep(0.2)
		end
	end
	clear()
end

--[[
 + displays the blue screen of death
 + draws the CraftOS shell below the error message
 + shell size adapts to error length
 + @param _error is displayed, defaults to custom message
]]
local function bsod(_error)
	local txt = {title = "ValorOS has crashed!", null = "Unfortunately, the exact error could not be determined.",
				 note = "Press any key to open the shell."}
	local w, h = term.getSize()

	term.setBackgroundColor(term.isColor() and colors.blue or colors.black)
	term.setTextColor(colors.white)
	term.clear()
	
	-- text
	term.setCursorPos(math.ceil((w - #txt.title) / 2), 2)
	write(txt.title)
	
	_error = tostring(_error)
	term.setCursorPos(2, 4)
	local len = 1
	if not _error then
		write(txt.null)
	else
		-- wrap error message
		local msg = tostring(_error)
		for i = 1, #msg do
			local c = msg:sub(i, i)
			local x, y = term.getCursorPos()
			local w, h = term.getSize()
			if x == 1 then
				write(" ")
				x = 2
			end
			if x < w then
				if not ((c == " ") and (x <= 2)) then
					write(c)
					if c == "\n" then
						write(" ")
					end
				end
				if (c == "\n") and (x < w) then
					len = len + 1
				end
			else
				term.setCursorPos(2, y + 1)
				len = len + 1
			end
		end
	end
	
	if term.isColor() then
		for row = len + 5, h do
			paintutils.drawLine(1, row, w, row, colors.black)
		end
		term.setCursorPos(1, len + 5)
		term.setTextColor(colors.yellow)
		print(os.version())
		term.setTextColor(colors.white)
		return
	else
		term.setCursorPos(1, len + 5)
		for i = 1, w do
			write("-")
		end
		term.setCursorPos(1, len + 6)
		print(os.version())
		return
	end
end

local ok, err = pcall(function()
	clear()
	welcome(true)
	checkfs()
	login()
	clear()
	bsod("This is an example error.")
end)

if not ok then
	local find1 = err:find(":", 1, true)
	local find2 = err:find(":", find1 + 1, true)
	local file = err:sub(10, find1 - 3)
	local line = err:sub(find1 + 1, find2 - 1)
	local msg = err:sub(find2 + 1)
	bsod(msg.."\nThe error occurred in "..(file or "an unknown file").." on line "..(line or "[?]")..".")
end
