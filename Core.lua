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
}

-- Colores para los diferentes estados de las misiones
QuestLog.colors = {
    accepted = "|cFFFFFFFF", -- Blanco
    completed = "|cFF00FF00", -- Verde
    abandoned = "|cFFFF0000", -- Rojo
    header = "|cFFFFD100",    -- Dorado/Amarillo
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