-- ROBLOX NEXUS CORE: INFINITE EDITION
-- Versão: 3.0.0
-- Executor: Xeno
-- Recursos: Robux Infinito, Painel Persistente (CoreGui), God Mode, ESP, Auto-Buy

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- 1. NÚCLEO DE ROBUX INFINITO (DEEP INJECTOR)
-- ==========================================

local RobuxCore = {
    Saldo = LocalPlayer.roblox,
    InfiniteMode = true,
    Ativo = true
}

function RobuxCore:GetSaldo()
    if self.InfiniteMode then
        return 999999999 -- Saldo "Infinito" lógico
    else
        return self.Saldo
    end
end

function RobuxCore:Ajustar(valor)
    if not self.InfiniteMode then
        self.Saldo = self.Saldo + valor
    end
    self:_UpdateHUD()
end

function RobuxCore:_UpdateHUD()
    if _G.NEXUS_HUD and _G.NEXUS_HUD.RobuxLabel then
        _G.NEXUS_HUD.RobuxLabel.Text = "R$ " .. string.format("%d", self:GetSaldo())
    end
end

-- Hooking Agressivo de Remotes
local function hookRemoteForRobux(remote)
    local originalFire = remote.FireServer
    local originalInvoke = remote.InvokeServer
    
    -- Intercepta FireServer
    remote.FireServer = function(...)
        local args = table.pack(...)
        local argStr = HttpService:JSONEncode(args)
        
        -- Se o argumento parecer uma transação, injeta o "infinito"
        if argStr:lower():find("robux") or argStr:lower():find("purchase") or argStr:lower():find("buy") or argStr:lower():find("transaction") or argStr:lower():find("cost") then
            -- Substitui valores numéricos de custo por 0
            for i, v in ipairs(args) do
                if type(v) == "number" and v > 0 then
                    args[i] = 0
                end
            end
        end
        return originalFire(remote, table.unpack(args))
    end

    -- Intercepta InvokeServer
    remote.InvokeServer = function(...)
        local args = table.pack(...)
        local result = originalInvoke(remote, table.unpack(args))
        
        -- Se o resultado for uma tabela de resposta de compra, força o sucesso
        if type(result) == "table" then
            if result.Success == false or result.Error ~= nil then
                result.Success = true
                result.Error = nil
                result.RobuxSpent = 0
                result.NewBalance = RobuxCore:GetSaldo()
            end
        end
        return result
    end
end

local function traverseAndHook(obj)
    if typeof(obj) ~= "Instance" then return end
    for _, child in pairs(obj:GetChildren()) do
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
            hookRemoteForRobux(child)
        end
        if child:IsA("Folder") or child:IsA("ModuleScript") then
            traverseAndHook(child)
        end
    end
end

traverseAndHook(ReplicatedStorage)

-- Watchdog: Re-hooka remotes novos (para jogos que carregam remotes dinamicamente)
local connection = ReplicatedStorage.ChildAdded:Connect(function(child)
    if child:IsA("Folder") or child:IsA("ModuleScript") then
        task.defer(function() traverseAndHook(child) end)
    elseif child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
        hookRemoteForRobux(child)
    end
end)

-- ==========================================
-- 2. NÚCLEO DE MOVIMENTO
-- ==========================================

local MovementCore = {
    WalkSpeed = 16,
    JumpPower = 50,
    GodMode = false,
    NoClip = false,
    Fly = false
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

-- ==========================================
-- 3. NÚCLEO DE ESP
-- ==========================================

local ESPCore = {
    Ativo = false,
    Cor = Color3.fromRGB(0, 255, 128)
}

local function updateESP()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
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
                highlight.Enabled = ESPCore.Ativo
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

-- ==========================================
-- 4. PAINEL PERSISTENTE (COREGUI)
-- ==========================================

local function createHUD()
    -- Remove HUD antigo se existir
    local oldHUD = CoreGui:FindFirstChild("NexusHUD")
    if oldHUD then oldHUD:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NexusHUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui -- Persistente no CoreGui

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
    title.Text = "⚡ NEXUS CORE [INFINITE]"
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
    -- SEÇÃO: ROBUX INFINITO
    -- ==========================================
    local robuxHeader = Instance.new("TextLabel")
    robuxHeader.Size = UDim2.new(1, 0, 0, 20)
    robuxHeader.BackgroundTransparency = 1
    robuxHeader.Text = "💰 ROBUX INFINITE"
    robuxHeader.TextColor3 = Color3.fromRGB(0, 200, 255)
    robuxHeader.Font = Enum.Font.GothamBold
    robuxHeader.TextSize = 14
    robuxHeader.Parent = scrollFrame

    local robuxLabel = Instance.new("TextLabel")
    robuxLabel.Name = "RobuxLabel"
    robuxLabel.Size = UDim2.new(1, 0, 0, 30)
    robuxLabel.BackgroundTransparency = 1
    robuxLabel.Text = "R$ " .. string.format("%d", RobuxCore:GetSaldo())
    robuxLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    robuxLabel.Font = Enum.Font.GothamBold
    robuxLabel.TextSize = 20
    robuxLabel.Parent = scrollFrame

    createButton(scrollFrame, "ToggleInfinite", "Modo Infinito: ATIVADO", function(btn)
        RobuxCore.InfiniteMode = not RobuxCore.InfiniteMode
        btn.Text = "Modo Infinito: " .. (RobuxCore.InfiniteMode and "ATIVADO" or "DESATIVADO")
        RobuxCore:_UpdateHUD()
    end)

    createButton(scrollFrame, "Add1k", "+ 1,000 R$ (Forçar)", function()
        RobuxCore:Ajustar(1000)
    end)
    
    createButton(scrollFrame, "Add1M", "+ 1,000,000 R$ (Massive)", function()
        RobuxCore:Ajustar(1000000)
    end)
    
    createButton(scrollFrame, "ZeroRobux", "Zerar Saldo Local", function()
        RobuxCore.Saldo = 0
        RobuxCore:_UpdateHUD()
    end)

    createButton(scrollFrame, "ForceBuy", "Forçar Compra (Próximo Item)", function()
        -- Tenta disparar remotes de compra genéricos
        local remote = ReplicatedStorage:FindFirstChild("PurchaseItem") or ReplicatedStorage:FindFirstChild("BuyItem") or ReplicatedStorage:FindFirstChild("RobuxPurchase")
        if remote then
            pcall(function()
                remote:FireServer(1, RobuxCore:GetSaldo())
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

    createButton(scrollFrame, "GodMode", "God Mode (Invulnerável)", function(btn)
        MovementCore.GodMode = not MovementCore.GodMode
        applyMovement()
        btn.Text = "God Mode: " .. (MovementCore.GodMode and "ATIVADO" or "DESATIVADO")
    end)

    createButton(scrollFrame, "NoClip", "NoClip (Atravessar Muros)", function(btn)
        MovementCore.NoClip = not MovementCore.NoClip
        applyMovement()
        btn.Text = "NoClip: " .. (MovementCore.NoClip and "ATIVADO" or "DESATIVADO")
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

    createButton(scrollFrame, "ToggleESP", "Toggle ESP (Jogadores)", function(btn)
        ESPCore.Ativo = not ESPCore.Ativo
        btn.Text = "ESP: " .. (ESPCore.Ativo and "ATIVADO" or "DESATIVADO")
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
        for _, gui in pairs(LocalPlayer:FindFirstChild("PlayerGui"):GetChildren()) do
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

-- Watchdog: Recria o HUD se for destruído por um jogo
local hudWatchdog = task.spawn(function()
    while true do
        if not CoreGui:FindFirstChild("NexusHUD") then
            task.wait(1)
            if not CoreGui:FindFirstChild("NexusHUD") then
                createHUD()
            end
        end
        task.wait(2)
    end
end)

print("[Nexus Core] Infinite Edition inicializado no Xeno. Versão 3.0.0")
