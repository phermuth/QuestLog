-- UI.lua
-- Funciones de la interfaz de usuario para QuestLog

function QuestLog:UpdateQuestList()
    local quests = self:GetQuestList()
    
    -- Ordenar por timestamp (más recientes primero)
    table.sort(quests, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
    
    local numEntries = table.getn(quests)
    local maxDisplayed = 15
    
    -- Configurar el scroll frame
    FauxScrollFrame_Update(self.scrollFrame, numEntries, maxDisplayed, 20)
    local offset = FauxScrollFrame_GetOffset(self.scrollFrame)
    
    -- Actualizar cada botón
    for i = 1, maxDisplayed do
        local button = self.buttons[i]
        local index = i + offset
        
        if index <= numEntries then
            local quest = quests[index]
            local statusColor = colors[quest.status] or colors.accepted
            
            button.title:SetText(statusColor .. quest.title .. " |r[" .. quest.level .. "]")
            button.questID = quest.questID
            
            local coordText = ""
            if quest.acceptCoords then
                coordText = quest.acceptCoords.zone .. " (" .. quest.acceptCoords.x .. ", " .. quest.acceptCoords.y .. ")"
            end
            button.coords:SetText(coordText)
            
            button:Show()
        else
            button:Hide()
        end
    end
end

function QuestLog:ShowQuestStats()
    local quests = self:GetQuestList()
    local totalQuests = 0
    local completedQuests = 0
    local abandonedQuests = 0
    local acceptedQuests = 0
    local totalCompletionTime = 0
    local totalXP = 0
    local questsByZone = {}
    
    for _, quest in pairs(quests) do
        totalQuests = totalQuests + 1
        
        if quest.status == "completed" then
            completedQuests = completedQuests + 1
            if quest.completionTime then
                totalCompletionTime = totalCompletionTime + quest.completionTime
            end
            if quest.xpGained then
                totalXP = totalXP + quest.xpGained
            end
            
            -- Contabilizar por zona
            local zone = quest.acceptCoords and quest.acceptCoords.zone or "Desconocida"
            questsByZone[zone] = questsByZone[zone] or {count = 0, time = 0, xp = 0}
            questsByZone[zone].count = questsByZone[zone].count + 1
            if quest.completionTime then
                questsByZone[zone].time = questsByZone[zone].time + quest.completionTime
            end
            if quest.xpGained then
                questsByZone[zone].xp = questsByZone[zone].xp + quest.xpGained
            end
        elseif quest.status == "abandoned" then
            abandonedQuests = abandonedQuests + 1
        elseif quest.status == "accepted" then
            acceptedQuests = acceptedQuests + 1
        end
    end
    
    -- Calcular tiempos medios y XP media
    local avgCompletionTime = completedQuests > 0 and (totalCompletionTime / completedQuests) or 0
    local avgXP = completedQuests > 0 and (totalXP / completedQuests) or 0
    local xpPerHour = 0
    if totalCompletionTime > 0 then
        xpPerHour = totalXP / (totalCompletionTime / 3600) -- XP por hora
    end
    
    -- Crear un resumen estadístico
    local summary = ""
    
    -- Verificar que tenemos datos
    if totalQuests == 0 then
        summary = "No hay misiones registradas en tu bitácora.\n\nCompletando misiones se irán registrando automáticamente aquí."
    else
        summary = "Estadísticas de Misiones:\n\n"
        summary = summary .. "Total de misiones registradas: " .. totalQuests .. "\n"
        summary = summary .. "Misiones completadas: " .. completedQuests .. "\n"
        summary = summary .. "Misiones abandonadas: " .. abandonedQuests .. "\n"
        summary = summary .. "Misiones en curso: " .. acceptedQuests .. "\n\n"
        
        if completedQuests > 0 then
            summary = summary .. "Tiempo medio de completado: " .. self:FormatTime(avgCompletionTime) .. "\n"
            if totalXP > 0 then
                summary = summary .. "Experiencia total ganada: " .. totalXP .. " XP\n"
                summary = summary .. "Experiencia media por misión: " .. math.floor(avgXP) .. " XP\n"
                if xpPerHour > 0 then
                    summary = summary .. "Tasa de XP por hora: " .. math.floor(xpPerHour) .. " XP/hora\n"
                end
            end
            summary = summary .. "\n"
        end
        
        if next(questsByZone) then
            summary = summary .. "Misiones por zona:\n"
            for zone, data in pairs(questsByZone) do
                local avgTime = data.count > 0 and (data.time / data.count) or 0
                local avgZoneXP = data.count > 0 and (data.xp / data.count) or 0
                local zoneXPPerHour = data.time > 0 and (data.xp / (data.time / 3600)) or 0
                
                summary = summary .. "- " .. zone .. ": " .. data.count .. " misiones"
                if avgTime > 0 then
                    summary = summary .. " (Tiempo medio: " .. self:FormatTime(avgTime) .. ")"
                end
                
                if data.xp > 0 then
                    summary = summary .. "\n  XP total: " .. data.xp .. " XP"
                    summary = summary .. ", Media: " .. math.floor(avgZoneXP) .. " XP/misión"
                    if zoneXPPerHour > 0 then
                        summary = summary .. ", Tasa: " .. math.floor(zoneXPPerHour) .. " XP/hora"
                    end
                end
                
                summary = summary .. "\n"
            end
        end
    end
    
    -- Mostrar en un diálogo mejorado
    self:ShowStatsDialog(summary)
end

function QuestLog:ShowStatsDialog(statsText)
    -- Cerrar el diálogo anterior si existe
    local oldFrame = getglobal("QuestLogStatsFrame")
    if oldFrame then
        oldFrame:Hide()
    end

    -- Crear un frame para mostrar las estadísticas
    local frame = CreateFrame("Frame", "QuestLogStatsFrame", UIParent)
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
    title:SetText("Estadísticas de QuestLog")
    
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    
    -- Crear un marco simple con texto
    local textArea = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -40)
    textArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -25, 25)
    textArea:SetJustifyH("LEFT")
    textArea:SetJustifyV("TOP")
    textArea:SetText(statsText)
    
    -- Asegurar que el frame se cierra con Escape
    table.insert(UISpecialFrames, "QuestLogStatsFrame")
    
    -- Mostrar el frame
    frame:Show()
end

-- Funciones para la interfaz de usuario
function QuestLog:CreateQuestLogFrame()
    -- Crear frame principal
    local frame = CreateFrame("Frame", "QuestLogFrame", UIParent)
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
    frame:Hide()
    
    -- Botón de cerrar
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    
    -- Título
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("Bitácora de Misiones")
    
    -- Botón de estadísticas
    local statsButton = CreateFrame("Button", "QuestLogStatsButton", frame, "UIPanelButtonTemplate")
    statsButton:SetWidth(100)
    statsButton:SetHeight(25)
    statsButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -10)
    statsButton:SetText("Estadísticas")
    statsButton:SetScript("OnClick", function() QuestLog:ShowQuestStats() end)
    
    -- Crear ScrollFrame para la lista de misiones
    local scrollFrame = CreateFrame("ScrollFrame", "QuestLogScrollFrame", frame, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 40)
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 20, function() QuestLog:UpdateQuestList() end)
    end)
    
    -- Crear botones para cada entrada de la lista
    local buttons = {}
    for i = 1, 15 do
        local button = CreateFrame("Button", "QuestLogButton" .. i, frame)
        button:SetWidth(440)
        button:SetHeight(20)
        button:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 5, -((i-1) * 20))
        
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        
        local title = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("LEFT", button, "LEFT", 5, 0)
        title:SetWidth(300)
        title:SetJustifyH("LEFT")
        
        local coords = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        coords:SetPoint("RIGHT", button, "RIGHT", -5, 0)
        coords:SetWidth(130)
        coords:SetJustifyH("RIGHT")
        
        button.title = title
        button.coords = coords
        
        button:SetScript("OnClick", function()
            QuestLog:SelectQuest(this.questID)
        end)
        
        buttons[i] = button
    end
    
    -- Panel de detalles
    local detailFrame = CreateFrame("Frame", "QuestLogDetailFrame", frame)
    detailFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 5, 0)
    detailFrame:SetWidth(300)
    detailFrame:SetHeight(400)
    detailFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    
    -- Título del detalle
    local detailTitle = detailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailTitle:SetPoint("TOP", detailFrame, "TOP", 0, -15)
    detailTitle:SetText("Detalles de la Misión")
    
    -- Contenido del detalle
    local detailContent = detailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailContent:SetPoint("TOPLEFT", detailFrame, "TOPLEFT", 20, -40)
    detailContent:SetPoint("BOTTOMRIGHT", detailFrame, "BOTTOMRIGHT", -20, 60)
    detailContent:SetJustifyH("LEFT")
    detailContent:SetJustifyV("TOP")
    
    -- Botones de acción en el panel de detalles
    local addCoordButton = CreateFrame("Button", "QuestLogAddCoordButton", detailFrame, "UIPanelButtonTemplate")
    addCoordButton:SetWidth(120)
    addCoordButton:SetHeight(25)
    addCoordButton:SetPoint("BOTTOMLEFT", detailFrame, "BOTTOMLEFT", 20, 20)
    addCoordButton:SetText("Añadir Coordenada")
    addCoordButton:SetScript("OnClick", function() QuestLog:AddManualCoord() end)
    
    local deleteCoordButton = CreateFrame("Button", "QuestLogDeleteCoordButton", detailFrame, "UIPanelButtonTemplate")
    deleteCoordButton:SetWidth(120)
    deleteCoordButton:SetHeight(25)
    deleteCoordButton:SetPoint("BOTTOMRIGHT", detailFrame, "BOTTOMRIGHT", -20, 20)
    deleteCoordButton:SetText("Eliminar Coordenada")
    deleteCoordButton:SetScript("OnClick", function() QuestLog:DeleteCoord() end)
    
    -- Guardar referencias
    self.frame = frame
    self.scrollFrame = scrollFrame
    self.buttons = buttons
    self.detailFrame = detailFrame
    self.detailContent = detailContent
    self.selectedQuest = nil
    
    -- Añadir a los frames especiales para cerrar con Escape
    table.insert(UISpecialFrames, "QuestLogFrame")
    table.insert(UISpecialFrames, "QuestLogDetailFrame")
end