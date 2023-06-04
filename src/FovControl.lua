-- @author: 4c65736975, All Rights Reserved
-- @version: 1.0.0.1, 05|05|2023
-- @filename: FovControl.lua

-- Changelog (1.0.0.1):
-- improved and cleaned code

FovControl = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_SETTINGS_DIRECTORY = g_modSettingsDirectory
}

source(FovControl.MOD_DIRECTORY .. 'src/gui/FovControlGui.lua')

local FovControl_mt = Class(FovControl)

---Creating FovControl instance
---@param gui table gui object
---@param l10n table l10n object
---@param settingsModel table settingsModel object
---@param messageCenter table messageCenter object
---@return table instance instance of object
function FovControl.new(customMt, gui, l10n, settingsModel, messageCenter)
	local self = setmetatable({}, customMt or FovControl_mt)

	self.gui = gui
	self.l10n = l10n
	self.settingsModel = settingsModel
	self.messageCenter = messageCenter
	self.modifiedVehicles = {}
	self.fovControlGui = FovControlGui.new(_, gui, l10n, settingsModel)

	self.messageCenter:subscribe(MessageType.VEHICLE_RESET, self.onVehicleReset, self)
	self.messageCenter:subscribe(BuyVehicleEvent, self.onVehicleBought, self)

	return self
end

---Initializing FovControl
function FovControl:initialize()
	self:loadVehicleCameraFovFromXMLFile()

	self.fovControlGui:initialize()
end

---Callback on map loading
---@param filename string map file path
function FovControl:loadMap(filename)
	self.fovControlGui:loadMap()
end

---Loading vehicles cameras fov from xml file
function FovControl:loadVehicleCameraFovFromXMLFile()
	local xmlFile = XMLFile.loadIfExists('FovControlXML', FovControl.MOD_SETTINGS_DIRECTORY .. 'fovControl.xml', 'vehicles')

	if xmlFile ~= nil then
		xmlFile:iterate('vehicles.vehicle', function (_, key)
			local xmlFilename = xmlFile:getString(key .. '#xmlFilename')

			if xmlFilename ~= nil and xmlFilename ~= '' then
				self.modifiedVehicles[xmlFilename] = {}

				xmlFile:iterate(key .. '.cameras.camera', function (_, cameraKey)
					local camera = {
						index = xmlFile:getInt(cameraKey .. '#index'),
						fov = xmlFile:getFloat(cameraKey .. '#fov'),
						defaultFov = xmlFile:getFloat(cameraKey .. '#defaultFov')
					}

					table.insert(self.modifiedVehicles[xmlFilename], camera)
				end)
			end
		end)

		xmlFile:delete()
	end
end

---Saving vehicles cameras fov to xml file
---@param vehicle string vehicle config xml file path
---@param cameraId integer vehicle camera index
---@param fov float vehicle camera fov
---@param defaultFov float vehicle default camera fov
function FovControl:saveVehicleCameraFovToXMLFile(vehicle, cameraId, fov, defaultFov)
	local camera = {
		index = cameraId,
		fov = fov,
		defaultFov = defaultFov
	}

	if self.modifiedVehicles[vehicle] ~= nil then
		local updated = false

		for _, modifiedCamera in pairs(self.modifiedVehicles[vehicle]) do
			if modifiedCamera.index == camera.index then
				modifiedCamera.fov = camera.fov

				updated = true

				break
			end
		end

		if not updated then
			table.insert(self.modifiedVehicles[vehicle], camera)
		end
	else
		self.modifiedVehicles[vehicle] = {}

		table.insert(self.modifiedVehicles[vehicle], camera)
	end

	local xmlFile = XMLFile.create('FovControlXML', FovControl.MOD_SETTINGS_DIRECTORY .. 'fovControl.xml', 'vehicles')

	if xmlFile ~= nil then
		local i = 0

		for vehicle, cameras in pairs(self.modifiedVehicles) do
			local key = string.format('vehicles.vehicle(%s)', i)

			xmlFile:setString(key .. '#xmlFilename', vehicle)
			xmlFile:setSortedTable(key .. '.cameras.camera', cameras, function (cameraKey, camera)
				xmlFile:setInt(cameraKey .. '#index', camera.index)
				xmlFile:setFloat(cameraKey .. '#fov', camera.fov)
				xmlFile:setFloat(cameraKey .. '#defaultFov', camera.defaultFov)
			end)

			i = i + 1
		end

		xmlFile:save()
		xmlFile:delete()
	end
end

---Loading vehicles cameras fov
function FovControl:loadVehiclesCamerasFov()
	for _, vehicle in pairs(g_currentMission.vehicles) do
		if SpecializationUtil.hasSpecialization(Enterable, vehicle.specializations) then
			local modifiedVehicle = self.modifiedVehicles[vehicle.configFileName]

			if modifiedVehicle ~= nil then
				local cameras = vehicle.spec_enterable.cameras

				if cameras ~= nil then
					for _, modifiedCamera in pairs(modifiedVehicle) do
						local camera = cameras[modifiedCamera.index]

						if camera ~= nil then
							if self.settingsModel.fovYToIndexMapping[modifiedCamera.fov] == nil then
								Logging.error(string.format('Saved "fov" for vehicle "%s", for camera "%d" is equals (%d). Must be in range (45-120) !', vehicle.configFileName, modifiedCamera.index, modifiedCamera.fov))

								return
							end

							setFovY(camera.cameraNode, math.rad(modifiedCamera.fov))
						end
					end
				end
			end
		end
	end
end

---ToggleFovControl action event callback
---@param actionName string action name
---@param inputValue integer input value
---@param callbackState any callback state
---@param isAnalog boolean is analog
function FovControl:actionEventToggleFovControl(actionName, inputValue, callbackState, isAnalog)
	g_gui:showDialog('FovControlDialog')
end

---Set vehicle active camera fov
---@param fov float vehicle camera fov
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

---Gets controlled vehicle active camera fov
---@return float fov vehicle active camera fov
function FovControl:getVehicleActiveCameraFov()
	local controlledVehicle = g_currentMission.controlledVehicle

	if controlledVehicle ~= nil and controlledVehicle.spec_enterable ~= nil then
		local activeCamera = controlledVehicle:getActiveCamera()

		if activeCamera ~= nil then
			return MathUtil.round(math.deg(getFovY(activeCamera.cameraNode)))
		end
	end

	return nil
end

---Gets controlled vehicle active camera index
---@return integer index vehicle active camera index
function FovControl:getVehicleActiveCameraIndex()
	local controlledVehicle = g_currentMission.controlledVehicle

	if controlledVehicle ~= nil and controlledVehicle.spec_enterable ~= nil then
		return controlledVehicle.spec_enterable.camIndex
	end

	return 1
end

---Gets controlled vehicle active camera default fov
---@return float fov default fov of vehicle active camera or nil when not found
function FovControl:getVehicleActiveCameraDefaultFov()
	local controlledVehicle = g_currentMission.controlledVehicle

	if controlledVehicle ~= nil then
		if controlledVehicle.spec_enterable ~= nil then
			local vehicle = self.modifiedVehicles[controlledVehicle.configFileName]

			if vehicle ~= nil then
				local camIndex = controlledVehicle.spec_enterable.camIndex

				for _, camera in pairs(vehicle) do
					if camera.index == camIndex then
						if camera.defaultFov ~= nil then
							if self.settingsModel.fovYToIndexMapping[camera.defaultFov] == nil then
								Logging.error(string.format('Saved default "fov" for vehicle "%s", for camera "%d" is equals (%d). Must be in range (45-120) !', controlledVehicle.configFileName, camera.index, camera.defaultFov))

								return nil
							end

							return camera.defaultFov
						end
					end
				end
			end
		end
	end

	return nil
end

---Callback on vehicle reset event
---@param vehicle table old vehicle object
---@param newVehicle table new vehicle object
function FovControl:onVehicleReset(vehicle, newVehicle)
	self:loadVehiclesCamerasFov()
end

---Callback on vehicle buy event
---@param errorCode integer error code
---@param leaseVehicle boolean whether or not is leased vehicle
---@param price float vehicle price
function FovControl:onVehicleBought(errorCode, leaseVehicle, price)
	self:loadVehiclesCamerasFov()
end

---Callback on map deleting
function FovControl:deleteMap()
	self.messageCenter:unsubscribeAll(self)
end

g_fovControl = FovControl.new(_, g_gui, g_i18n, SettingsModel.new(g_gameSettings, g_savegameXML, g_i18n, g_soundMixer, GS_IS_CONSOLE_VERSION), g_messageCenter)

addModEventListener(g_fovControl)

local function validateTypes(self)
	if self.typeName == 'vehicle' then
		g_fovControl:initialize()
	end
end

TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, validateTypes)

local function loadVehiclesFromSavegameFinished()
	g_fovControl:loadVehiclesCamerasFov()
end

VehicleLoadingUtil.loadVehiclesFromSavegameFinished = Utils.appendedFunction(VehicleLoadingUtil.loadVehiclesFromSavegameFinished, loadVehiclesFromSavegameFinished)

local function onRegisterActionEvents(self, isActiveForInput, isActiveForInputIgnoreSelection)
	if self:getIsEntered() then
		local spec = self.spec_enterable

		if isActiveForInputIgnoreSelection then
			local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_FOV_CONTROL, self, FovControl.actionEventToggleFovControl, false, true, false, true, nil)

			g_inputBinding:setActionEventText(actionEventId, g_i18n:getText('action_openFovControl'))
			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
		end
	end
end

Enterable.onRegisterActionEvents = Utils.appendedFunction(Enterable.onRegisterActionEvents, onRegisterActionEvents)

local function onVehicleChanged()
	g_fovControl:loadVehiclesCamerasFov()
end

WorkshopScreen.onVehicleChanged = Utils.appendedFunction(WorkshopScreen.onVehicleChanged, onVehicleChanged)