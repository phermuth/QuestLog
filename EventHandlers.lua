-- EventHandlers.lua
-- Manejo de eventos de WoW para QuestLog

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

function QuestLog:CaptureQuestXP()
    -- Intentar capturar la XP de la misión de múltiples formas
    local currentLevel = UnitLevel("player")
    local currentXP = UnitXP("player")
    local xpToNextLevel = UnitXPMax("player")
    
    local xpGained = 0
    
    -- Método 1: Si cambia el nivel
    if currentLevel > self.lastPlayerLevel then
        -- Calcular XP basada en el cambio de nivel
        xpGained = xpToNextLevel - (self.lastQuestXP or 0) + currentXP
        self:Print(string.format("Subiste de nivel. XP calculada: %d", xpGained))
    else
        -- Método 2: Comparación directa de XP
        if currentXP > (self.lastQuestXP or 0) then
            xpGained = currentXP - (self.lastQuestXP or 0)
            self:Print(string.format("XP ganada directamente: %d", xpGained))
        end
    end
    
    -- Actualizar seguimiento de XP
    self.lastQuestXP = currentXP
    self.lastPlayerLevel = currentLevel
    
    return xpGained
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
    local questID = self:GenerateQuestID(title, zone, time())
    
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
    -- Este método se llama cuando se muestra la ventana de misión completada
    local title = GetTitleText()
    if not title then
        self:Print("Error: No se pudo obtener el título de la misión completada")
        return
    end
    
    -- Capturar XP antes de entregar la misión
    self.lastQuestXP = UnitXP("player")
    self.xpBeforeTurnIn = self.lastQuestXP
    
    self.lastCompletedQuest = title
    self:Print("Misión lista para entregar: " .. title)
end

function QuestLog:QUEST_FINISHED()
    local title = self.lastCompletedQuest
    if not title then 
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
    
    -- Intentar capturar la XP de la misión
    local xpGained = self:CaptureQuestXP()
    
    -- Obtener el nivel actual del jugador
    local playerLevel = UnitLevel("player")
    
    -- Buscar si tenemos esta misión en nuestra base de datos
    local found = false
    if self.db.account.questsByTitle[title] then
        for _, questID in ipairs(self.db.account.questsByTitle[title]) do
            local quest = self.db.account.quests[questID]
            if quest and quest.status == "accepted" then
                quest.turnInCoords = { x = x, y = y, zone = zone }
                quest.status = "completed"
                quest.completedTimestamp = time()
                quest.completionTime = quest.completedTimestamp - quest.timestamp
                quest.completionLevel = playerLevel
                quest.xpGained = xpGained
                
                self:Print("Misión completada: " .. title .. " en " .. zone .. " (" .. x .. ", " .. y .. ")")
                self:Print("Tiempo de completado: " .. self:FormatTime(quest.completionTime))
                if xpGained > 0 then
                    self:Print("Experiencia ganada: " .. xpGained .. " XP")
                else
                    self:Print("No se pudo calcular la ganancia de XP para esta misión.")
                end
                
                found = true
                break
            end
        end
    end
    
    if not found then
        -- Si no encontramos la misión en nuestro registro, la añadimos como nueva
        local questID = self:GenerateQuestID(title, zone, time())
        
        self.db.account.quests[questID] = {
            questID = questID,
            title = title,
            level = playerLevel,
            acceptCoords = nil,
            turnInCoords = { x = x, y = y, zone = zone },
            status = "completed",
            timestamp = time(),
            completedTimestamp = time(),
            completionTime = 0,
            playerLevel = playerLevel,
            completionLevel = playerLevel,
            xpGained = xpGained,
        }
        
        -- Actualizar el índice por título
        self.db.account.questsByTitle[title] = self.db.account.questsByTitle[title] or {}
        table.insert(self.db.account.questsByTitle[title], questID)
        
        self:Print("Misión registrada y completada: " .. title)
        if xpGained > 0 then
            self:Print("Experiencia ganada: " .. xpGained .. " XP")
        else
            self:Print("No se pudo calcular la ganancia de XP para esta misión.")
        end
    end
    
    -- Limpiar variables
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
    for title in pairs(self.currentQuestLog) do
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
    self.currentQuestLog = newQuestLog
end