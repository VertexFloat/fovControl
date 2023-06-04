-- @author: 4c65736975, All Rights Reserved
-- @version: 1.0.0.1, 05|05|2023
-- @filename: FovControlGui.lua

-- Changelog (1.0.0.1):
-- improved and cleaned code

FovControlGui = {
	MOD_DIRECTORY = g_currentModDirectory,
	HUD_ATLAS_PATH = g_currentModDirectory .. 'data/menu/hud/ui_elements.png'
}

source(FovControlGui.MOD_DIRECTORY .. 'src/gui/dialogs/FovControlDialog.lua')

local FovControlGui_mt = Class(FovControlGui)

---Creating FovControlGui instance
---@param gui table gui object
---@param l10n table l10n object
---@param settingsModel table settingsModel object
---@return table instance instance of object
function FovControlGui.new(customMt, gui, l10n, settingsModel)
	local self = setmetatable({}, customMt or FovControlGui_mt)

	self.gui = gui
	self.l10n = l10n
	self.fovControlDialog = FovControlDialog.new(nil, customMt, l10n, settingsModel)

	return self
end

---Initializing FovControlGui
function FovControlGui:initialize()
	self.gui:loadProfiles(FovControlGui.MOD_DIRECTORY .. 'data/gui/guiProfiles.xml')

	for _, profile in pairs(self.gui.profiles) do
		for name, value in pairs(profile.values) do
			if (name == 'imageFilename' or name == 'iconFilename') and value == 'g_fovControlUIElements' then
				profile.values[name] = FovControlGui.HUD_ATLAS_PATH
			end
		end
	end
end

---Callback on map loading
---@param filename string map file path
function FovControlGui:loadMap(filename)
	self.gui:loadGui(Utils.getFilename('data/gui/dialogs/FovControlDialog.xml', FovControlGui.MOD_DIRECTORY), 'FovControlDialog', self.fovControlDialog)
end