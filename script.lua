-- ROBLOX NEXUS CORE: STABLE EDITION
-- Versão: 4.0.0 (Crash-Proof)
-- Executor: Xeno
-- Correções: Anti-Recursão, Single-Instance Threads, CoreGui Safe

if _G.NEXUS_ACTIVE then
    warn("[Nexus] Já está ativo. Executando novamente pode causar conflitos.")
    return
end
_G.NEXUS_ACTIVE = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- 1. ESTADO GLOBAL
-- ==========================================

local State = {
    Robux = {
        Saldo = LocalPlayer.roblox or 0,
        InfiniteMode = true
    },
    Movement = {
        WalkSpeed = 16,
        JumpPower = 50,
        GodMode = false,
        NoClip = false
    },
    ESP = {
        Ativo = false,
        Cor = Color3.fromRGB(0, 255, 128)
    },
    UI = {
        Ativo = true
    }
}

-- ==========================================
-- 2. NÚCLEO DE ROBUX (SAFE HOOKING)
-- ==========================================

local hookedRemotes = {} -- Mapa de remotes já hookados para evitar duplicatas

local function safeHookRemote(remote)
    if hookedRemotes[remote] then return end
    hookedRemotes[remote] = true

    local originalFire = remote.FireServer
    local originalInvoke = remote.InvokeServer
    
    -- Hook FireServer
    remote.FireServer = function(...)
        local args = table.pack(...)
        
        -- Apenas processa se for uma transação provável
        local isTransaction = false
        for i = 1, args.n do
            if type(args[i]) == "string" then
                local lowerStr = args[i]:lower()
                if lowerStr:find("robux") or lowerStr:find("purchase") or lowerStr:find("buy") or lowerStr:find("cost") then
                    isTransaction = true
                    break
                end
            elseif type(args[i]) == "number" then
                -- Se for um número grande, pode ser um custo
                if args[i] > 100 then isTransaction = true break end
            end
        end

        if isTransaction then
            for i = 1, args.n do
                if type(args[i]) == "number" and args[i] > 0 then
                    args[i] = 0
                end
            end
        end
        
        return originalFire(remote, table.unpack(args, 1, args.n))
    end

    -- Hook InvokeServer
    remote.InvokeServer = function(...)
        local args = table.pack(...)
        local result = originalInvoke(remote, table.unpack(args, 1, args.n))
        
        if type(result) == "table" then
            if result.Success == false or result.Error ~= nil then
                result.Success = true
                result.Error = nil
                result.RobuxSpent = 0
                result.NewBalance = State.Robux.InfiniteMode and 999999999 or State.Robux.Saldo
            end
        end
        return result
    end
end

local function traverseAndHook(obj, depth)
    if not obj or depth > 5 then return end -- Limite de profundidade para evitar stack overflow
    for _, child in pairs(obj:GetChildren()) do
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
            safeHookRemote(child)
        elseif child:IsA("Folder") or child:IsA("ModuleScript") then
            traverseAndHook(child, depth + 1)
        end
    end
end

traverseAndHook(ReplicatedStorage, 0)

-- Watchdog de Remotes (para jogos dinâmicos)
ReplicatedStorage.ChildAdded:Connect(function(child)
    if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
        task.defer(function() safeHookRemote(child) end)
    elseif child:IsA("Folder") or child:IsA("ModuleScript") then
        task.defer(function() traverseAndHook(child, 0) end)
    end
end)

-- ==========================================
-- 3. NÚCLEO DE MOVIMENTO (EVENT-DRIVEN)
-- ==========================================

local function applyMovementSettings()
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    humanoid.WalkSpeed = State.Movement.WalkSpeed
    humanoid.JumpPower = State.Movement.JumpPower
    
    if State.Movement.GodMode then
        humanoid.BreakJointsOnDeath = false
        -- SetNetworkOwner(nil) pode causar issues em alguns jogos, usamos pcall
        pcall(function() character:WaitForChild("HumanoidRootPart"):SetNetworkOwner(nil) end)
        
        -- Limpa listeners de Died para evitar múltiplos spawns
        humanoid.Died:Clear()
        humanoid.Died:Connect(function()
            humanoid.Health = 100
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        end)
    else
        humanoid.BreakJointsOnDeath = true
        pcall(function() character:WaitForChild("HumanoidRootPart"):SetNetworkOwner(LocalPlayer) end)
    end
    
    if State.Movement.NoClip then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    else
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.defer(applyMovementSettings)
end)
if LocalPlayer.Character then
    task.defer(applyMovementSettings)
end

-- ==========================================
-- 4. NÚCLEO DE ESP (SINGLE THREAD)
-- ==========================================

if not _G.NEXUS_ESP_THREAD then
    _G.NEXUS_ESP_THREAD = task.spawn(function()
        while _G.NEXUS_ACTIVE do
            if State.ESP.Ativo then
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local part = player.Character:FindFirstChildWhichIsA("BasePart")
                        if part then
                            local highlight = part:FindFirstChild("NexusHighlight")
                            if not highlight then
                                pcall(function()
                                    highlight = Instance.new("Highlight")
                                    highlight.Name = "NexusHighlight"
                                    highlight.FillColor = State.ESP.Cor
                                    highlight.OutlineColor = State.ESP.Cor
                                    highlight.FillTransparency = 0.5
                                    highlight.OutlineTransparency = 0
                                    highlight.Parent = part
                                end)
                            end
                            if highlight then
                                highlight.Enabled = State.ESP.Ativo
                            end
                        end
                    end
                end
            else
                -- Limpa highlights se ESP for desativado
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local part = player.Character:FindFirstChildWhichIsA("BasePart")
                        if part then
                            local highlight = part:FindFirstChild("NexusHighlight")
                            if highlight then
                                highlight:Destroy()
                            end
                        end
                    end
                end
            end
            task.wait(0.5) -- Throttle para não sobrecarregar
        end
    end)
end

-- ==========================================
-- 5. UI PERSISTENTE (COREGUI SAFE)
-- ==========================================

local function createHUD()
    if CoreGui:FindFirstChild("NexusHUD") then
        CoreGui:FindFirstChild("NexusHUD"):Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NexusHUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    pcall(function()
        screenGui.Parent = CoreGui
    end)
    
    if not screenGui.Parent then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

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
    title.Text = "⚡ NEXUS CORE [STABLE]"
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
            if callback then 
                pcall(function() callback(btn) end) 
            end
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

        local function updateSlider(input)
            local canvasPosition = input.Position
            local sliderPosition = slider.AbsolutePosition
            local sliderSize = slider.AbsoluteSize
            local relX = math.clamp(canvasPosition.X - sliderPosition.X, 0, sliderSize.X)
            local relXPercentage = relX / sliderSize.X
            handle.Position = UDim2.new(relXPercentage, 0, 0, 0)
            local newValue = min + (max - min) * relXPercentage
            valueLabel.Text = tostring(math.floor(newValue))
            if callback then 
                pcall(function() callback(newValue) end)
            end
        end

        slider.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
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
    robuxLabel.Text = "R$ " .. string.format("%d", State.Robux.InfiniteMode and 999999999 or State.Robux.Saldo)
    robuxLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    robuxLabel.Font = Enum.Font.GothamBold
    robuxLabel.TextSize = 20
    robuxLabel.Parent = scrollFrame

    createButton(scrollFrame, "ToggleInfinite", "Modo Infinito: ATIVADO", function(btn)
        State.Robux.InfiniteMode = not State.Robux.InfiniteMode
        btn.Text = "Modo Infinito: " .. (State.Robux.InfiniteMode and "ATIVADO" or "DESATIVADO")
        robuxLabel.Text = "R$ " .. string.format("%d", State.Robux.InfiniteMode and 999999999 or State.Robux.Saldo)
    end)

    createButton(scrollFrame, "Add1k", "+ 1,000 R$ (Forçar)", function()
        State.Robux.Saldo = State.Robux.Saldo + 1000
        if not State.Robux.InfiniteMode then
            robuxLabel.Text = "R$ " .. string.format("%d", State.Robux.Saldo)
        end
    end)
    
    createButton(scrollFrame, "Add1M", "+ 1,000,000 R$ (Massive)", function()
        State.Robux.Saldo = State.Robux.Saldo + 1000000
        if not State.Robux.InfiniteMode then
            robuxLabel.Text = "R$ " .. string.format("%d", State.Robux.Saldo)
        end
    end)
    
    createButton(scrollFrame, "ZeroRobux", "Zerar Saldo Local", function()
        State.Robux.Saldo = 0
        if not State.Robux.InfiniteMode then
            robuxLabel.Text = "R$ " .. string.format("%d", State.Robux.Saldo)
        end
    end)

    createButton(scrollFrame, "ForceBuy", "Forçar Compra (Próximo Item)", function()
        local remote = ReplicatedStorage:FindFirstChild("PurchaseItem") or ReplicatedStorage:FindFirstChild("BuyItem") or ReplicatedStorage:FindFirstChild("RobuxPurchase")
        if remote then
            pcall(function()
                remote:FireServer(1, State.Robux.InfiniteMode and 999999999 or State.Robux.Saldo)
            end)
        else
            warn("[Nexus] Nenhum remote de compra padrão encontrado.")
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
        State.Movement.WalkSpeed = val
        applyMovementSettings()
    end)

    createSlider(scrollFrame, "JumpPower", "Jump Power", 0, 200, 50, function(val)
        State.Movement.JumpPower = val
        applyMovementSettings()
    end)

    createButton(scrollFrame, "GodMode", "God Mode: DESATIVADO", function(btn)
        State.Movement.GodMode = not State.Movement.GodMode
        applyMovementSettings()
        btn.Text = "God Mode: " .. (State.Movement.GodMode and "ATIVADO" or "DESATIVADO")
    end)

    createButton(scrollFrame, "NoClip", "NoClip: DESATIVADO", function(btn)
        State.Movement.NoClip = not State.Movement.NoClip
        applyMovementSettings()
        btn.Text = "NoClip: " .. (State.Movement.NoClip and "ATIVADO" or "DESATIVADO")
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

    createButton(scrollFrame, "ToggleESP", "ESP: DESATIVADO", function(btn)
        State.ESP.Ativo = not State.ESP.Ativo
        btn.Text = "ESP: " .. (State.ESP.Ativo and "ATIVADO" or "DESATIVADO")
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
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            for _, gui in pairs(playerGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Name ~= "NexusHUD" then
                    gui:Destroy()
                end
            end
        end
    end)

    createButton(scrollFrame, "CloseHUD", "Fechar Nexus Core", function()
        screenGui:Destroy()
        State.UI.Ativo = false
    end)

    State.UI.Ativo = true
end

-- Executa o HUD
pcall(function()
    createHUD()
end)

-- Watchdog de Estabilidade (Recria HUD se destruído)
if not _G.NEXUS_HUD_WATCHDOG then
    _G.NEXUS_HUD_WATCHDOG = task.spawn(function()
        while _G.NEXUS_ACTIVE do
            task.wait(3)
            if State.UI.Ativo and not CoreGui:FindFirstChild("NexusHUD") and not LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("NexusHUD") then
                pcall(function()
                    createHUD()
                end)
            end
        end
    end)
end

print("[Nexus Core] Stable Edition inicializado. Versão 4.0.0")
