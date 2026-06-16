HotkeyColors = {
	textAutoSend = "#FFFFFF",
	text = "#888888"
}
hotkeysManagerLoaded = false
hotkeysWindow = nil
configSelector = nil
hotkeysButton = nil
currentHotkeyLabel = nil
addHotkeyButton = nil
removeHotkeyButton = nil
hotkeyText = nil
hotKeyTextLabel = nil
sendAutomatically = nil
currentHotkeys = nil
boundCombosCallback = {}
hotkeysList = {}
hotkeyConfigs = {}
currentConfig = 1
configValueChanged = false

function init()
	if not g_app.isMobile() then
		hotkeysButton = modules.client_topmenu.addLeftGameButton("hotkeysButton", tr("Hotkeys") .. " (Ctrl+K)", "/images/topbuttons/hotkeys", toggle, false, 7)
	end

	g_keyboard.bindKeyDown("Ctrl+K", toggle)

	hotkeysWindow = g_ui.displayUI("hotkeys_manager")

	hotkeysWindow:setVisible(false)

	configSelector = hotkeysWindow:getChildById("configSelector")
	currentHotkeys = hotkeysWindow:getChildById("currentHotkeys")
	addHotkeyButton = hotkeysWindow:getChildById("addHotkeyButton")
	removeHotkeyButton = hotkeysWindow:getChildById("removeHotkeyButton")
	hotkeyText = hotkeysWindow:getChildById("hotkeyText")
	hotKeyTextLabel = hotkeysWindow:getChildById("hotKeyTextLabel")
	sendAutomatically = hotkeysWindow:getChildById("sendAutomatically")

	function currentHotkeys:onChildFocusChange(hotkeyLabel)
		onSelectHotkeyLabel(hotkeyLabel)
	end

	g_keyboard.bindKeyPress("Down", function ()
		currentHotkeys:focusNextChild(KeyboardFocusReason)
	end, hotkeysWindow)
	g_keyboard.bindKeyPress("Up", function ()
		currentHotkeys:focusPreviousChild(KeyboardFocusReason)
	end, hotkeysWindow)

	connect(g_game, {
		onGameStart = online,
		onGameEnd = offline
	})

	for i = 1, configSelector:getOptionsCount() do
		hotkeyConfigs[i] = g_configs.create("/hotkeys_" .. i .. ".otml")
	end

	load()
end

function terminate()
	disconnect(g_game, {
		onGameStart = online,
		onGameEnd = offline
	})
	g_keyboard.unbindKeyDown("Ctrl+K")
	unload()
	hotkeysWindow:destroy()

	if hotkeysButton then
		hotkeysButton:destroy()
	end
end

function online()
	reload()
	hide()
end

function offline()
	unload()
	hide()
end

function show()
	if not g_game.isOnline() then
		return
	end

	hotkeysWindow:show()
	hotkeysWindow:raise()
	hotkeysWindow:focus()
end

function hide()
	hotkeysWindow:hide()
end

function toggle()
	if not hotkeysWindow:isVisible() then
		show()
	else
		hide()
	end
end

function ok()
	save()
	hide()
end

function cancel()
	reload()
	hide()
end

function load(forceDefaults)
	hotkeysManagerLoaded = false
	currentConfig = 1
	local hotkeysNode = g_settings.getNode("hotkeys") or {}
	local index = g_game.getCharacterName() .. "_" .. g_game.getClientVersion()

	if hotkeysNode[index] ~= nil and hotkeysNode[index] > 0 and hotkeysNode[index] <= #hotkeyConfigs then
		currentConfig = hotkeysNode[index]
	end

	configSelector:setCurrentIndex(currentConfig, true)

	local hotkeySettings = hotkeyConfigs[currentConfig]:getNode("hotkeys")
	local hotkeys = {}

	if not table.empty(hotkeySettings) then
		hotkeys = hotkeySettings
	end

	hotkeyList = {}

	if not forceDefaults and not table.empty(hotkeys) then
		for keyCombo, setting in pairs(hotkeys) do
			keyCombo = tostring(keyCombo)

			addKeyCombo(keyCombo, setting)

			hotkeyList[keyCombo] = setting
		end
	end

	if currentHotkeys:getChildCount() == 0 then
		loadDefautComboKeys()
	end

	configValueChanged = false
	hotkeysManagerLoaded = true
end

function unload()
	local gameRootPanel = modules.game_interface.getRootPanel()

	for keyCombo, callback in pairs(boundCombosCallback) do
		g_keyboard.unbindKeyPress(keyCombo, callback, gameRootPanel)
	end

	boundCombosCallback = {}

	currentHotkeys:destroyChildren()

	currentHotkeyLabel = nil

	updateHotkeyForm(true)

	hotkeyList = {}
end

function reset()
	unload()
	load(true)
end

function reload()
	unload()
	load()
end

function save()
	if not configValueChanged then
		return
	end

	local hotkeySettings = hotkeyConfigs[currentConfig]:getNode("hotkeys") or {}

	table.clear(hotkeySettings)

	for _, child in pairs(currentHotkeys:getChildren()) do
		hotkeySettings[child.keyCombo] = {
			autoSend = child.autoSend,
			value = child.value
		}
	end

	hotkeyList = hotkeySettings

	hotkeyConfigs[currentConfig]:setNode("hotkeys", hotkeySettings)
	hotkeyConfigs[currentConfig]:save()

	local index = g_game.getCharacterName() .. "_" .. g_game.getClientVersion()
	local hotkeysNode = g_settings.getNode("hotkeys") or {}
	hotkeysNode[index] = currentConfig

	g_settings.setNode("hotkeys", hotkeysNode)
	g_settings.save()
end

function onConfigChange()
	if not configSelector then
		return
	end

	local index = g_game.getCharacterName() .. "_" .. g_game.getClientVersion()
	local hotkeysNode = g_settings.getNode("hotkeys") or {}
	hotkeysNode[index] = configSelector.currentIndex

	g_settings.setNode("hotkeys", hotkeysNode)
	reload()
end

function loadDefautComboKeys()
	for i = 1, 12 do
		addKeyCombo("F" .. i)
	end

	for i = 1, 12 do
		addKeyCombo("Shift+F" .. i)
	end
end

function addHotkey()
	local assignWindow = g_ui.createWidget("HotkeyAssignWindow", rootWidget)

	assignWindow:grabKeyboard()

	local comboLabel = assignWindow:getChildById("comboPreview")
	comboLabel.keyCombo = ""
	assignWindow.onKeyDown = hotkeyCapture
end

function addKeyCombo(keyCombo, keySettings, focus)
	if keyCombo == nil or #keyCombo == 0 then
		return
	end

	if not keyCombo then
		return
	end

	local hotkeyLabel = currentHotkeys:getChildById(keyCombo)

	if not hotkeyLabel then
		hotkeyLabel = g_ui.createWidget("HotkeyListLabel")

		hotkeyLabel:setId(keyCombo)

		local children = currentHotkeys:getChildren()
		children[#children + 1] = hotkeyLabel

		table.sort(children, function (a, b)
			if a:getId():len() < b:getId():len() then
				return true
			elseif a:getId():len() == b:getId():len() then
				return a:getId() < b:getId()
			else
				return false
			end
		end)

		for i = 1, #children do
			if children[i] == hotkeyLabel then
				currentHotkeys:insertChild(i, hotkeyLabel)

				break
			end
		end

		if keySettings then
			currentHotkeyLabel = hotkeyLabel
			hotkeyLabel.keyCombo = keyCombo
			hotkeyLabel.autoSend = toboolean(keySettings.autoSend)

			if keySettings.value then
				hotkeyLabel.value = tostring(keySettings.value)
			end
		else
			hotkeyLabel.keyCombo = keyCombo
			hotkeyLabel.autoSend = false
			hotkeyLabel.value = ""
		end

		updateHotkeyLabel(hotkeyLabel)

		local gameRootPanel = modules.game_interface.getRootPanel()

		if keyCombo:lower():find("ctrl") and boundCombosCallback[keyCombo] then
			g_keyboard.unbindKeyPress(keyCombo, boundCombosCallback[keyCombo], gameRootPanel)
		end

		boundCombosCallback[keyCombo] = function (k, c, ticks)
			prepareKeyCombo(keyCombo, ticks)
		end

		g_keyboard.bindKeyPress(keyCombo, boundCombosCallback[keyCombo], gameRootPanel)

		if not keyCombo:lower():find("ctrl") then
			local keyComboCtrl = "Ctrl+" .. keyCombo

			if not boundCombosCallback[keyComboCtrl] then
				boundCombosCallback[keyComboCtrl] = function (k, c, ticks)
					prepareKeyCombo(keyComboCtrl, ticks)
				end

				g_keyboard.bindKeyPress(keyComboCtrl, boundCombosCallback[keyComboCtrl], gameRootPanel)
			end
		end
	end

	if focus then
		currentHotkeys:focusChild(hotkeyLabel)
		currentHotkeys:ensureChildVisible(hotkeyLabel)
		updateHotkeyForm(true)
	end

	configValueChanged = true
end

function prepareKeyCombo(keyCombo, ticks)
	local hotKey = hotkeyList[keyCombo]

	if not hotKey then
		return
	end

	local now = g_clock.millis()
	if hotKey.lastUsed and now - hotKey.lastUsed < 1000 then
		return
	end
	hotKey.lastUsed = now

	scheduleEvent(function ()
		doKeyCombo(keyCombo, ticks >= 5)
	end, g_settings.getNumber("hotkeyDelay"))
end

function doKeyCombo(keyCombo, repeated)
	if not g_game.isOnline() then
		return
	end

	if modules.game_console and modules.game_console.isChatEnabled() and keyCombo:len() == 1 then
		return
	end

	local hotKey = hotkeyList[keyCombo]

	if not hotKey then
		return
	end

	if not hotKey.value or #hotKey.value == 0 then
		return
	end

	if hotKey.autoSend then
		modules.game_console.sendMessage(hotKey.value)
	else
		modules.game_console.setTextEditText(hotKey.value)
	end
end

function updateHotkeyLabel(hotkeyLabel)
	if not hotkeyLabel then
		return
	end

	local text = hotkeyLabel.keyCombo .. ": "

	if hotkeyLabel.value then
		text = text .. hotkeyLabel.value
	end

	hotkeyLabel:setText(text)

	if hotkeyLabel.autoSend then
		hotkeyLabel:setColor(HotkeyColors.autoSend)
	else
		hotkeyLabel:setColor(HotkeyColors.text)
	end
end

function updateHotkeyForm(reset)
	configValueChanged = true

	if currentHotkeyLabel then
		removeHotkeyButton:enable()
		hotkeyText:enable()
		hotkeyText:focus()
		hotKeyTextLabel:enable()

		if reset then
			hotkeyText:setCursorPos(-1)
		end

		hotkeyText:setText(currentHotkeyLabel.value)
		sendAutomatically:setChecked(currentHotkeyLabel.autoSend)
		sendAutomatically:setEnabled(currentHotkeyLabel.value and #currentHotkeyLabel.value > 0)
	else
		removeHotkeyButton:disable()
		hotkeyText:disable()
		sendAutomatically:disable()
		hotkeyText:clearText()
		sendAutomatically:setChecked(false)
	end
end

function removeHotkey()
	if currentHotkeyLabel == nil then
		return
	end

	local gameRootPanel = modules.game_interface.getRootPanel()
	configValueChanged = true

	g_keyboard.unbindKeyPress(currentHotkeyLabel.keyCombo, boundCombosCallback[currentHotkeyLabel.keyCombo], gameRootPanel)

	boundCombosCallback[currentHotkeyLabel.keyCombo] = nil

	currentHotkeyLabel:destroy()

	currentHotkeyLabel = nil
end

function onHotkeyTextChange(value)
	if not hotkeysManagerLoaded then
		return
	end

	if currentHotkeyLabel == nil then
		return
	end

	currentHotkeyLabel.value = value
	configValueChanged = true

	updateHotkeyLabel(currentHotkeyLabel)
	updateHotkeyForm()
end

function onSendAutomaticallyChange(autoSend)
	if not hotkeysManagerLoaded then
		return
	end

	if currentHotkeyLabel == nil then
		return
	end

	if not currentHotkeyLabel.value or #currentHotkeyLabel.value == 0 then
		return
	end

	configValueChanged = true
	currentHotkeyLabel.autoSend = autoSend

	updateHotkeyLabel(currentHotkeyLabel)
	updateHotkeyForm()
end

function onSelectHotkeyLabel(hotkeyLabel)
	currentHotkeyLabel = hotkeyLabel

	if currentHotkeys and hotkeyLabel then
		currentHotkeys:ensureChildVisible(hotkeyLabel)
	end

	updateHotkeyForm(true)
end

function hotkeyCapture(assignWindow, keyCode, keyboardModifiers)
	local keyCombo = determineKeyComboDesc(keyCode, keyboardModifiers)
	local comboPreview = assignWindow:getChildById("comboPreview")

	comboPreview:setText(tr("Current hotkey to add: %s", keyCombo))

	comboPreview.keyCombo = keyCombo

	comboPreview:resizeToText()
	assignWindow:getChildById("addButton"):enable()

	return true
end

function hotkeyCaptureOk(assignWindow, keyCombo)
	addKeyCombo(keyCombo, nil, true)
	assignWindow:destroy()
end
