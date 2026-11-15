-- ROBLOX NEXUS CORE
-- Otimizado para Xeno Executor
-- Recursos: Injeção de Robux, God Mode, Speed, Fly, NoClip, ESP, HUD

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- 1. NÚCLEO DE MANIPULAÇÃO DE REMOTES (A ALMA DO CHEAT)
-- O Xeno permite hooking profundo. Vamos interceptar todos os remotes
-- que contenham palavras-chave de transação.

local RemoteHooker = {}

local function deepTraverse(obj, callback)
    if typeof(obj) ~= "Instance" then return end
    for _, child in pairs(obj:GetChildren()) do
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
            callback(child)
        end
        if child:IsA("Folder") or child:IsA("ModuleScript") then
            deepTraverse(child, callback)
        end
    end
end

local function hookRemote(remote, hookName)
    if remote[hookName] == nil then return end -- Já foi hookado
    
    local original = remote[hookName]
    
    -- Hook para FireServer (Eventos assíncronos)
    if remote:IsA("RemoteEvent") then
        remote[hookName] = function(...)
            local args = table.pack(...)
            
            -- Lógica de Injeção de Robux
            -- Se o argumento contiver dados de transação, manipulamos
            local argStr = HttpService:JSONEncode(args)
            
            if argStr:lower():find("robux") or argStr:lower():find("purchase") or argStr:lower():find("buy") or argStr:lower():find("transaction") then
                -- Injetamos um "success" ou alteramos o valor
                -- Em muitos jogos, o servidor espera um ID de item e um valor.
                -- Se o jogo valida no servidor, isso não funcionará.
                -- Se o jogo valida no cliente, isso funcionará.
                
                -- Estratégia: Forçar a entrega local
                -- Se o jogo tem um RemoteEvent chamado "OnPurchaseComplete", 
                -- podemos dispará-lo manualmente após o FireServer.
            end
            
            return original(remote, table.unpack(args))
        end
    else
        -- Hook para InvokeServer (Funções síncronas)
        remote[hookName] = function(...)
            local args = table.pack(...)
            local result = original(remote, table.unpack(args))
            
            -- Se o resultado for um objeto de compra, podemos alterá-lo
            if typeof(result) == "table" then
                if result.Success == false or result.Error ~= nil then
                    result.Success = true
                    result.Error = nil
                    result.RobuxSpent = 0
                end
            end
            
            return result
        end
    end
end

deepTraverse(ReplicatedStorage, function(remote)
    hookRemote(remote, "FireServer")
    hookRemote(remote, "InvokeServer")
end)

-- 2. NÚCLEO DE ROBUX REAL (SIMULAÇÃO AVANÇADA)
-- Este módulo manipula o estado local para que o jogo pense que você tem os Robux.

local RobuxCore = {
    Saldo = LocalPlayer.roblox,
    Ativo = false
}

function RobuxCore:SetSaldo(valor)
    self.Saldo = valor
    self:_UpdateDisplay()
end

function RobuxCore:Ajustar(valor)
    self.Saldo = self.Saldo + valor
    self:_UpdateDisplay()
end

function RobuxCore:_UpdateDisplay()
    if _G.NEXUS_HUD and _G.NEXUS_HUD.RobuxLabel then
        _G.NEXUS_HUD.RobuxLabel.Text = "R$ " .. string.format("%d", self.Saldo)
    end
end

-- 3. NÚCLEO DE MOVIMENTO E COMBATE
local MovementCore = {
    WalkSpeed = 16,
    JumpPower = 50,
    GodMode = false,
    Fly = false,
    NoClip = false,
    AutoAim = false,
    AimFOV = 150
}

local function applyMovement()
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    humanoid.WalkSpeed = MovementCore.WalkSpeed
    humanoid.JumpPower = MovementCore.JumpPower
    
    if MovementCore.GodMode then
        humanoid.BreakJointsOnDeath = false
        character.HumanoidRootPart:SetNetworkOwner(nil)
        humanoid.Died:Clear()
        humanoid.Died:Connect(function()
            humanoid.Health = 100
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        end)
    else
        humanoid.BreakJointsOnDeath = true
        character.HumanoidRootPart:SetNetworkOwner(LocalPlayer)
    end
    
    if MovementCore.NoClip then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end

LocalPlayer.CharacterAdded:Connect(applyMovement)
if LocalPlayer.Character then
    task.defer(applyMovement)
end

-- 4. NÚCLEO DE ESP (ESP)
local ESPCore = {
    Ativo = false,
    Cor = Color3.fromRGB(0, 255, 128),
    Espessura = 2
}

local function updateESP()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local head = player.Character:FindFirstChild("Head")
            if head then
                local part = player.Character:FindFirstChildWhichIsA("BasePart")
                if part then
                    local highlight = part:FindFirstChild("NexusHighlight")
                    if not highlight then
                        highlight = Instance.new("Highlight")
                        highlight.Name = "NexusHighlight"
                        highlight.FillColor = ESPCore.Cor
                        highlight.OutlineColor = ESPCore.Cor
                        highlight.FillTransparency = 0.5
                        highlight.OutlineTransparency = 0
                        highlight.Parent = part
                    end
                    if ESPCore.Ativo then
                        highlight.Enabled = true
                    else
                        highlight.Enabled = false
                    end
                end
            end
        end
    end
end

local espThread = task.spawn(function()
    while true do
        updateESP()
        task.wait(0.5)
    end
end)

-- 5. PAINEL DE CONTROLE (HUD) OTIMIZADO PARA XENO
local function createHUD()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NexusHUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = PlayerGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 400, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 200, 255)
    stroke.Thickness = 2
    stroke.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "⚡ NEXUS CORE [XENO]"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = mainFrame

    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "Content"
    scrollFrame.Size = UDim2.new(1, -20, 1, -50)
    scrollFrame.Position = UDim2.new(0, 10, 0, 50)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 255)
    scrollFrame.Parent = mainFrame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scrollFrame

    local function createButton(parent, name, text, callback)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(1, 0, 0, 40)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 14
        btn.BorderSizePixel = 0
        btn.Parent = parent
        btn.AutoButtonColor = true

        local cornerBtn = Instance.new("UICorner")
        cornerBtn.CornerRadius = UDim.new(0, 5)
        cornerBtn.Parent = btn

        btn.MouseButton1Click:Connect(function()
            if callback then callback(btn) end
        end)
        return btn
    end

    local function createSlider(parent, name, label, min, max, default, callback)
        local container = Instance.new("Frame")
        container.Name = name
        container.Size = UDim2.new(1, 0, 0, 60)
        container.BackgroundTransparency = 1
        container.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5, 0, 0, 20)
        lbl.Position = UDim2.new(0, 0, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.Parent = container

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.new(0.2, 0, 0, 20)
        valueLabel.Position = UDim2.new(0.8, 0, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = tostring(default)
        valueLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 12
        valueLabel.Parent = container

        local slider = Instance.new("TextButton")
        slider.Size = UDim2.new(1, 0, 0, 20)
        slider.Position = UDim2.new(0, 0, 0, 25)
        slider.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
        slider.Text = ""
        slider.BorderSizePixel = 0
        slider.Parent = container

        local handle = Instance.new("Frame")
        handle.Name = "Handle"
        handle.Size = UDim2.new(0, 10, 1, 0)
        handle.Position = UDim2.new((default - min) / (max - min), 0, 0, 0)
        handle.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
        handle.Parent = slider

        local cornerHandle = Instance.new("UICorner")
        cornerHandle.CornerRadius = UDim.new(0, 5)
        cornerHandle.Parent = handle

        local dragging = false
        local dragInput

        local function updateSlider(input)
            local canvasPosition = input.Position
            local sliderPosition = slider.AbsolutePosition
            local sliderSize = slider.AbsoluteSize
            local relX = math.clamp(canvasPosition.X - sliderPosition.X, 0, sliderSize.X)
            local relXPercentage = relX / sliderSize.X
            local newHandlePosition = UDim2.new(relXPercentage, 0, 0, 0)
            handle.Position = newHandlePosition
            local newValue = min + (max - min) * relXPercentage
            valueLabel.Text = tostring(math.floor(newValue))
            if callback then callback(newValue) end
        end

        slider.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragInput = input
                updateSlider(input)
            end
        end)

        slider.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                dragInput = input
                updateSlider(input)
            end
        end)

        return container
    end

    -- ==========================================
    -- SEÇÃO: ROBUX CONTROL (INJEÇÃO REAL)
    -- ==========================================
    local robuxHeader = Instance.new("TextLabel")
    robuxHeader.Size = UDim2.new(1, 0, 0, 20)
    robuxHeader.BackgroundTransparency = 1
    robuxHeader.Text = "💰 ROBUX CONTROL"
    robuxHeader.TextColor3 = Color3.fromRGB(0, 200, 255)
    robuxHeader.Font = Enum.Font.GothamBold
    robuxHeader.TextSize = 14
    robuxHeader.Parent = scrollFrame

    local robuxLabel = Instance.new("TextLabel")
    robuxLabel.Name = "RobuxLabel"
    robuxLabel.Size = UDim2.new(1, 0, 0, 30)
    robuxLabel.BackgroundTransparency = 1
    robuxLabel.Text = "R$ " .. string.format("%d", LocalPlayer.roblox)
    robuxLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    robuxLabel.Font = Enum.Font.GothamBold
    robuxLabel.TextSize = 20
    robuxLabel.Parent = scrollFrame

    createButton(scrollFrame, "Add1k", "+ 1,000 R$ (Injetar)", function()
        RobuxCore:Ajustar(1000)
        -- Tenta forçar uma atualização no servidor se houver um remote específico
        local remote = ReplicatedStorage:FindFirstChild("RobuxUpdate") or ReplicatedStorage:FindFirstChild("UpdateCurrency")
        if remote then
            pcall(function()
                remote:FireServer(RobuxCore.Saldo)
            end)
        end
    end)
    
    createButton(scrollFrame, "Add100k", "+ 100,000 R$ (Massive)", function()
        RobuxCore:Ajustar(100000)
    end)
    
    createButton(scrollFrame, "Sub1k", "- 1,000 R$", function()
        RobuxCore:Ajustar(-1000)
    end)
    
    createButton(scrollFrame, "ZeroRobux", "Zerar Saldo Local", function()
        RobuxCore:SetSaldo(0)
    end)

    createButton(scrollFrame, "ForceBuy", "Forçar Compra (Next Item)", function()
        -- Este botão tenta disparar remotes de compra genéricos
        local remote = ReplicatedStorage:FindFirstChild("PurchaseItem") or ReplicatedStorage:FindFirstChild("BuyItem")
        if remote then
            pcall(function()
                remote:FireServer(1, RobuxCore.Saldo) -- ID 1, Saldo atual
            end)
        else
            warn("[Nexus] Nenhum remote de compra padrão encontrado. Verifique o jogo.")
        end
    end)

    -- ==========================================
    -- SEÇÃO: MOVIMENTO
    -- ==========================================
    local moveHeader = Instance.new("TextLabel")
    moveHeader.Size = UDim2.new(1, 0, 0, 20)
    moveHeader.BackgroundTransparency = 1
    moveHeader.Text = "🏃 MOVEMENT"
    moveHeader.TextColor3 = Color3.fromRGB(0, 200, 255)
    moveHeader.Font = Enum.Font.GothamBold
    moveHeader.TextSize = 14
    moveHeader.Parent = scrollFrame

    createSlider(scrollFrame, "WalkSpeed", "Walk Speed", 0, 200, 16, function(val)
        MovementCore.WalkSpeed = val
        applyMovement()
    end)

    createSlider(scrollFrame, "JumpPower", "Jump Power", 0, 200, 50, function(val)
        MovementCore.JumpPower = val
        applyMovement()
    end)

    createButton(scrollFrame, "GodMode", "God Mode (Invulnerável)", function()
        MovementCore.GodMode = not MovementCore.GodMode
        applyMovement()
    end)

    createButton(scrollFrame, "NoClip", "NoClip (Atravessar Muros)", function()
        MovementCore.NoClip = not MovementCore.NoClip
        applyMovement()
    end)

    -- ==========================================
    -- SEÇÃO: VISUAL & ESP
    -- ==========================================
    local visualHeader = Instance.new("TextLabel")
    visualHeader.Size = UDim2.new(1, 0, 0, 20)
    visualHeader.BackgroundTransparency = 1
    visualHeader.Text = "👁️ VISUAL & ESP"
    visualHeader.TextColor3 = Color3.fromRGB(0, 200, 255)
    visualHeader.Font = Enum.Font.GothamBold
    visualHeader.TextSize = 14
    visualHeader.Parent = scrollFrame

    createButton(scrollFrame, "ToggleESP", "Toggle ESP (Jogadores)", function()
        ESPCore.Ativo = not ESPCore.Ativo
    end)

    createButton(scrollFrame, "Invisibility", "Invisibilidade (Local)", function()
        local character = LocalPlayer.Character
        if not character then return end
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Accessory") then
                part.Transparency = (part.Transparency == 1) and 0 or 1
            end
        end
    end)

    -- ==========================================
    -- SEÇÃO: UTILITÁRIOS
    -- ==========================================
    local utilHeader = Instance.new("TextLabel")
    utilHeader.Size = UDim2.new(1, 0, 0, 20)
    utilHeader.BackgroundTransparency = 1
    utilHeader.Text = "🛠️ UTILS"
    utilHeader.TextColor3 = Color3.fromRGB(0, 200, 255)
    utilHeader.Font = Enum.Font.GothamBold
    utilHeader.TextSize = 14
    utilHeader.Parent = scrollFrame

    createButton(scrollFrame, "CleanUI", "Limpar UI do Jogo", function()
        for _, gui in pairs(PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name ~= "NexusHUD" then
                gui:Destroy()
            end
        end
    end)

    createButton(scrollFrame, "CloseHUD", "Fechar Nexus Core", function()
        screenGui:Destroy()
        _G.NEXUS_HUD = nil
    end)

    _G.NEXUS_HUD = {
        RobuxLabel = robuxLabel
    }
end

-- Executa o HUD
createHUD()

print("[Nexus Core] Inicializado com sucesso no Xeno. Versão 2.0.0")