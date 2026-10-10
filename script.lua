--[[
    POP IT TRADING | ITEM BUYER V2.1

    Game: Pop It Trading
    PlaceId: 7346416636

    Features:
    - Dark Mode
    - Item Scanner
    - Search
    - Item Selection
    - Price Detection
    - Buy Button
    - Auto Buy
    - Refresh
    - Mobile Support
    - Dragging
    - Notifications
]]

--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local Config = {
    GameId = 7346416636,
    AutoBuyDelay = 2,
    MinDelay = 1,
    MaxDelay = 10
}

--------------------------------------------------
-- GAME CHECK
--------------------------------------------------

if game.PlaceId ~= Config.GameId then
    warn("[POP IT BUYER] Wrong game!")
    return
end

--------------------------------------------------
-- CLEANUP
--------------------------------------------------

local Environment = getgenv and getgenv()

if Environment and Environment.PopItBuyerStop then
    Environment.PopItBuyerStop()
end

local OldGui = PlayerGui:FindFirstChild("PopItBuyerV21")

if OldGui then
    OldGui:Destroy()
end

--------------------------------------------------
-- STATE
--------------------------------------------------

local Running = true
local AutoBuy = false
local Buying = false

local Items = {}
local Selected = nil

local LastBuy = 0

if Environment then
    Environment.PopItBuyerStop = function()
        Running = false
        AutoBuy = false
    end
end

--------------------------------------------------
-- COLORS
--------------------------------------------------

local C = {
    BG = Color3.fromRGB(18, 19, 28),
    Panel = Color3.fromRGB(29, 31, 44),
    Button = Color3.fromRGB(43, 46, 63),
    Purple = Color3.fromRGB(135, 95, 255),
    Green = Color3.fromRGB(50, 190, 120),
    Red = Color3.fromRGB(225, 75, 90),
    White = Color3.fromRGB(245, 245, 255),
    Gray = Color3.fromRGB(160, 160, 180)
}

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function New(class, properties, parent)

    local object = Instance.new(class)

    for property, value in pairs(properties) do
        object[property] = value
    end

    object.Parent = parent

    return object

end

local function Round(object, radius)

    New("UICorner", {
        CornerRadius = UDim.new(0, radius or 8)
    }, object)

end

local function Notify(title, text)

    pcall(function()

        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = tostring(text),
            Duration = 4
        })

    end)

end

--------------------------------------------------
-- GUI
--------------------------------------------------

local Gui = New("ScreenGui", {
    Name = "PopItBuyerV21",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999
}, PlayerGui)

local Main = New("Frame", {
    Size = UDim2.fromOffset(380, 520),
    Position = UDim2.new(0.5, -190, 0.5, -260),
    BackgroundColor3 = C.BG,
    BorderSizePixel = 0
}, Gui)

Round(Main, 14)

New("UIStroke", {
    Color = C.Purple,
    Thickness = 1.5,
    Transparency = 0.2
}, Main)

--------------------------------------------------
-- MOBILE SCALE
--------------------------------------------------

local Scale = New("UIScale", {
    Scale = 1
}, Main)

local function UpdateScale()

    local camera = workspace.CurrentCamera

    if not camera then
        return
    end

    local size = camera.ViewportSize

    Scale.Scale = math.min(
        1,
        size.X / 410,
        size.Y / 550
    )

end

UpdateScale()

if workspace.CurrentCamera then

    workspace.CurrentCamera:GetPropertyChangedSignal(
        "ViewportSize"
    ):Connect(UpdateScale)

end

--------------------------------------------------
-- HEADER
--------------------------------------------------

local Header = New("Frame", {
    Size = UDim2.new(1, 0, 0, 50),
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0
}, Main)

Round(Header, 14)

New("TextLabel", {
    Size = UDim2.new(1, -90, 1, 0),
    Position = UDim2.fromOffset(15, 0),
    BackgroundTransparency = 1,
    Text = "POP IT | BUYER V2.1",
    TextColor3 = C.White,
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left
}, Header)

local Close = New("TextButton", {
    Size = UDim2.fromOffset(34, 32),
    Position = UDim2.new(1, -43, 0, 9),
    BackgroundColor3 = C.Red,
    Text = "X",
    TextColor3 = C.White,
    Font = Enum.Font.GothamBold,
    TextSize = 15
}, Header)

Round(Close, 8)

--------------------------------------------------
-- OPEN BUTTON
--------------------------------------------------

local Open = New("TextButton", {
    Size = UDim2.fromOffset(120, 44),
    Position = UDim2.new(0, 10, 0.5, -22),
    BackgroundColor3 = C.Purple,
    Text = "ITEM BUYER",
    TextColor3 = C.White,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    Visible = false
}, Gui)

Round(Open, 10)

Close.MouseButton1Click:Connect(function()
    Main.Visible = false
    Open.Visible = true
end)

Open.MouseButton1Click:Connect(function()
    Main.Visible = true
    Open.Visible = false
end)

--------------------------------------------------
-- DRAGGING
--------------------------------------------------

local Dragging = false
local DragStart
local StartPosition
local DragInput

Header.InputBegan:Connect(function(input)

    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then

        Dragging = true
        DragStart = input.Position
        StartPosition = Main.Position
        DragInput = input

    end

end)

UIS.InputChanged:Connect(function(input)

    if not Dragging then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.MouseMovement
    and input ~= DragInput then
        return
    end

    local delta = input.Position - DragStart

    Main.Position = UDim2.new(
        StartPosition.X.Scale,
        StartPosition.X.Offset + delta.X,
        StartPosition.Y.Scale,
        StartPosition.Y.Offset + delta.Y
    )

end)

UIS.InputEnded:Connect(function(input)

    if input == DragInput
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        Dragging = false
    end

end)

--------------------------------------------------
-- SEARCH
--------------------------------------------------

local Search = New("TextBox", {
    Size = UDim2.new(1, -24, 0, 40),
    Position = UDim2.fromOffset(12, 62),
    BackgroundColor3 = C.Panel,
    Text = "",
    PlaceholderText = "Search items...",
    PlaceholderColor3 = C.Gray,
    TextColor3 = C.White,
    TextSize = 14,
    Font = Enum.Font.Gotham,
    ClearTextOnFocus = false
}, Main)

Round(Search, 9)

--------------------------------------------------
-- ITEM LIST
--------------------------------------------------

local List = New("ScrollingFrame", {
    Size = UDim2.new(1, -24, 0, 220),
    Position = UDim2.fromOffset(12, 112),
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = C.Purple,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.fromOffset(0, 0)
}, Main)

Round(List, 9)

New("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder
}, List)

New("UIPadding", {
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6)
}, List)

--------------------------------------------------
-- SELECTED LABEL
--------------------------------------------------

local SelectedText = New("TextLabel", {
    Size = UDim2.new(1, -24, 0, 32),
    Position = UDim2.fromOffset(12, 340),
    BackgroundTransparency = 1,
    Text = "Selected: None",
    TextColor3 = C.White,
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd
}, Main)

--------------------------------------------------
-- BUTTON HELPER
--------------------------------------------------

local function Button(text, pos, size, color)

    local button = New("TextButton", {
        Size = size,
        Position = pos,
        BackgroundColor3 = color,
        Text = text,
        TextColor3 = C.White,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        BorderSizePixel = 0
    }, Main)

    Round(button, 8)

    return button

end

--------------------------------------------------
-- BUTTONS
--------------------------------------------------

local BuyButton = Button(
    "BUY SELECTED ITEM",
    UDim2.fromOffset(12, 380),
    UDim2.new(1, -24, 0, 42),
    C.Green
)

local AutoButton = Button(
    "AUTO BUY: OFF",
    UDim2.fromOffset(12, 430),
    UDim2.new(0.48, 0, 0, 36),
    C.Button
)

local RefreshButton = Button(
    "REFRESH",
    UDim2.new(0.52, 0, 0, 430),
    UDim2.new(0.45, 0, 0, 36),
    C.Purple
)

local DelayButton = Button(
    "DELAY: 2s",
    UDim2.fromOffset(12, 475),
    UDim2.new(1, -24, 0, 32),
    C.Button
)

--------------------------------------------------
-- IMPROVED PRICE DETECTION
--------------------------------------------------

local PriceNames = {
    "Price",
    "price",
    "Cost",
    "cost",
    "Coins",
    "Cash",
    "Money",
    "Amount",
    "BuyPrice",
    "PurchasePrice"
}

local function GetPrice(object)

    -- Check attributes

    for _, name in ipairs(PriceNames) do

        local value = object:GetAttribute(name)

        if typeof(value) == "number"
        and value >= 0 then
            return value
        end

    end

    -- Check descendants

    for _, child in ipairs(object:GetDescendants()) do

        for _, name in ipairs(PriceNames) do

            if child.Name == name then

                if child:IsA("NumberValue")
                or child:IsA("IntValue") then

                    if child.Value >= 0 then
                        return child.Value
                    end

                end

            end

        end

    end

    return nil

end

--------------------------------------------------
-- ITEM SCANNER
--------------------------------------------------

local function ScanItems()

    local found = {}
    local seen = {}

    local containers = {
        "Items",
        "ShopItems",
        "ItemData",
        "Catalog",
        "Shop"
    }

    for _, name in ipairs(containers) do

        local folder = RS:FindFirstChild(name, true)

        if folder then

            for _, item in ipairs(folder:GetChildren()) do

                if not seen[item.Name] then

                    seen[item.Name] = true

                    table.insert(found, {
                        Name = item.Name,
                        Price = GetPrice(item),
                        Object = item
                    })

                end

            end

        end

    end

    table.sort(found, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)

    return found

end

--------------------------------------------------
-- RENDER ITEMS
--------------------------------------------------

local Render

Render = function()

    for _, child in ipairs(List:GetChildren()) do

        if child:IsA("TextButton")
        or child.Name == "EmptyLabel" then
            child:Destroy()
        end

    end

    local query = Search.Text:lower()
    local count = 0

    for _, item in ipairs(Items) do

        if item.Name:lower():find(query, 1, true) then

            count += 1

            local priceText = item.Price ~= nil
                and tostring(item.Price)
                or "Price N/A"

            local button = New("TextButton", {
                Size = UDim2.new(1, -2, 0, 37),
                BackgroundColor3 =
                    Selected == item and C.Purple
                    or C.Button,
                Text = "  " .. item.Name .. " | " .. priceText,
                TextColor3 = C.White,
                TextSize = 13,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                BorderSizePixel = 0
            }, List)

            Round(button, 7)

            button.MouseButton1Click:Connect(function()

                Selected = item

                SelectedText.Text =
                    "Selected: " .. item.Name
                    .. " | " .. priceText

                Render()

            end)

        end

    end

    if count == 0 then

        New("TextLabel", {
            Name = "EmptyLabel",
            Size = UDim2.new(1, -2, 0, 40),
            BackgroundTransparency = 1,
            Text = "No items found",
            TextColor3 = C.Gray,
            TextSize = 14,
            Font = Enum.Font.Gotham
        }, List)

    end

end

--------------------------------------------------
-- REFRESH
--------------------------------------------------

local function Refresh()

    local oldName = Selected and Selected.Name

    Items = ScanItems()
    Selected = nil

    if oldName then

        for _, item in ipairs(Items) do

            if item.Name == oldName then
                Selected = item
                break
            end

        end

    end

    if Selected then

        SelectedText.Text =
            "Selected: " .. Selected.Name

    else

        SelectedText.Text = "Selected: None"

    end

    Render()

    Notify(
        "Pop It Buyer V2.1",
        "Items found: " .. tostring(#Items)
    )

end

--------------------------------------------------
-- BALANCE DETECTION
--------------------------------------------------

local function GetBalance()

    local stats = Player:FindFirstChild("leaderstats")

    if not stats then
        return nil
    end

    local currencies = {
        "Cash",
        "Coins",
        "Money",
        "Credits"
    }

    for _, name in ipairs(currencies) do

        local value = stats:FindFirstChild(name)

        if value and (
            value:IsA("IntValue")
            or value:IsA("NumberValue")
        ) then

            return value.Value

        end

    end

    return nil

end

--------------------------------------------------
-- PURCHASE ADAPTER
--------------------------------------------------

-- Replace with confirmed game purchase logic.
--
-- Return:
-- true, "Success"
-- false, "Reason"

local function PurchaseAdapter(item)

    return false, "Purchase system not configured"

end

--------------------------------------------------
-- BUY SYSTEM
--------------------------------------------------

local function Buy()

    if Buying then
        return
    end

    if not Selected then

        Notify(
            "Item Buyer",
            "Select an item first"
        )

        return

    end

    if Selected.Price == nil then

        Notify(
            "Purchase Failed",
            "Price not available"
        )

        return

    end

    local balance = GetBalance()

    if balance ~= nil
    and balance < Selected.Price then

        Notify(
            "Purchase Failed",
            "Not enough currency"
        )

        return

    end

    if os.clock() - LastBuy < Config.AutoBuyDelay then
        return
    end

    Buying = true
    LastBuy = os.clock()

    BuyButton.Text = "BUYING..."

    local item = Selected

    local ok, success, message = pcall(function()
        return PurchaseAdapter(item)
    end)

    Buying = false
    BuyButton.Text = "BUY SELECTED ITEM"

    if not ok then

        Notify(
            "Purchase Error",
            tostring(success)
        )

        return

    end

    if success == true then

        Notify(
            "Purchase Successful",
            item.Name
        )

    else

        Notify(
            "Purchase Failed",
            tostring(message or "Unknown error")
        )

    end

end

--------------------------------------------------
-- BUY BUTTON
--------------------------------------------------

BuyButton.MouseButton1Click:Connect(function()
    task.spawn(Buy)
end)

--------------------------------------------------
-- AUTO BUY
--------------------------------------------------

AutoButton.MouseButton1Click:Connect(function()

    AutoBuy = not AutoBuy

    if AutoBuy then

        AutoButton.Text = "AUTO BUY: ON"
        AutoButton.BackgroundColor3 = C.Green

    else

        AutoButton.Text = "AUTO BUY: OFF"
        AutoButton.BackgroundColor3 = C.Button

    end

end)

task.spawn(function()

    while Running do

        if AutoBuy and Selected and not Buying then
            Buy()
        end

        task.wait(Config.AutoBuyDelay)

    end

end)

--------------------------------------------------
-- DELAY BUTTON
--------------------------------------------------

DelayButton.MouseButton1Click:Connect(function()

    Config.AutoBuyDelay += 1

    if Config.AutoBuyDelay > Config.MaxDelay then
        Config.AutoBuyDelay = Config.MinDelay
    end

    DelayButton.Text =
        "DELAY: " .. Config.AutoBuyDelay .. "s"

end)

--------------------------------------------------
-- EVENTS
--------------------------------------------------

RefreshButton.MouseButton1Click:Connect(Refresh)

Search:GetPropertyChangedSignal("Text"):Connect(Render)

--------------------------------------------------
-- START
--------------------------------------------------

Refresh()

Notify(
    "POP IT BUYER V2.1",
    "GUI loaded successfully!"
)

print("[POP IT BUYER V2.1] Loaded")
