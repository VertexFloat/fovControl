-- @author: 4c65736975, All Rights Reserved
-- @version: 1.0.0.2, 20|09|2023
-- @filename: FovControlDialog.lua

-- Changelog (1.0.0.1):
-- improved and cleaned code

-- Changelog (1.0.0.2):
-- removed unnecessary code

FovControlDialog = {
  CONTROLS = {
    "fovElement",
    "bgElement",
    "btnRemoveBgElement"
  }
}

local FovControlDialog_mt = Class(FovControlDialog, MessageDialog)

function FovControlDialog.new(target, customMt, l10n, settingsModel)
  local self = MessageDialog.new(target, customMt or FovControlDialog_mt)

  self.l10n = l10n
  self.settingsModel = settingsModel
  self.selectedFovValue = nil
  self.lastValidFovValue = nil

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
  self.lastValidFovValue = MathUtil.round(math.deg(g_fovControl:getVehicleActiveCameraFov()))

  self:setState(self.lastValidFovValue)
end

function FovControlDialog:setState(state)
  if state ~= nil then
    if self.settingsModel.fovYToIndexMapping[state] ~= nil then
      self.fovElement:setState(self.settingsModel.fovYToIndexMapping[state])

      self.selectedFovValue = state
    end
  end
end

function FovControlDialog:save()
  g_fovControl:saveVehicleCameraFov()
end

function FovControlDialog:onClickFovValue(state)
  self.selectedFovValue = self.settingsModel.indexToFovYMapping[state]

  g_currentMission:consoleCommandSetFOV(self.selectedFovValue)
end

function FovControlDialog:onClickApply()
  self:save()
  self:close()
end

function FovControlDialog:onClickRemoveBackground()
  self.bgElement:setVisible(not self.bgElement.visible)

  self.btnRemoveBgElement.text = not self.bgElement.visible and self.l10n:getText("button_addBackground"):upper() or self.l10n:getText("button_removeBackground"):upper()
end

function FovControlDialog:onClickResetFov()
  local defaultFovValue = MathUtil.round(math.deg(g_fovControl:getVehicleActiveCameraDefaultFov()))

  if defaultFovValue == nil then
    defaultFovValue = self.lastValidFovValue
  end

  self:setState(defaultFovValue)

  g_currentMission:consoleCommandSetFOV(defaultFovValue)
end

function FovControlDialog:onClickBack()
  g_currentMission:consoleCommandSetFOV(self.lastValidFovValue)

  self:close()
end