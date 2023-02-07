-- @author: 4c65736975, All Rights Reserved
-- @version: 1.0.0.0, 07/09/2022
-- @filename: FovControlDialog.lua

FovControlDialog = {}

local FovControlDialog_mt = Class(FovControlDialog, MessageDialog)

FovControlDialog.CONTROLS = {
	FOV_VALUE = 'fovElement',
	BASE_BACKGROUND = 'bgElement',
	BUTTON_REMOVE_BACKGROUND = 'btnRemoveBgElement'
}

function FovControlDialog.new(target, customMt, settingsModel)
	local self = MessageDialog.new(target, customMt or FovControlDialog_mt)

	self.settingsModel = settingsModel

	self.selectedFovValue = nil
	self.lastSelectedFovValue = nil

	self:registerControls(FovControlDialog.CONTROLS)

	return self
end

function FovControlDialog:onOpen()
	FovControlDialog:superClass().onOpen(self)

	self:updateValues()
end

function FovControlDialog:updateValues()
	self.fovElement:setTexts(self.settingsModel:getFovYTexts())

	self.selectedFovValue = nil
	self.lastSelectedFovValue = self:getControlledVehicleActiveCameraFov()

	self:setState(self.lastSelectedFovValue)
end

function FovControlDialog:setState(state)
	if state ~= nil then
		if self.settingsModel.fovYToIndexMapping[state] ~= nil then
			self.fovElement:setState(self.settingsModel.fovYToIndexMapping[state])

			self.selectedFovValue = state
		end
	end
end

function FovControlDialog:onClickFovValue(state)
	self.selectedFovValue = self.settingsModel.indexToFovYMapping[state]

	g_fovControl:setActiveCameraFov(self.selectedFovValue)
end

function FovControlDialog:onClickApply()
	self:saveFovState()
	self:close()
end

function FovControlDialog:onClickRemoveBackground()
	self.bgElement:setVisible(not self.bgElement.visible)

	self.btnRemoveBgElement.text = not self.bgElement.visible and g_i18n:getText('button_add_background'):upper() or g_i18n:getText('button_remove_background'):upper()
end

function FovControlDialog:onClickResetFov()
	local defaultFovValue = g_fovControl:getControlledVehicleActiveCameraDefaultFov()

	if defaultFovValue == nil then
		defaultFovValue = self.lastSelectedFovValue
	end

	self:setState(defaultFovValue)

	g_fovControl:setActiveCameraFov(defaultFovValue)
end

function FovControlDialog:onClickBack(sender)
	g_fovControl:setActiveCameraFov(self.lastSelectedFovValue)

	self:close()
end

function FovControlDialog:saveFovState()
	local controlledVehicle = g_currentMission.controlledVehicle

	if controlledVehicle ~= nil then
		local filename = controlledVehicle.configFileName
		local cameraId = self:getControlledVehicleActiveCameraIndex(controlledVehicle)
		local defaultFov = self.lastSelectedFovValue
		local fov = self.selectedFovValue

		if fov == nil then
			fov = self.lastSelectedFovValue
		end

		if filename ~= nil and fov ~= nil then
			g_fovControl:saveVehicleCameraFovToXMLFile(filename, cameraId, fov, defaultFov)
		end
	end
end

function FovControlDialog:getControlledVehicleActiveCameraFov()
	local controlledVehicle = g_currentMission.controlledVehicle

	if controlledVehicle ~= nil then
		if controlledVehicle.spec_enterable ~= nil then
			local activeCamera = controlledVehicle:getActiveCamera()

			if activeCamera ~= nil then
				return MathUtil.round(math.deg(getFovY(activeCamera.cameraNode)))
			end
		end
	end

	return nil
end

function FovControlDialog:getControlledVehicleActiveCameraIndex(controlledVehicle)
	if controlledVehicle.spec_enterable ~= nil then
		local camera = controlledVehicle.spec_enterable.cameras[controlledVehicle.spec_enterable.camIndex]

		if controlledVehicle:getActiveCamera() == camera then
			return controlledVehicle.spec_enterable.camIndex
		end
	end

	return 1
end