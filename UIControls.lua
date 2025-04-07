-- UIControls.lua
-- Funciones de control de la interfaz para QuestLog

function QuestLog:CreateMinimapButton()
    local button = CreateFrame("Button", "QuestLogMinimapButton", Minimap)
    button:SetWidth(31)
    button:SetHeight(31)
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetWidth(53)
    overlay:SetHeight(53)
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    
    -- Posicionamiento y arrastre
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
    button:RegisterForDrag("LeftButton")
    
    local lastX, lastY = 0, 0
    local minimapShapes = {
        ["ROUND"] = {true, true, true, true},
        ["SQUARE"] = {false, false, false, false},
        ["CORNER-TOPLEFT"] = {false, false, false, true},
        ["CORNER-TOPRIGHT"] = {false, false, true, false},
        ["CORNER-BOTTOMLEFT"] = {false, true, false, false},
        ["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
        ["SIDE-LEFT"] = {false, true, false, true},
        ["SIDE-RIGHT"] = {true, false, true, false},
        ["SIDE-TOP"] = {false, false, true, true},
        ["SIDE-BOTTOM"] = {true, true, false, false},
        ["TRICORNER-TOPLEFT"] = {false, true, true, true},
        ["TRICORNER-TOPRIGHT"] = {true, false, true, true},
        ["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
        ["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
    }
    
    local function updatePosition()
        local scale = Minimap:GetEffectiveScale()
        local x, y = GetCursorPosition()
        x, y = x / scale, y / scale
        local centerX, centerY = Minimap:GetCenter()
        local width, height = Minimap:GetWidth(), Minimap:GetHeight()
        
        local radius = width / 2
        x = x - centerX
        y = y - centerY
        
        local angle = math.atan2(y, x)
        x = math.cos(angle) * radius
        y = math.sin(angle) * radius
        
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    
    button:SetScript("OnDragStart", function()
        button:SetScript("OnUpdate", updatePosition)
    end)
    
    button:SetScript("OnDragStop", function()
        button:SetScript("OnUpdate", nil)
    end)
    
    button:SetScript("OnClick", function()
        if QuestLog.frame:IsVisible() then
            QuestLog.frame:Hide()
            QuestLog.detailFrame:Hide()
        else
            QuestLog:ShowQuestLogFrame()
        end
    end)
    
    self.minimapButton = button
end

function QuestLog:ShowQuestLogFrame()
    self.frame:Show()
    self.detailFrame:Show()
    self:UpdateQuestList()
end

function QuestLog:SelectQuest(questID)
    self.selectedQuest = questID
    local quest = self.db.account.quests[questID]
    
    if not quest then
        self.detailContent:SetText("No se encontró información para esta misión.")
        return
    end
    
    local statusText = {
        accepted = "Aceptada",
        completed = "Completada",
        abandoned = "Abandonada"
    }
    
    local text = self.colors.header .. "Misión: |r" .. quest.title .. "\n\n"
    text = text .. self.colors.header .. "Nivel: |r" .. quest.level .. "\n"
    text = text .. self.colors.header .. "Estado: |r" .. (statusText[quest.status] or "Desconocido") .. "\n"
    
    -- Mostrar nivel del jugador al aceptar y completar
    if quest.playerLevel then
        text = text .. self.colors.header .. "Nivel al aceptar: |r" .. quest.playerLevel .. "\n"
    end
    if quest.completionLevel then
        text = text .. self.colors.header .. "Nivel al completar: |r" .. quest.completionLevel .. "\n"
    end
    
    -- Mostrar XP ganada si está disponible
    if quest.xpGained and quest.xpGained > 0 then
        text = text .. self.colors.header .. "Experiencia ganada: |r" .. quest.xpGained .. " XP\n"
    end
    
    text = text .. "\n"
    
    if quest.acceptCoords then
        text = text .. self.colors.header .. "Aceptada en: |r" .. quest.acceptCoords.zone .. "\n"
        text = text .. "Coordenadas: (" .. quest.acceptCoords.x .. ", " .. quest.acceptCoords.y .. ")\n\n"
    end
    
    if quest.turnInCoords then
        text = text .. self.colors.header .. "Entregada en: |r" .. quest.turnInCoords.zone .. "\n"
        text = text .. "Coordenadas: (" .. quest.turnInCoords.x .. ", " .. quest.turnInCoords.y .. ")\n\n"
    end
    
    if quest.completionTime and quest.completionTime > 0 then
        text = text .. self.colors.header .. "Tiempo de completado: |r" .. self:FormatTime(quest.completionTime) .. "\n\n"
    end
    
    if quest.manualCoords and table.getn(quest.manualCoords) > 0 then
        text = text .. self.colors.header .. "Coordenadas manuales:\n|r"
        for i, coord in ipairs(quest.manualCoords) do
            text = text .. i .. ". " .. coord.zone .. " (" .. coord.x .. ", " .. coord.y .. ")\n"
        end
    end
    
    self.detailContent:SetText(text)
end

function QuestLog:AddManualCoord()
    if not self.selectedQuest then
        self:Print("Primero selecciona una misión.")
        return
    end
    
    local quest = self.db.account.quests[self.selectedQuest]
    if not quest then return end
    
    -- Obtener coordenadas actuales
    local x, y = GetPlayerMapPosition("player")
    x = math.floor(x * 10000) / 100
    y = math.floor(y * 10000) / 100
    
    -- Añadir coordenada manual
    quest.manualCoords = quest.manualCoords or {}
    table.insert(quest.manualCoords, {
        x = x,
        y = y,
        zone = GetZoneText(),
        timestamp = time()
    })
    
    self:Print("Coordenada manual añadida para " .. quest.title .. " en " .. GetZoneText() .. " (" .. x .. ", " .. y .. ")")
    self:SelectQuest(self.selectedQuest) -- Actualizar el panel de detalles
end

function QuestLog:DeleteCoord()
    if not self.selectedQuest then
        self:Print("Primero selecciona una misión.")
        return
    end
    
    local quest = self.db.account.quests[self.selectedQuest]
    if not quest or not quest.manualCoords or table.getn(quest.manualCoords) == 0 then
        self:Print("No hay coordenadas manuales para eliminar.")
        return
    end
    
    -- Crear un diálogo simple para elegir qué coordenada eliminar
    StaticPopupDialogs["QUESTLOG_DELETE_COORD"] = {
        text = "Eliminar coordenada número (1-" .. table.getn(quest.manualCoords) .. "):",
        button1 = "Eliminar",
        button2 = "Cancelar",
        hasEditBox = true,
        maxLetters = 2,
        OnAccept = function()
            local index = tonumber(getglobal(this:GetParent():GetName().."EditBox"):GetText())
            if index and index >= 1 and index <= table.getn(quest.manualCoords) then
                local coord = quest.manualCoords[index]
                table.remove(quest.manualCoords, index)
                QuestLog:Print("Coordenada eliminada: " .. coord.zone .. " (" .. coord.x .. ", " .. coord.y .. ")")
                QuestLog:SelectQuest(QuestLog.selectedQuest) -- Actualizar el panel de detalles
            else
                QuestLog:Print("Número de coordenada inválido.")
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("QUESTLOG_DELETE_COORD")
end

-- Función para exportar datos a un archivo
function QuestLog:ExportData()
    local output = "QuestLog Export - " .. date("%Y-%m-%d %H:%M:%S") .. "\n\n"
    
    for _, quest in pairs(self.db.account.quests) do
        output = output .. "Misión: " .. quest.title .. " [" .. quest.level .. "]\n"
        output = output .. "Estado: " .. quest.status .. "\n"
        
        if quest.playerLevel then
            output = output .. "Nivel al aceptar: " .. quest.playerLevel .. "\n"
        end
        if quest.completionLevel then
            output = output .. "Nivel al completar: " .. quest.completionLevel .. "\n"
        end
        
        if quest.acceptCoords then
            output = output .. "Aceptada en: " .. quest.acceptCoords.zone .. " (" .. quest.acceptCoords.x .. ", " .. quest.acceptCoords.y .. ")\n"
        end
        
        if quest.turnInCoords then
            output = output .. "Entregada en: " .. quest.turnInCoords.zone .. " (" .. quest.turnInCoords.x .. ", " .. quest.turnInCoords.y .. ")\n"
        end
        
        if quest.completionTime and quest.completionTime > 0 then
            output = output .. "Tiempo de completado: " .. self:FormatTime(quest.completionTime) .. "\n"
        end
        
        if quest.manualCoords and table.getn(quest.manualCoords) > 0 then
            output = output .. "Coordenadas manuales:\n"
            for i, coord in ipairs(quest.manualCoords) do
                output = output .. "  " .. i .. ". " .. coord.zone .. " (" .. coord.x .. ", " .. coord.y .. ")\n"
            end
        end
        
        output = output .. "\n"
    end
    
    -- La salida se guarda en el archivo WTF\Account\ACCOUNTNAME\SavedVariables\QuestLog.lua
    -- También podemos mostrarla para copiar y pegar
    self:Print("Los datos se han guardado en WTF\\Account\\ACCOUNTNAME\\SavedVariables\\QuestLogDB.lua")
    
    -- Crear un frame para mostrar los datos
    local frame = CreateFrame("Frame", "QuestLogExportFrame", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetWidth(500)
    frame:SetHeight(400)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("Exportar Datos de QuestLog")
    
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    
    local scrollFrame = CreateFrame("ScrollFrame", "QuestLogExportScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 40)
    
    local editBox = CreateFrame("EditBox", "QuestLogExportEditBox", scrollFrame)
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetHeight(scrollFrame:GetHeight())
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlight)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    editBox:SetText(output)
    
    scrollFrame:SetScrollChild(editBox)
    
    table.insert(UISpecialFrames, "QuestLogExportFrame")
end