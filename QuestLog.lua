-- QuestLog.lua
-- Addon para registrar las misiones completadas y sus coordenadas

QuestLog = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceEvent-2.0", "AceHook-2.1")

-- Inicialización de variables
local defaults = {
    quests = {}, -- Lista de todas las misiones (ahora indexadas por ID único)
    questsByTitle = {}, -- Índice secundario para buscar misiones por título
}

-- Colores para los diferentes estados de las misiones
local colors = {
    accepted = "|cFFFFFFFF", -- Blanco
    completed = "|cFF00FF00", -- Verde
    abandoned = "|cFFFF0000", -- Rojo
    header = "|cFFFFD100",    -- Dorado/Amarillo
}

-- Llevar un seguimiento de las misiones en el log para detectar abandonos
local currentQuestLog = {}

-- Función para generar ID único para una misión
local function GenerateQuestID(title, zone, timestamp)
    local realm = GetRealmName() or "Unknown"
    local player = UnitName("player") or "Unknown"
    return title .. "-" .. realm .. "-" .. player .. "-" .. zone .. "-" .. timestamp
end

function QuestLog:OnInitialize()
    -- Registrar base de datos
    self:RegisterDB("QuestLogDB")
    self:RegisterDefaults("account", defaults)
    
    -- Validar que la estructura de datos esté inicializada correctamente
    self.db.account.quests = self.db.account.quests or {}
    self.db.account.questsByTitle = self.db.account.questsByTitle or {}
    
    -- Comprobar si necesitamos migrar datos antiguos
    self:MigrateOldData()
    
    -- Registrar comandos de chat
    self:RegisterChatCommand({ "/qlog", "/questlog" }, {
        type = "group",
        args = {
            show = {
                type = "execute",
                name = "Mostrar",
                desc = "Muestra la ventana de bitácora de misiones",
                func = function() self:ShowQuestLogFrame() end,
            },
            add = {
                type = "execute",
                name = "Añadir coordenada",
                desc = "Añade una coordenada manual a la última misión seleccionada",
                func = function() self:AddManualCoord() end,
            },
            delete = {
                type = "execute",
                name = "Eliminar coordenada",
                desc = "Elimina una coordenada de la misión seleccionada",
                func = function() self:DeleteCoord() end,
            },
            export = {
                type = "execute",
                name = "Exportar",
                desc = "Exporta los datos de las misiones",
                func = function() self:ExportData() end,
            },
            debug = {
                type = "execute",
                name = "Debug",
                desc = "Muestra información de depuración",
                func = function() 
                    self:Print("Datos en DB: " .. (next(self.db.account.quests) and "Sí" or "No"))
                    local questList = self:GetQuestList()
                    self:Print("Número de misiones: " .. table.getn(questList))
                    for _, quest in ipairs(questList) do
                        self:Print("Misión: " .. quest.title .. " [" .. quest.level .. "] - Estado: " .. quest.status)
                    end
                end,
            },
            stats = {
                type = "execute",
                name = "Estadísticas",
                desc = "Muestra estadísticas de las misiones completadas",
                func = function() self:ShowQuestStats() end,
            },
        },
    })
    
    -- Inicializar la interfaz de usuario
    self:CreateQuestLogFrame()
    
    -- Minimap icon if FuBar is not installed
    self:CreateMinimapButton()
    
    -- Para debug
    self:Print("QuestLog inicializado. DB contiene datos: " .. (next(self.db.account.quests) and "Sí" or "No"))
end

-- Migra los datos del formato antiguo (indexado por título) al nuevo (indexado por ID único)
function QuestLog:MigrateOldData()
    local hasOldData = false
    
    -- Comprobar si hay datos en formato antiguo (directamente indexados por título)
    for title, questData in pairs(self.db.account.quests) do
        if type(questData) == "table" and questData.title and not questData.questID then
            hasOldData = true
            break
        end
    end
    
    if hasOldData then
        self:Print("Migrando datos antiguos al nuevo formato...")
        local newQuests = {}
        local newQuestsByTitle = {}
        
        for title, questData in pairs(self.db.account.quests) do
            -- Asegurarse de que es un formato antiguo y no un índice
            if type(questData) == "table" and questData.title then
                -- Generar un ID único para esta misión
                local zone = (questData.acceptCoords and questData.acceptCoords.zone) or 
                             (questData.turnInCoords and questData.turnInCoords.zone) or "Unknown"
                local timestamp = questData.timestamp or time()
                local questID = GenerateQuestID(title, zone, timestamp)
                
                -- Añadir el ID a los datos
                questData.questID = questID
                
                -- Guardar en la nueva estructura
                newQuests[questID] = questData
                
                -- Añadir al índice por título
                newQuestsByTitle[title] = newQuestsByTitle[title] or {}
                table.insert(newQuestsByTitle[title], questID)
            end
        end
        
        -- Reemplazar la estructura antigua
        self.db.account.quests = newQuests
        self.db.account.questsByTitle = newQuestsByTitle
        
        self:Print("Migración completada. " .. table.getn(self:GetQuestList()) .. " misiones migradas.")
    end
end

function QuestLog:OnEnable()
    -- Registrar eventos usando su nombre exacto
    self:RegisterEvent("QUEST_ACCEPTED")
    self:RegisterEvent("QUEST_COMPLETE")
    self:RegisterEvent("QUEST_FINISHED")
    self:RegisterEvent("QUEST_LOG_UPDATE")
    
    -- Hook de funciones del juego
    -- Nos aseguramos de que estas funciones existan
    self:Hook("AcceptQuest", true)
    self:Hook("CompleteQuest", true)
    
    -- Inicializar el seguimiento de misiones
    for i=1, GetNumQuestLogEntries() do
        local title, _, _, isHeader = GetQuestLogTitle(i)
        if not isHeader and title then
            -- Solo añadimos a nuestro registro de misiones actuales
            currentQuestLog[title] = true
        end
    end
    
    -- Mensaje de inicialización
    self:Print("QuestLog cargado. Usa /qlog para mostrar la bitácora de misiones.")
end

function QuestLog:OnDisable()
    -- Desregistrar eventos
    self:UnregisterAllEvents()
    self:UnhookAll()
end

-- Hooks para funciones del juego
function QuestLog:AcceptQuest()
    -- Cuando se llama a AcceptQuest, guardamos el título
    self.questTitle = GetTitleText()
    self:Print("Aceptando misión: " .. (self.questTitle or "desconocida"))
    -- Luego llamamos a la función original
    self.hooks.AcceptQuest()
end

function QuestLog:CompleteQuest()
    -- Cuando se llama a CompleteQuest, guardamos el título y la XP actual
    self.lastCompletedQuest = GetTitleText()
    self.xpBeforeTurnIn = UnitXP("player")
    
    -- Enviar mensaje a nosotros mismos para debugging
    self:Print("Completando misión: " .. (self.lastCompletedQuest or "desconocida"))
    self:Print("XP antes de entregar: " .. self.xpBeforeTurnIn)
    
    -- Luego llamamos a la función original
    self.hooks.CompleteQuest()
end

-- Métodos para manejar eventos - DEBEN coincidir exactamente con los nombres de los eventos
function QuestLog:QUEST_ACCEPTED()
    -- En Vanilla, QUEST_ACCEPTED no pasa el questIndex como argumento
    -- Tenemos que obtener el título de la misión del marco de la misión
    local title = GetTitleText()
    if not title then 
        self:Print("Error: No se pudo obtener el título de la misión")
        return 
    end
    
    -- Buscamos la información de la misión en el registro de misiones
    local level = 1 -- Valor por defecto
    for i=1, GetNumQuestLogEntries() do
        local questTitle, questLevel, _, isHeader = GetQuestLogTitle(i)
        if not isHeader and questTitle == title then
            level = questLevel
            break
        end
    end
    
    -- Obtener coordenadas actuales
    local x, y = GetPlayerMapPosition("player")
    x = math.floor(x * 10000) / 100
    y = math.floor(y * 10000) / 100
    local zone = GetZoneText()
    
    -- Generar un ID único para esta misión
    local questID = GenerateQuestID(title, zone, time())
    
    -- Añadir la misión a la lista
    self.db.account.quests[questID] = {
        questID = questID,
        title = title,
        level = level,
        acceptCoords = { x = x, y = y, zone = zone },
        status = "accepted",
        turnInCoords = nil,
        timestamp = time(),
        playerLevel = UnitLevel("player"),
    }
    
    -- Actualizar el índice por título
    self.db.account.questsByTitle[title] = self.db.account.questsByTitle[title] or {}
    table.insert(self.db.account.questsByTitle[title], questID)
    
    self:Print("Misión registrada: " .. title .. " en " .. zone .. " (" .. x .. ", " .. y .. ")")
    
    -- Actualizar la UI
    self:UpdateQuestList()
end

function QuestLog:QUEST_COMPLETE()
    -- Este evento se dispara cuando se muestra la ventana de completar misión
    -- Guardamos el título para usarlo cuando se entregue realmente
    local title = GetTitleText()
    if not title then
        self:Print("Error: No se pudo obtener el título de la misión completada")
        return
    end
    
    self.lastCompletedQuest = title
    self:Print("Misión lista para entregar: " .. title)
end

function QuestLog:QUEST_FINISHED()
    -- Este evento se dispara cuando se cierra la ventana de misión después de entregarla
    local title = self.lastCompletedQuest
    if not title then 
        -- Si no tenemos título guardado, intentamos obtenerlo de otra manera
        title = self.questTitle
    end
    
    if not title then
        self:Print("Error: No se pudo identificar la misión entregada")
        return
    end
    
    -- Obtener coordenadas actuales
    local x, y = GetPlayerMapPosition("player")
    x = math.floor(x * 10000) / 100
    y = math.floor(y * 10000) / 100
    local zone = GetZoneText()
    
    -- Guardar XP después de la entrega de la misión (lo hemos capturado en CompleteQuest)
    local currentXP = UnitXP("player")
    self:Print("XP después de entregar: " .. currentXP)
    
    local xpGained = 0
    if self.xpBeforeTurnIn and currentXP > self.xpBeforeTurnIn then
        xpGained = currentXP - self.xpBeforeTurnIn
        self:Print("¡Experiencia calculada correctamente! Ganancia: " .. xpGained .. " XP")
    elseif self.xpBeforeTurnIn then
        -- Si la XP nueva es menor que la anterior, podría ser porque subiste de nivel
        self:Print("XP nueva menor que anterior. Posible subida de nivel o problema en el cálculo.")
        -- En caso de subida de nivel, podríamos intentar calcular la XP considerando el máximo del nivel anterior
        -- Pero por ahora, lo dejamos como 0 para evitar valores incorrectos
        xpGained = 0
    else
        self:Print("No se pudo calcular la XP ganada. No se guardó el valor previo.")
        xpGained = 0
    end
    
    -- Buscar si tenemos esta misión en nuestra base de datos
    local found = false
    if self.db.account.questsByTitle[title] then
        -- Buscar entre las misiones con este título
        for _, questID in ipairs(self.db.account.questsByTitle[title]) do
            local quest = self.db.account.quests[questID]
            if quest and quest.status == "accepted" then
                -- Actualizar la misión existente
                quest.turnInCoords = { x = x, y = y, zone = zone }
                quest.status = "completed"
                quest.completedTimestamp = time()
                quest.completionTime = quest.completedTimestamp - quest.timestamp
                quest.completionLevel = UnitLevel("player")
                quest.xpGained = xpGained
                
                self:Print("Misión completada: " .. title .. " en " .. zone .. " (" .. x .. ", " .. y .. ")")
                self:Print("Tiempo de completado: " .. self:FormatTime(quest.completionTime))
                if xpGained > 0 then
                    self:Print("Experiencia ganada: " .. xpGained .. " XP")
                else
                    self:Print("No se registró ganancia de XP para esta misión.")
                end
                
                found = true
                break
            end
        end
    end
    
    if not found then
        -- Si no encontramos la misión en nuestro registro, la añadimos como nueva
        local questID = GenerateQuestID(title, zone, time())
        
        self.db.account.quests[questID] = {
            questID = questID,
            title = title,
            level = UnitLevel("player"), -- Usamos el nivel del jugador como aproximación
            acceptCoords = nil, -- No sabemos dónde la aceptó
            turnInCoords = { x = x, y = y, zone = zone },
            status = "completed",
            timestamp = time(),
            completedTimestamp = time(),
            completionTime = 0, -- No sabemos cuánto tiempo llevó
            playerLevel = UnitLevel("player"),
            completionLevel = UnitLevel("player"),
            xpGained = xpGained,
        }
        
        -- Actualizar el índice por título
        self.db.account.questsByTitle[title] = self.db.account.questsByTitle[title] or {}
        table.insert(self.db.account.questsByTitle[title], questID)
        
        self:Print("Misión registrada y completada: " .. title)
        if xpGained > 0 then
            self:Print("Experiencia ganada: " .. xpGained .. " XP")
        else
            self:Print("No se registró ganancia de XP para esta misión.")
        end
    end
    
    -- Limpiar las variables
    self.lastCompletedQuest = nil
    self.questTitle = nil
    self.xpBeforeTurnIn = nil
    
    -- Actualizar la UI
    self:UpdateQuestList()
end

function QuestLog:QUEST_LOG_UPDATE()
    -- Obtener todas las misiones actuales
    local newQuestLog = {}
    for i=1, GetNumQuestLogEntries() do
        local title, _, _, isHeader = GetQuestLogTitle(i)
        if not isHeader and title then
            newQuestLog[title] = true
        end
    end
    
    -- Buscar misiones que estaban en el log pero ya no están (posiblemente abandonadas)
    for title in pairs(currentQuestLog) do
        if not newQuestLog[title] and self.db.account.questsByTitle[title] then
            -- Buscar entre las misiones con este título
            for _, questID in ipairs(self.db.account.questsByTitle[title]) do
                local quest = self.db.account.quests[questID]
                if quest and quest.status == "accepted" then
                    quest.status = "abandoned"
                    quest.abandonedTimestamp = time()
                    self:Print("Misión abandonada: " .. title)
                    self:UpdateQuestList()
                    break
                end
            end
        end
    end
    
    -- Actualizar nuestro registro del log
    currentQuestLog = newQuestLog
end

-- Devuelve una lista plana de todas las misiones
function QuestLog:GetQuestList()
    local list = {}
    for _, quest in pairs(self.db.account.quests) do
        table.insert(list, quest)
    end
    return list
end

-- Formatea un tiempo en segundos a un formato legible
function QuestLog:FormatTime(seconds)
    if not seconds or seconds <= 0 then
        return "N/A"
    end
    
    local days = math.floor(seconds / 86400)
    seconds = math.mod(seconds, 86400)
    local hours = math.floor(seconds / 3600)
    seconds = math.mod(seconds, 3600)
    local minutes = math.floor(seconds / 60)
    seconds = math.mod(seconds, 60)
    
    if days > 0 then
        return string.format("%d días, %d horas, %d minutos", days, hours, minutes)
    elseif hours > 0 then
        return string.format("%d horas, %d minutos", hours, minutes)
    elseif minutes > 0 then
        return string.format("%d minutos, %d segundos", minutes, seconds)
    else
        return string.format("%d segundos", seconds)
    end
end

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
    
    local text = colors.header .. "Misión: |r" .. quest.title .. "\n\n"
    text = text .. colors.header .. "Nivel: |r" .. quest.level .. "\n"
    text = text .. colors.header .. "Estado: |r" .. (statusText[quest.status] or "Desconocido") .. "\n"
    
    -- Mostrar nivel del jugador al aceptar y completar
    if quest.playerLevel then
        text = text .. colors.header .. "Nivel al aceptar: |r" .. quest.playerLevel .. "\n"
    end
    if quest.completionLevel then
        text = text .. colors.header .. "Nivel al completar: |r" .. quest.completionLevel .. "\n"
    end
    
    -- Mostrar XP ganada si está disponible
    if quest.xpGained and quest.xpGained > 0 then
        text = text .. colors.header .. "Experiencia ganada: |r" .. quest.xpGained .. " XP\n"
    end
    
    text = text .. "\n"
    
    if quest.acceptCoords then
        text = text .. colors.header .. "Aceptada en: |r" .. quest.acceptCoords.zone .. "\n"
        text = text .. "Coordenadas: (" .. quest.acceptCoords.x .. ", " .. quest.acceptCoords.y .. ")\n\n"
    end
    
    if quest.turnInCoords then
        text = text .. colors.header .. "Entregada en: |r" .. quest.turnInCoords.zone .. "\n"
        text = text .. "Coordenadas: (" .. quest.turnInCoords.x .. ", " .. quest.turnInCoords.y .. ")\n\n"
    end
    
    if quest.completionTime and quest.completionTime > 0 then
        text = text .. colors.header .. "Tiempo de completado: |r" .. self:FormatTime(quest.completionTime) .. "\n\n"
    end
    
    if quest.manualCoords and table.getn(quest.manualCoords) > 0 then
        text = text .. colors.header .. "Coordenadas manuales:\n|r"
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