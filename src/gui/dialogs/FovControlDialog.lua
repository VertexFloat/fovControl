-- @author: 4c65736975, All Rights Reserved
-- @version: 1.0.0.1, 05|05|2023
-- @filename: FovControlDialog.lua

-- Changelog (1.0.0.1):
-- improved and cleaned code

FovControlDialog = {
	CONTROLS = {
		'fovElement',
		'bgElement',
		'btnRemoveBgElement'
	}
}

local FovControlDialog_mt = Class(FovControlDialog, MessageDialog)

---Creating FovControlDialog instance
---@param l10n table l10n object
---@param settingsModel table settingsModel object
---@return table instance instance of object
function FovControlDialog.new(target, customMt, l10n, settingsModel)
	local self = MessageDialog.new(target, customMt or FovControlDialog_mt)

	self.l10n = l10n
	self.settingsModel = settingsModel
	self.selectedFovValue = nil
	self.lastValidFovValue = nil

	self:registerControls(FovControlDialog.CONTROLS)

	return self
end

---Callback on dialog open
function FovControlDialog:onOpen()
	FovControlDialog:superClass().onOpen(self)

	self:updateValues()
end

---Updating dialog values
function FovControlDialog:updateValues()
	self.fovElement:setTexts(self.settingsModel:getFovYTexts())

	self.selectedFovValue = nil
	self.lastValidFovValue = g_fovControl:getVehicleActiveCameraFov()

	self:setState(self.lastValidFovValue)
end

---Set fov multi text option element state
---@param state float camera fov
function FovControlDialog:setState(state)
	if state ~= nil then
		if self.settingsModel.fovYToIndexMapping[state] ~= nil then
			self.fovElement:setState(self.settingsModel.fovYToIndexMapping[state])

			self.selectedFovValue = state
		end
	end
end

---Callback on click fov value
---@param state integer fov multi text option element state
function FovControlDialog:onClickFovValue(state)
	self.selectedFovValue = self.settingsModel.indexToFovYMapping[state]

	g_fovControl:setActiveCameraFov(self.selectedFovValue)
end

---Callback on click apply
function FovControlDialog:onClickApply()
	self:saveFovState()
	self:close()
end

---Callback on click remove background
function FovControlDialog:onClickRemoveBackground()
	self.bgElement:setVisible(not self.bgElement.visible)

	self.btnRemoveBgElement.text = not self.bgElement.visible and self.l10n:getText('button_add_background'):upper() or self.l10n:getText('button_remove_background'):upper()
end

---Callback on click reset fov
function FovControlDialog:onClickResetFov()
	local defaultFovValue = g_fovControl:getVehicleActiveCameraDefaultFov()

	if defaultFovValue == nil then
		defaultFovValue = self.lastValidFovValue
	end

	self:setState(defaultFovValue)

	g_fovControl:setActiveCameraFov(defaultFovValue)
end

---Callback on click back
function FovControlDialog:onClickBack()
	g_fovControl:setActiveCameraFov(self.lastValidFovValue)

	self:close()
end

---Saving current vehicle camera fov
function FovControlDialog:saveFovState()
	local controlledVehicle = g_currentMission.controlledVehicle

	if controlledVehicle ~= nil then
		local filename = controlledVehicle.configFileName
		local cameraId = g_fovControl:getVehicleActiveCameraIndex()
		local defaultFov = self.lastValidFovValue
		local fov = self.selectedFovValue

		if fov == nil then
			fov = self.lastValidFovValue
		end

		if filename ~= nil and fov ~= nil then
			g_fovControl:saveVehicleCameraFovToXMLFile(filename, cameraId, fov, defaultFov)
		end
	end
end