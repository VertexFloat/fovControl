-- @author: 4c65736975, All Rights Reserved
-- @version: 1.0.0.0, 07/09/2022
-- @filename: FovControlGui.lua

FovControlGui = {}

local FovControlGui_mt = Class(FovControlGui)

function FovControlGui.new(settingsModel, hudAtlasPath)
	local self = setmetatable({}, FovControlGui_mt)

	self.fovControlDialog = FovControlDialog.new(nil, _, settingsModel)
	self.hudAtlasPath = hudAtlasPath

	return self
end

function FovControlGui:loadGuiProfiles(modDirectory)
	g_gui:loadProfiles(modDirectory .. 'src/resources/gui/guiProfiles.xml')

	for _, profile in pairs(g_gui.profiles) do
		for name, value in pairs(profile.values) do
			if (name == 'imageFilename' or name == 'iconFilename') and value == 'g_fovControlUIElements' then
				profile.values[name] = self.hudAtlasPath
			end
		end
	end
end

function FovControlGui:loadGui(modDirectory)
	g_gui:loadGui(Utils.getFilename('src/resources/gui/dialogs/FovControlDialog.xml', modDirectory), 'FovControlDialog', self.fovControlDialog)
end