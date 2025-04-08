-- UI.lua
-- Funciones de la interfaz de usuario para QuestLog

-- Reemplaza la función UpdateQuestList en UI.lua con esta versión mejorada
-- Mejora 3: Actualizar función UpdateQuestList para mostrar el nuevo estado
-- Modificar la función UpdateQuestList en UI.lua

-- Mejora para la función UpdateQuestList en UI.lua para mostrar el nuevo estado más claramente
function QuestLog:UpdateQuestList()
    local quests = self:GetQuestList()
    
    -- Ordenar por timestamp (más recientes primero) si no hay un orden personalizado
    if not self.db.account.questOrder or not next(self.db.account.questOrder) then
        table.sort(quests, function(a, b) 
            -- Si ambas misiones tienen el mismo estado, priorizar por timestamp
            if a.status == b.status then
                -- Para misiones aceptadas, priorizar las que tienen objetivos completados
                if a.status == "accepted" then
                    if a.objectivesCompleted and not b.objectivesCompleted then
                        return true
                    elseif not a.objectivesCompleted and b.objectivesCompleted then
                        return false
                    end
                end
                
                return (a.timestamp or 0) > (b.timestamp or 0)
            end
            
            -- Priorizar misiones con objetivos completados
            if a.status == "accepted" and a.objectivesCompleted and not (b.status == "accepted" and b.objectivesCompleted) then
                return true
            elseif b.status == "accepted" and b.objectivesCompleted and not (a.status == "accepted" and a.objectivesCompleted) then
                return false
            end
            
            -- Luego priorizar misiones activas sobre las completadas/abandonadas
            if a.status == "accepted" and b.status ~= "accepted" then
                return true
            elseif a.status ~= "accepted" and b.status == "accepted" then
                return false
            end
            
            -- Luego priorizar completadas sobre abandonadas
            if a.status == "completed" and b.status == "abandoned" then
                return true
            elseif a.status == "abandoned" and b.status == "completed" then
                return false
            end
            
            -- Si llegamos aquí, tienen mismo estado, ordenar por timestamp
            return (a.timestamp or 0) > (b.timestamp or 0)
        end)
    end
    
    local numEntries = table.getn(quests)
    local maxDisplayed = 15
    
    -- Asegurarnos de que el scrollPos esté en un rango válido
    if not self.scrollPos then
        self.scrollPos = 0
    end
    
    -- Limitar el rango de desplazamiento
    local maxScroll = math.max(0, numEntries - maxDisplayed)
    if self.scrollPos > maxScroll then
        self.scrollPos = maxScroll
    end
    
    -- Actualizar los botones de scroll
    if self.scrollUpButton then
        if self.scrollPos > 0 then
            self.scrollUpButton:Enable()
        else
            self.scrollUpButton:Disable()
        end
    end
    
    if self.scrollDownButton then
        if self.scrollPos < maxScroll then
            self.scrollDownButton:Enable()
        else
            self.scrollDownButton:Disable()
        end
    end

    -- Versión más compacta de la visualización de coordenadas
    local function formatCoords(zone, x, y)
        -- Abreviar nombres de zona muy largos
        if string.len(zone) > 8 then
            zone = string.sub(zone, 1, 8) .. ".."
        end
        
        -- Coordenadas sin espacios y redondeadas si son necesarias
        local xDisplay = math.floor(x * 10) / 10
        local yDisplay = math.floor(y * 10) / 10
        
        return zone .. "(" .. xDisplay .. "," .. yDisplay .. ")"
    end
    
    -- Actualizar cada botón
    for i = 1, maxDisplayed do
        local button = self.buttons[i]
        local index = i + self.scrollPos
        
        if index <= numEntries then
            local quest = quests[index]
            
            -- Determinar el color basado en el estado
            local statusColor
            if quest.status == "accepted" and quest.objectivesCompleted then
                statusColor = self.colors.objectives_complete or "|cFF00FFFF" -- Color cian para objetivos completados
            else
                statusColor = self.colors[quest.status] or self.colors.accepted
            end
            
            -- Añadimos indicador visual para mostrar el estado
            local titleText = statusColor .. quest.title .. " |r[" .. quest.level .. "]"
            
            -- Añadir indicadores de tiempo para los diferentes estados
            if quest.status == "completed" and quest.turnInTimestamp then
                local timeAgo = self:FormatTimeAgo(time() - quest.turnInTimestamp)
                titleText = titleText .. " |cff7f7f7f(Entregada: " .. timeAgo .. ")|r"
            elseif quest.status == "accepted" and quest.objectivesCompleted and quest.objectivesCompletedTimestamp then
                local timeAgo = self:FormatTimeAgo(time() - quest.objectivesCompletedTimestamp)
                titleText = titleText .. " |cff00ffff(Listo: " .. timeAgo .. ")|r"
            elseif quest.status == "accepted" and quest.timestamp then
                local timeAgo = self:FormatTimeAgo(time() - quest.timestamp)
                titleText = titleText .. " |cffaaaaff(" .. timeAgo .. ")|r"
            end
            
            button.title:SetText(titleText)
            button.questID = quest.questID
            button.upButton.questID = quest.questID
            button.downButton.questID = quest.questID
            
            -- Mostrar coordenadas relevantes según el estado
            local coordText = ""
            if quest.status == "accepted" and quest.objectivesCompleted and quest.objectivesCompletedCoords then
                local coords = quest.objectivesCompletedCoords
                coordText = formatCoords(coords.zone, coords.x, coords.y)
            elseif quest.status == "completed" and quest.turnInCoords then
                local coords = quest.turnInCoords
                coordText = formatCoords(coords.zone, coords.x, coords.y)
            elseif quest.acceptCoords then
                local coords = quest.acceptCoords
                coordText = formatCoords(coords.zone, coords.x, coords.y)
            end
            button.coords:SetText(coordText)
            
            button:Show()
            button.upButton:Show()
            button.downButton:Show()
        else
            button:Hide()
            button.upButton:Hide()
            button.downButton:Hide()
        end
    end
end

-- Añadir función para formatear tiempo relativo (cuánto tiempo ha pasado)
function QuestLog:FormatTimeAgo(seconds)
    if seconds < 60 then
        return seconds .. "s"
    elseif seconds < 3600 then
        return math.floor(seconds/60) .. "m"
    elseif seconds < 86400 then
        return math.floor(seconds/3600) .. "h"
    else
        return math.floor(seconds/86400) .. "d"
    end
end

-- Función para desplazarse hacia arriba
function QuestLog:ScrollUp()
    if not self.scrollPos then
        self.scrollPos = 0
    end
    
    if self.scrollPos > 0 then
        self.scrollPos = self.scrollPos - 1
        self:UpdateQuestList()
    end
end

-- Función para desplazarse hacia abajo
function QuestLog:ScrollDown()
    local quests = self:GetQuestList()
    local numEntries = table.getn(quests)
    local maxDisplayed = 15
    local maxScroll = math.max(0, numEntries - maxDisplayed)
    
    if not self.scrollPos then
        self.scrollPos = 0
    end
    
    if self.scrollPos < maxScroll then
        self.scrollPos = self.scrollPos + 1
        self:UpdateQuestList()
    end
end

-- Función para desplazarse una página hacia arriba
function QuestLog:ScrollPageUp()
    if not self.scrollPos then
        self.scrollPos = 0
    end
    
    self.scrollPos = math.max(0, self.scrollPos - 10)
    self:UpdateQuestList()
end

-- Función para desplazarse una página hacia abajo
function QuestLog:ScrollPageDown()
    local quests = self:GetQuestList()
    local numEntries = table.getn(quests)
    local maxDisplayed = 15
    local maxScroll = math.max(0, numEntries - maxDisplayed)
    
    if not self.scrollPos then
        self.scrollPos = 0
    end
    
    self.scrollPos = math.min(maxScroll, self.scrollPos + 10)
    self:UpdateQuestList()
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
-- Reemplaza la función CreateQuestLogFrame con esta versión personalizada
-- Esta función crea la interfaz gráfica principal
function QuestLog:CreateQuestLogFrame()
    -- Crear frame principal
    local frame = CreateFrame("Frame", "QuestLogFrame", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetWidth(550)  -- Aumentar el ancho del marco principal para acomodar los botones
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
    
    -- Área para la lista de misiones (que reemplaza al ScrollFrame)
    local listArea = CreateFrame("Frame", "QuestLogListArea", frame)
    listArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 45, -40)  -- Mover más a la derecha para dar espacio a los botones
    listArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -25, 40)  -- Ajustar para dejar espacio para la barra de desplazamiento
    
    -- Botón de desplazamiento hacia arriba
    local scrollUpButton = CreateFrame("Button", "QuestLogScrollUpButton", frame, "UIPanelScrollUpButtonTemplate")
    scrollUpButton:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", 0, 5)
    scrollUpButton:SetScript("OnClick", function() QuestLog:ScrollUp() end)
    
    -- Botón de desplazamiento hacia abajo
    local scrollDownButton = CreateFrame("Button", "QuestLogScrollDownButton", frame, "UIPanelScrollDownButtonTemplate")
    scrollDownButton:SetPoint("BOTTOMRIGHT", listArea, "BOTTOMRIGHT", 0, -5)
    scrollDownButton:SetScript("OnClick", function() QuestLog:ScrollDown() end)
    
    -- Guardar referencias a los botones de desplazamiento
    self.scrollUpButton = scrollUpButton
    self.scrollDownButton = scrollDownButton
    
    -- Inicializar el desplazamiento
    self.scrollPos = 0
    
    -- Crear botones para cada entrada de la lista
    local buttons = {}
    for i = 1, 15 do
        local button = CreateFrame("Button", "QuestLogButton" .. i, listArea)
        button:SetWidth(440)
        button:SetHeight(20)
        button:SetPoint("TOPLEFT", listArea, "TOPLEFT", 5, -((i-1) * 20))
        
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        
        -- Modificación para el título de la misión - reducir ancho para dar más espacio a coordenadas
        local title = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("LEFT", button, "LEFT", 5, 0)
        title:SetWidth(280) -- Reducido de 300 a 280
        title:SetJustifyH("LEFT")
        
        -- Modificación para las coordenadas - cambiar a formato compacto en una sola línea
        local coords = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") -- Usar fuente más pequeña
        coords:SetPoint("RIGHT", button, "RIGHT", -20, 0) -- 20px de margen desde el borde derecho
        coords:SetWidth(130) -- Aumentado ligeramente el ancho
        coords:SetJustifyH("RIGHT")
        
        button.title = title
        button.coords = coords
        
        button:SetScript("OnClick", function()
            QuestLog:SelectQuest(this.questID)
        end)
        
        buttons[i] = button
    end
    
    -- Responder a eventos del mouse wheel para scroll
    listArea:EnableMouseWheel(true)
    -- Crear función de manejo de rueda para el addon
    function QuestLog:OnMouseWheel()
        if arg1 > 0 then
            self:ScrollUp()
        else
            self:ScrollDown()
        end
    end

    -- Asignar el evento al listArea
    listArea:SetScript("OnMouseWheel", function() 
        QuestLog:OnMouseWheel() 
    end)
    
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
    self.listArea = listArea
    self.buttons = buttons
    self.detailFrame = detailFrame
    self.detailContent = detailContent
    self.selectedQuest = nil
    
    -- IMPORTANTE: Crear los botones de movimiento DESPUÉS de asignar self.buttons
    for i = 1, 15 do
        -- Botón para mover arriba
        local upButton = CreateFrame("Button", "QuestLogUpButton" .. i, frame)
        upButton:SetWidth(20)
        upButton:SetHeight(20)
        upButton:SetPoint("RIGHT", self.buttons[i], "LEFT", -5, 0)
        upButton:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
        upButton:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down")
        upButton:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Highlight")
        upButton:SetScript("OnClick", function()
            if this.questID then
                QuestLog:MoveQuestUp(this.questID)
            end
        end)
        self.buttons[i].upButton = upButton
        
        -- Botón para mover abajo
        local downButton = CreateFrame("Button", "QuestLogDownButton" .. i, frame)
        downButton:SetWidth(20)
        downButton:SetHeight(20)
        downButton:SetPoint("RIGHT", upButton, "LEFT", -2, 0)
        downButton:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
        downButton:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
        downButton:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight")
        downButton:SetScript("OnClick", function()
            if this.questID then
                QuestLog:MoveQuestDown(this.questID)
            end
        end)
        self.buttons[i].downButton = downButton
    end
    
    -- Añadir a los frames especiales para cerrar con Escape
    table.insert(UISpecialFrames, "QuestLogFrame")
    table.insert(UISpecialFrames, "QuestLogDetailFrame")
    
    -- Agregar soporte para teclas de página arriba/abajo
    frame:SetScript("OnKeyDown", function()
        if arg1 == "PAGEUP" then
            QuestLog:ScrollPageUp()
        elseif arg1 == "PAGEDOWN" then
            QuestLog:ScrollPageDown()
        end
    end)
    
    -- Actualizar la lista de misiones al inicio
    self:UpdateQuestList()
end