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
    if not self.db.account.questOrder then
        self.db.account.questOrder = {}
    end
    
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
    
    -- IMPORTANTE: Poner la nueva misión al principio del orden personalizado
    table.insert(self.db.account.questOrder, 1, questID)
    
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
    
    -- Obtener coordenadas actuales en la entrega (IMPORTANTE: agregado nuevo)
    local x, y = GetPlayerMapPosition("player")
    x = math.floor(x * 10000) / 100
    y = math.floor(y * 10000) / 100
    local zone = GetZoneText()
    self.lastTurnInCoords = { x = x, y = y, zone = zone }
    
    self.lastCompletedQuest = title
    self:Print("Misión lista para entregar: " .. title)
    
    -- Guardar el nivel del jugador en el momento de completar (antes de entregar)
    self.completionPlayerLevel = UnitLevel("player")
end

-- Modificar QUEST_FINISHED para preservar las coordenadas de objetivos completados
-- Esta función se encuentra en EventHandlers.lua
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
    
    -- Obtener el nivel actual del jugador (nivel de entrega)
    local playerLevel = UnitLevel("player")
    
    -- Buscar si tenemos esta misión en nuestra base de datos
    local found = false
    if self.db.account.questsByTitle[title] then
        for _, questID in ipairs(self.db.account.questsByTitle[title]) do
            local quest = self.db.account.quests[questID]
            if quest and quest.status == "accepted" then
                -- Guardar las coordenadas de entrega
                quest.turnInCoords = { x = x, y = y, zone = zone }
                quest.status = "completed"
                quest.completedTimestamp = time()
                quest.turnInTimestamp = time()  -- Nueva propiedad para diferenciar
                
                -- Conservar la información de objetivos completados
                quest.completionTime = quest.completedTimestamp - quest.timestamp
                
                -- Usar el nivel capturado en QUEST_COMPLETE si está disponible
                quest.completionLevel = self.completionPlayerLevel or playerLevel
                quest.turnInLevel = playerLevel
                quest.xpGained = xpGained
                
                -- Mover esta misión al principio del orden personalizado
                self:MoveQuestToTop(questID)
                
                -- Mostrar mensajes informativos
                self:Print("Misión entregada: " .. title .. " en " .. zone .. " (" .. x .. ", " .. y .. ")")
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
            turnInTimestamp = time(),  -- Nueva propiedad para diferenciar
            completionTime = 0,
            playerLevel = playerLevel,   -- En este caso, no conocemos el nivel de aceptación real
            completionLevel = playerLevel, -- Asumimos que fue completada al mismo nivel
            turnInLevel = playerLevel,
            xpGained = xpGained,
        }
        
        -- Actualizar el índice por título
        self.db.account.questsByTitle[title] = self.db.account.questsByTitle[title] or {}
        table.insert(self.db.account.questsByTitle[title], questID)
        
        -- Añadir al orden personalizado al principio
        if self.db.account.questOrder then
            table.insert(self.db.account.questOrder, 1, questID)
        end
        
        self:Print("Misión registrada y entregada: " .. title)
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
    self.completionPlayerLevel = nil
    self.lastTurnInCoords = nil
    
    -- Actualizar la UI
    self:UpdateQuestList()
end

-- Esta nueva implementación rastreará con precisión cuándo cambia el estado de completado
-- Esta parte mejora la función QUEST_LOG_UPDATE para detectar misiones completadas con mayor precisión

function QuestLog:QUEST_LOG_UPDATE()
    local shouldUpdateUI = false
    
    -- Guardar el estado actual de todas las misiones del log
    local newQuestLog = {}
    local currentQuestStates = {}
    
    for i=1, GetNumQuestLogEntries() do
        local title, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
        if not isHeader and title then
            newQuestLog[title] = true
            -- Guardar el estado actual de la misión (0 = en progreso, 1 = objetivos completados)
            currentQuestStates[title] = isComplete
            
            -- Si no tenemos un cache previo para esta misión, inicializar
            if self.questStateCache[title] == nil then
                self.questStateCache[title] = isComplete
            end
            
            -- Detectar si la misión acaba de completar sus objetivos
            if isComplete == 1 and self.questStateCache[title] == 0 then
                -- ¡Los objetivos acaban de completarse!
                self:Print("¡Los objetivos de la misión " .. title .. " se han completado!")
                
                -- Encontrar esta misión en nuestra base de datos
                if self.db.account.questsByTitle[title] then
                    for _, questID in ipairs(self.db.account.questsByTitle[title]) do
                        local quest = self.db.account.quests[questID]
                        if quest and quest.status == "accepted" and (not quest.objectivesCompleted) then
                            -- Obtener coordenadas actuales
                            local x, y = GetPlayerMapPosition("player")
                            x = math.floor(x * 10000) / 100
                            y = math.floor(y * 10000) / 100
                            local zone = GetZoneText()
                            
                            -- Actualizar estado y guardar coordenadas de completado
                            quest.objectivesCompleted = true
                            quest.objectivesCompletedTimestamp = time()
                            quest.objectivesCompletedCoords = { x = x, y = y, zone = zone }
                            
                            -- Mover al principio de la lista
                            self:MoveQuestToTop(questID)
                            
                            self:Print("Objetivos completados en: " .. zone .. " (" .. x .. ", " .. y .. ")")
                            shouldUpdateUI = true
                            break
                        end
                    end
                end
            end
            
            -- Actualizar nuestro cache con el estado actual
            self.questStateCache[title] = isComplete
        end
    end
    
    -- Limpiar misiones que ya no están en el log del cache
    for title in pairs(self.questStateCache) do
        if not currentQuestStates[title] then
            self.questStateCache[title] = nil
        end
    end
    
    -- Detectar misiones abandonadas
    for title in pairs(self.currentQuestLog) do
        if not newQuestLog[title] and self.db.account.questsByTitle[title] then
            -- Buscar entre las misiones con este título
            for _, questID in ipairs(self.db.account.questsByTitle[title]) do
                local quest = self.db.account.quests[questID]
                if quest and quest.status == "accepted" then
                    quest.status = "abandoned"
                    quest.abandonedTimestamp = time()
                    quest.abandonLevel = UnitLevel("player")
                    self:Print("Misión abandonada: " .. title)
                    shouldUpdateUI = true
                    break
                end
            end
        end
    end
    
    -- Actualizar nuestro registro del log
    self.currentQuestLog = newQuestLog
    
    -- Actualizar la UI solo si es necesario
    if shouldUpdateUI then
        self:UpdateQuestList()
    end
end