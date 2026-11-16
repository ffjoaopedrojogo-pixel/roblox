
-- Luau | LocalScript
-- Roblox Studio | StarterPlayerScripts
-- Captura de prompts de compra na experiência e exibe os itens.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local currentItem = nil
local requestId = 0

local gui = Instance.new("ScreenGui")
gui.Name = "ItemPurchaseMonitor"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(280, 245)
main.Position = UDim2.new(0, 25, 0.35, 0)
main.BackgroundColor3 = Color3.fromRGB(8, 19, 29)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 9)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 190, 180)
stroke.Thickness = 1.5
stroke.Parent = main

local function label(text, position, size, color, fontSize)
    local obj = Instance.new("TextLabel")
    obj.Position = position
    obj.Size = size
    obj.BackgroundTransparency = 1
    obj.Text = text
    obj.TextColor3 = color
    obj.TextSize = fontSize
    obj.Font = Enum.Font.GothamBold
    obj.TextWrapped = true
    obj.Parent = main
    return obj
end

label(
    "ITEM PURCHASE MONITOR",
    UDim2.fromOffset(10, 9),
    UDim2.new(1, -20, 0, 25),
    Color3.fromRGB(0, 220, 200),
    15
)

label(
    "MONITORAMENTO DE COMPRAS",
    UDim2.fromOffset(10, 34),
    UDim2.new(1, -20, 0, 17),
    Color3.fromRGB(120, 155, 170),
    10
)

local itemName = label(
    "Aguardando item...",
    UDim2.fromOffset(12, 66),
    UDim2.new(1, -24, 0, 35),
    Color3.fromRGB(255, 255, 255),
    14
)

local itemPrice = label(
    "Preço: --",
    UDim2.fromOffset(12, 105),
    UDim2.new(1, -24, 0, 23),
    Color3.fromRGB(0, 220, 170),
    13
)

local itemId = label(
    "ID: --",
    UDim2.fromOffset(12, 131),
    UDim2.new(1, -24, 0, 20),
    Color3.fromRGB(155, 175, 190),
    11
)

local status = label(
    "STATUS: AGUARDANDO",
    UDim2.fromOffset(12, 158),
    UDim2.new(1, -24, 0, 24),
    Color3.fromRGB(255, 210, 90),
    11
)

local apply = Instance.new("TextButton")
apply.Position = UDim2.fromOffset(12, 194)
apply.Size = UDim2.new(1, -24, 0, 36)
apply.BackgroundColor3 = Color3.fromRGB(0, 125, 120)
apply.Text = "ATUALIZAR ITEM"
apply.TextColor3 = Color3.new(1, 1, 1)
apply.Font = Enum.Font.GothamBold
apply.TextSize = 12
apply.Parent = main

local applyCorner = Instance.new("UICorner")
applyCorner.CornerRadius = UDim.new(0, 6)
applyCorner.Parent = apply

local function loadItem(assetId)
    requestId += 1
    local thisRequest = requestId

    currentItem = assetId
    itemId.Text = "ID: " .. tostring(assetId)
    itemName.Text = "Consultando produto..."
    itemPrice.Text = "Preço: consultando..."
    status.Text = "STATUS: CONSULTANDO"

    task.spawn(function()
        local success, info = pcall(function()
            return MarketplaceService:GetProductInfo(
                assetId,
                Enum.InfoType.Asset
            )
        end)

        if thisRequest ~= requestId then
            return
        end

        if success and info then
            itemName.Text = info.Name or "Item sem nome"

            if info.PriceInRobux then
                itemPrice.Text =
                    "Preço: " .. tostring(info.PriceInRobux) .. " Robux"
            else
                itemPrice.Text = "Preço: indisponível"
            end

            status.Text = "STATUS: ITEM IDENTIFICADO"
            status.TextColor3 = Color3.fromRGB(80, 255, 160)
        else
            itemName.Text = "Não foi possível identificar"
            itemPrice.Text = "Preço: indisponível"
            status.Text = "STATUS: ERRO NA CONSULTA"
            status.TextColor3 = Color3.fromRGB(255, 90, 90)
        end
    end)
end

-- Recebe o fechamento de prompts de compra de assets
-- na experiência, quando o evento estiver disponível no cliente.
MarketplaceService.PromptPurchaseFinished:Connect(
    function(who, assetId, purchased)
        if typeof(who) == "Instance" and who ~= player then
            return
        end

        loadItem(assetId)

        if purchased then
            status.Text = "STATUS: COMPRA CONCLUÍDA"
        else
            status.Text = "STATUS: COMPRA CANCELADA"
        end
    end
)

apply.Activated:Connect(function()
    if currentItem then
        loadItem(currentItem)
    else
        status.Text = "STATUS: NENHUM ITEM RECEBIDO"
    end
end)

print("[Item Purchase Monitor] Inicializado.")
