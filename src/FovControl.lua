-- @author: 4c65736975, All Rights Reserved
-- @version: 1.0.0.3, 25|01|2024
-- @filename: FovControl.lua

-- Changelog (1.0.0.1):
-- improved and cleaned code

-- Changelog (1.0.0.2):
-- removed unnecessary code

-- Changelog (1.0.0.3):
-- fixed a problem with data compatibility with previous settings

FovControl = {
  MOD_DIRECTORY = g_currentModDirectory,
  MOD_SETTINGS_DIRECTORY = g_modSettingsDirectory
}

source(FovControl.MOD_DIRECTORY .. "src/gui/FovControlGui.lua")

local FovControl_mt = Class(FovControl)

function FovControl.new(customMt, gui, l10n, settingsModel)
  local self = setmetatable({}, customMt or FovControl_mt)

  self.modifiedVehicles = {}
  self.fovControlGui = FovControlGui.new(nil, gui, l10n, settingsModel)

  return self
end

function FovControl:initialize()
  self:loadVehicleCameraFovFromXMLFile()

  self.fovControlGui:initialize()
end

function FovControl:loadMap(filename)
  self.fovControlGui:loadMap()
end

function FovControl:loadVehicleCameraFovFromXMLFile()
  local xmlFile = XMLFile.loadIfExists("FovControlXML", FovControl.MOD_SETTINGS_DIRECTORY .. "fovControl.xml", "vehicles")

  if xmlFile ~= nil then
    xmlFile:iterate("vehicles.vehicle", function (_, key)
      local xmlFilename = xmlFile:getString(key .. "#xmlFilename")

      if xmlFilename ~= nil and xmlFilename ~= "" then
        self.modifiedVehicles[xmlFilename] = {}

        xmlFile:iterate(key .. ".cameras.camera", function (_, cameraKey)
          local cameraId = xmlFile:getInt(cameraKey .. "#id")

          if cameraId then
            self.modifiedVehicles[xmlFilename][cameraId] = {
              fov = xmlFile:getFloat(cameraKey .. "#fov")
            }
          end
        end)
      end
    end)

    xmlFile:delete()
  end
end

function FovControl:saveVehicleCameraFovToXMLFile()
  local xmlFile = XMLFile.create("FovControlXML", FovControl.MOD_SETTINGS_DIRECTORY .. "fovControl.xml", "vehicles")

  if xmlFile ~= nil then
    local i = 0

    for vehicle, cameras in pairs(self.modifiedVehicles) do
      local key = string.format("vehicles.vehicle(%s)", i)

      xmlFile:setString(key .. "#xmlFilename", vehicle)
      xmlFile:setSortedTable(key .. ".cameras.camera", cameras, function (cameraKey, camera, index)
        xmlFile:setInt(cameraKey .. "#id", index)
        xmlFile:setFloat(cameraKey .. "#fov", camera.fov)
      end)

      i = i + 1
    end

    xmlFile:save()
    xmlFile:delete()
  end
end

function FovControl:saveVehicleCameraFov()
  local controlledVehicle = g_currentMission.controlledVehicle

  if controlledVehicle ~= nil then
    local spec = controlledVehicle.spec_enterable

    self.modifiedVehicles[controlledVehicle.configFileName] = {}

    for i = 1, #spec.cameras do
      local camera = spec.cameras[i]

      self.modifiedVehicles[controlledVehicle.configFileName][i] = {
        fov = getFovY(camera.cameraNode)
      }
    end
  end

  self:saveVehicleCameraFovToXMLFile()
end

function FovControl:actionEventToggleFovControl(actionName, inputValue, callbackState, isAnalog)
  g_gui:showDialog("FovControlDialog")
end

function FovControl:getVehicleActiveCameraFov()
  local controlledVehicle = g_currentMission.controlledVehicle

  if controlledVehicle ~= nil then
    local activeCamera = controlledVehicle:getActiveCamera()

    if activeCamera ~= nil then
      return getFovY(activeCamera.cameraNode)
    end
  end

  return nil
end

function FovControl:getVehicleActiveCameraDefaultFov()
  local controlledVehicle = g_currentMission.controlledVehicle

  if controlledVehicle ~= nil then
    local activeCamera = controlledVehicle:getActiveCamera()

    if activeCamera ~= nil then
      return activeCamera.fovY
    end
  end

  return nil
end

g_fovControl = FovControl.new(_, g_gui, g_i18n, SettingsModel.new(g_gameSettings, g_savegameXML, g_i18n, g_soundMixer, GS_IS_CONSOLE_VERSION))

addModEventListener(g_fovControl)

local function validateTypes(self)
  if self.typeName == "vehicle" then
    g_fovControl:initialize()
  end
end

TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, validateTypes)

local function onRegisterActionEvents(self, isActiveForInput, isActiveForInputIgnoreSelection)
  if self:getIsEntered() then
    local spec = self.spec_enterable

    if isActiveForInputIgnoreSelection then
      local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_FOV_CONTROL, self, FovControl.actionEventToggleFovControl, false, true, false, true, nil)

      g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("action_openFovControl"))
      g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
    end
  end
end

Enterable.onRegisterActionEvents = Utils.appendedFunction(Enterable.onRegisterActionEvents, onRegisterActionEvents)

local function onPostLoad(self, savegame)
  local spec = self.spec_enterable
  local modifiedVehicle = g_fovControl.modifiedVehicles[self.configFileName]

  if modifiedVehicle ~= nil then
    for i = 1, #spec.cameras do
      local camera = spec.cameras[i]
      local modifiedCamera = modifiedVehicle[i]

      if modifiedCamera then
        setFovY(camera.cameraNode, modifiedCamera.fov)
      end
    end
  end
end

Enterable.onPostLoad = Utils.appendedFunction(Enterable.onPostLoad, onPostLoad)