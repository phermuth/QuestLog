-- Core.lua
-- Parte central del addon QuestLog

QuestLog = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceEvent-2.0", "AceHook-2.1")

-- Variables globales para seguimiento de XP
QuestLog.lastQuestXP = 0
QuestLog.lastPlayerLevel = 0

-- Inicialización de variables
local defaults = {
    quests = {}, -- Lista de todas las misiones (ahora indexadas por ID único)
    questsByTitle = {}, -- Índice secundario para buscar misiones por título
    questOrder = {}, -- Nueva estructura para almacenar el orden personalizado de las misiones
}

-- Colores para los diferentes estados de las misiones (modificar existente)
QuestLog.colors = {
    accepted = "|cFFFFFFFF", -- Blanco
    completed = "|cFF00FF00", -- Verde
    abandoned = "|cFFFF0000", -- Rojo
    header = "|cFFFFD100",    -- Dorado/Amarillo
    objectives_complete = "|cFF00FFFF", -- Cian (nuevo estado para objetivos completados)
}

-- Llevar un seguimiento de las misiones en el log para detectar abandonos
QuestLog.currentQuestLog = {}

-- Función para generar ID único para una misión
function QuestLog:GenerateQuestID(title, zone, timestamp)
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
                local questID = self:GenerateQuestID(title, zone, timestamp)
                
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

-- En el método OnEnable, asegurarse de inicializar las variables de XP
function QuestLog:OnEnable()
    -- Código original de OnEnable
    self:RegisterEvent("QUEST_ACCEPTED")
    self:RegisterEvent("QUEST_COMPLETE")
    self:RegisterEvent("QUEST_FINISHED")
    self:RegisterEvent("QUEST_LOG_UPDATE")
    
    -- Hooks originales
    self:Hook("AcceptQuest", true)
    self:Hook("CompleteQuest", true)
    
    -- Inicializar seguimiento de XP
    self.lastQuestXP = UnitXP("player")
    self.lastPlayerLevel = UnitLevel("player")
    
    -- Mensaje de inicialización
    self:Print("QuestLog cargado. Usa /qlog para mostrar la bitácora de misiones.")
end

function QuestLog:OnDisable()
    -- Desregistrar eventos
    self:UnregisterAllEvents()
    self:UnhookAll()
end

-- Devuelve una lista plana de todas las misiones
-- GetQuestList modificada para respetar el orden personalizado
function QuestLog:GetQuestList()
    local list = {}
    
    -- Si existe un orden personalizado, lo usamos
    if self.db.account.questOrder and next(self.db.account.questOrder) then
        -- Primero agregamos las misiones en el orden personalizado
        for _, questID in ipairs(self.db.account.questOrder) do
            if self.db.account.quests[questID] then
                table.insert(list, self.db.account.quests[questID])
            end
        end
        
        -- Luego agregamos cualquier misión que no esté en el orden personalizado
        for questID, quest in pairs(self.db.account.quests) do
            local found = false
            for _, orderedID in ipairs(self.db.account.questOrder) do
                if orderedID == questID then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(list, quest)
            end
        end
    else
        -- Si no hay orden personalizado, solo agregamos todas las misiones
        for _, quest in pairs(self.db.account.quests) do
            table.insert(list, quest)
        end
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

-- Nueva función para mover una misión hacia arriba en la lista ordenada
function QuestLog:MoveQuestUp(questID)
    if not self.db.account.questOrder then
        self.db.account.questOrder = {}
        -- Inicializar el orden con el orden actual basado en timestamp
        local quests = {}
        for id, quest in pairs(self.db.account.quests) do
            table.insert(quests, {id = id, timestamp = quest.timestamp or 0})
        end
        table.sort(quests, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
        for _, quest in ipairs(quests) do
            table.insert(self.db.account.questOrder, quest.id)
        end
    end
    
    -- Encontrar el índice actual de la misión
    local currentIndex = 0
    for i, id in ipairs(self.db.account.questOrder) do
        if id == questID then
            currentIndex = i
            break
        end
    end
    
    -- Si no está en la lista ordenada o ya está en la parte superior, añadirla
    if currentIndex <= 1 then
        if currentIndex == 0 then
            table.insert(self.db.account.questOrder, 1, questID)
        end
        return
    end
    
    -- Intercambiar con la misión anterior
    local tempID = self.db.account.questOrder[currentIndex-1]
    self.db.account.questOrder[currentIndex-1] = questID
    self.db.account.questOrder[currentIndex] = tempID
    
    -- Actualizar la UI
    self:UpdateQuestList()
end

-- Nueva función para mover una misión hacia abajo en la lista ordenada
function QuestLog:MoveQuestDown(questID)
    if not self.db.account.questOrder then
        self.db.account.questOrder = {}
        -- Inicializar el orden con el orden actual basado en timestamp
        local quests = {}
        for id, quest in pairs(self.db.account.quests) do
            table.insert(quests, {id = id, timestamp = quest.timestamp or 0})
        end
        table.sort(quests, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
        for _, quest in ipairs(quests) do
            table.insert(self.db.account.questOrder, quest.id)
        end
    end
    
    -- Encontrar el índice actual de la misión
    local currentIndex = 0
    for i, id in ipairs(self.db.account.questOrder) do
        if id == questID then
            currentIndex = i
            break
        end
    end
    
    -- Si no está en la lista ordenada o ya está en la parte inferior, añadirla al final
    if currentIndex == 0 then
        table.insert(self.db.account.questOrder, questID)
        return
    elseif currentIndex == table.getn(self.db.account.questOrder) then
        return
    end
    
    -- Intercambiar con la misión siguiente
    local tempID = self.db.account.questOrder[currentIndex+1]
    self.db.account.questOrder[currentIndex+1] = questID
    self.db.account.questOrder[currentIndex] = tempID
    
    -- Actualizar la UI
    self:UpdateQuestList()
end

-- Mejora 5: Añadir la función MoveQuestToTop si no la has añadido ya
-- Ubicación: Core.lua, después de las funciones MoveQuestUp/MoveQuestDown

function QuestLog:MoveQuestToTop(questID)
    if not self.db.account.questOrder then
        self.db.account.questOrder = {}
        -- Inicializar el orden con el orden actual basado en timestamp
        local quests = {}
        for id, quest in pairs(self.db.account.quests) do
            table.insert(quests, {id = id, timestamp = quest.timestamp or 0})
        end
        table.sort(quests, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
        for _, quest in ipairs(quests) do
            table.insert(self.db.account.questOrder, quest.id)
        end
    end
    
    -- Encontrar el índice actual de la misión
    local currentIndex = 0
    for i, id in ipairs(self.db.account.questOrder) do
        if id == questID then
            currentIndex = i
            break
        end
    end
    
    -- Si ya está al principio, no hacer nada
    if currentIndex <= 1 then
        if currentIndex == 0 then
            table.insert(self.db.account.questOrder, 1, questID)
        end
        return
    end
    
    -- Quitar de su posición actual
    table.remove(self.db.account.questOrder, currentIndex)
    
    -- Añadir al principio
    table.insert(self.db.account.questOrder, 1, questID)
    
    -- No es necesario actualizar la UI aquí, se hará después
end