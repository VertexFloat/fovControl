-- @author: 4c65736975, All Rights Reserved
-- @version: 1.0.0.0, 07/09/2022
-- @filename: FovControl.lua

FovControl = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_SETTINGS_DIRECTORY = g_modSettingsDirectory,
	HUD_ATLAS_PATH = g_currentModDirectory .. 'src/resources/menu/hud/ui_elements.png'
}

source(FovControl.MOD_DIRECTORY .. 'src/gui/dialogs/FovControlDialog.lua')
source(FovControl.MOD_DIRECTORY .. 'src/gui/FovControlGui.lua')

local FovControl_mt = Class(FovControl)

function FovControl.new(customMt, settingsModel, messageCenter)
	local self = setmetatable({}, customMt or FovControl_mt)

	self.modifiedVehicles = {}
	self.settingsModel = settingsModel
	self.messageCenter = messageCenter

	self.fovControlGui = FovControlGui.new(self.settingsModel, FovControl.HUD_ATLAS_PATH)

	self.messageCenter:subscribe(MessageType.VEHICLE_RESET, self.onVehicleReset, self)
	self.messageCenter:subscribe(BuyVehicleEvent, self.onVehicleBought, self)

	return self
end

function FovControl:initialize()
	self.fovControlGui:loadGuiProfiles(FovControl.MOD_DIRECTORY)
	self.fovControlGui:loadGui(FovControl.MOD_DIRECTORY)

	self:loadVehicleCameraFovFromXMLFile()
end

function FovControl:loadVehicleCameraFovFromXMLFile()
	local xmlFile = XMLFile.loadIfExists('FovControlXML', FovControl.MOD_SETTINGS_DIRECTORY .. 'fovControl.xml', 'vehicles')

	if xmlFile ~= nil then
		xmlFile:iterate('vehicles.vehicle', function (_, key)
			local vehicle = {
				xmlFilename = xmlFile:getString(key .. '#xmlFilename')
			}

			vehicle.cameras = {}

			xmlFile:iterate(key .. '.cameras.camera', function (_, cameraKey)
				local camera = {
					index = xmlFile:getInt(cameraKey .. '#index'),
					fov = xmlFile:getFloat(cameraKey .. '#fov'),
					defaultFov = xmlFile:getFloat(cameraKey .. '#defaultFov')
				}

				table.insert(vehicle.cameras, camera)
			end)

			table.insert(self.modifiedVehicles, vehicle)
		end)

		xmlFile:delete()
	end
end

function FovControl:loadVehiclesCamerasFov(updateVehicle)
	for _, vehicle in pairs(g_currentMission.vehicles) do
		for _, modifiedVehicle in pairs(self.modifiedVehicles) do
			if SpecializationUtil.hasSpecialization(Enterable, vehicle.specializations) then
				local modifyVehicle = modifiedVehicle.xmlFilename

				if updateVehicle ~= nil then
					modifyVehicle = nil

					if modifiedVehicle.xmlFilename == updateVehicle then
						modifyVehicle = updateVehicle
					end
				end

				if modifyVehicle == vehicle.configFileName then
					local cameras = vehicle.spec_enterable.cameras

					if cameras ~= nil then
						for _, modifiedCamera in pairs(modifiedVehicle.cameras) do
							local camera = cameras[modifiedCamera.index]

							if self.settingsModel.fovYToIndexMapping[modifiedCamera.fov] == nil then
								Logging.error(string.format("Saved 'fov' for vehicle '%s', for camera '%d' is equals (%d). Must be in range (45-120) !", vehicle.configFileName, modifiedCamera.index, modifiedCamera.fov))
							end

							setFovY(camera.cameraNode, math.rad(modifiedCamera.fov))
						end
					end
				end
			end
		end
	end
end

function FovControl:saveVehicleCameraFovToXMLFile(vehicle, camera, fov, defaultFov)
	local xmlFile = XMLFile.create('FovControlXML', FovControl.MOD_SETTINGS_DIRECTORY .. 'fovControl.xml', 'vehicles')
	local modifiedVehicle = {
		xmlFilename = vehicle,
		cameras = {
			{
				index = camera,
				fov = fov,
				defaultFov = defaultFov
			}
		}
	}

	if rawequal(next(self.modifiedVehicles), nil) then
		table.insert(self.modifiedVehicles, modifiedVehicle)
	else
		local vehicleToUpdate = nil
		local cameraToUpdate = nil

		for _, savedVehicle in pairs(self.modifiedVehicles) do
			if savedVehicle.xmlFilename == modifiedVehicle.xmlFilename then
				vehicleToUpdate = savedVehicle.xmlFilename

				for _, savedCamera in pairs(savedVehicle.cameras) do
					if savedCamera.index == modifiedVehicle.cameras[1].index then
						cameraToUpdate = savedCamera.index
					end
				end
			end
		end

		if vehicleToUpdate == nil then
			table.insert(self.modifiedVehicles, modifiedVehicle)
		else
			for _, savedVehicle in pairs(self.modifiedVehicles) do
				if savedVehicle.xmlFilename == vehicleToUpdate then
					if cameraToUpdate == nil then
						table.insert(savedVehicle.cameras, modifiedVehicle.cameras[1])
					else
						for _, savedCamera in pairs(savedVehicle.cameras) do
							if savedCamera.index == cameraToUpdate then
								savedCamera.fov = modifiedVehicle.cameras[1].fov
							end
						end
					end
				end
			end
		end
	end

	if xmlFile ~= nil then
		xmlFile:setSortedTable('vehicles.vehicle', self.modifiedVehicles, function (key, modifiedVehicle, _)
			xmlFile:setString(key .. '#xmlFilename', modifiedVehicle.xmlFilename)
			xmlFile:setSortedTable(key .. '.cameras.camera', modifiedVehicle.cameras, function (cameraKey, modifiedCamera, _)
				xmlFile:setInt(cameraKey .. '#index', modifiedCamera.index)
				xmlFile:setFloat(cameraKey .. '#fov', modifiedCamera.fov)
				xmlFile:setFloat(cameraKey .. '#defaultFov', modifiedCamera.defaultFov)
			end)
		end)

		xmlFile:save()
		xmlFile:delete()
	end
end

function FovControl:registerActionEvents(self, isActiveForInput, isActiveForInputIgnoreSelection)
	if self:getIsEntered() then
		local spec = self.spec_enterable

		if isActiveForInputIgnoreSelection then
			local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_FOV_CONTROL, self, FovControl.actionEventToggleFovControl, false, true, false, true, nil)

			g_inputBinding:setActionEventText(actionEventId, g_i18n:getText('action_openFovControl'))
			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
		end
	end
end

function FovControl:actionEventToggleFovControl(actionName, inputValue, callbackState, isAnalog)
	g_gui:showDialog('FovControlDialog')
end

function FovControl:setActiveCameraFov(fov)
	local controlledVehicle = g_currentMission.controlledVehicle

	if controlledVehicle ~= nil then
		if controlledVehicle.spec_enterable ~= nil then
			local activeCamera = controlledVehicle:getActiveCamera()

			if fov ~= nil and activeCamera ~= nil then
				setFovY(activeCamera.cameraNode, math.rad(fov))
			end
		end
	end
end

function FovControl:onVehicleReset(vehicle, newVehicle)
	self:loadVehiclesCamerasFov(vehicle.configFileName)
end

function FovControl:onVehicleBought(errorCode, leaseVehicle, price)
	self:loadVehiclesCamerasFov()
end

function FovControl:getControlledVehicleActiveCameraDefaultFov()
	local controlledVehicle = g_currentMission.controlledVehicle

	if controlledVehicle ~= nil then
		if controlledVehicle.spec_enterable ~= nil then
			local camera = controlledVehicle.spec_enterable.cameras[controlledVehicle.spec_enterable.camIndex]

			if controlledVehicle:getActiveCamera() == camera then
				for _, vehicle in pairs(self.modifiedVehicles) do
					if vehicle.xmlFilename == controlledVehicle.configFileName then
						for _, camera in pairs(vehicle.cameras) do
							if camera.index == controlledVehicle.spec_enterable.camIndex then
								local defaultFov = camera.defaultFov

								if defaultFov ~= nil then
									if self.settingsModel.fovYToIndexMapping[defaultFov] == nil then
										Logging.error(string.format("Saved default 'fov' for vehicle '%s', for camera '%d' is equals (%d). Must be in range (45-120) !", vehicle.xmlFilename, camera.index, defaultFov))

										return nil
									end

									return defaultFov
								end
							end
						end
					end
				end
			end
		end
	end

	return nil
end

function FovControl:deleteMap()
	self.messageCenter:unsubscribeAll(self)
end

g_fovControl = FovControl.new(_, SettingsModel.new(g_gameSettings, g_savegameXML, g_i18n, g_soundMixer, GS_IS_CONSOLE_VERSION), g_messageCenter)

addModEventListener(g_fovControl)

local function validateTypes(self)
	if self.typeName == 'vehicle' and g_fovControl ~= nil then
		g_fovControl:initialize()
	end
end

TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, validateTypes)

local function loadVehiclesFromSavegameFinished()
	if g_fovControl ~= nil then
		g_fovControl:loadVehiclesCamerasFov()
	end
end

VehicleLoadingUtil.loadVehiclesFromSavegameFinished = Utils.appendedFunction(VehicleLoadingUtil.loadVehiclesFromSavegameFinished, loadVehiclesFromSavegameFinished)

local function onRegisterActionEvents(self, isActiveForInput, isActiveForInputIgnoreSelection)
	if g_fovControl ~= nil then
		g_fovControl:registerActionEvents(self, isActiveForInput, isActiveForInputIgnoreSelection)
	end
end

Enterable.onRegisterActionEvents = Utils.appendedFunction(Enterable.onRegisterActionEvents, onRegisterActionEvents)

local function onVehicleChanged()
	if g_fovControl ~= nil then
		g_fovControl:loadVehiclesCamerasFov()
	end
end

WorkshopScreen.onVehicleChanged = Utils.appendedFunction(WorkshopScreen.onVehicleChanged, onVehicleChanged)