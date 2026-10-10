--[[
    POP IT TRADING | ITEM BUYER V4

    Game ID: 7346416636

    Features:
    - Dark Mode GUI
    - Item Search
    - Item Selection
    - Real BuyItemCash Remote
    - Auto Buy
    - Adjustable Delay
    - Refresh Items
    - Price Detection
    - Mobile Support
    - Draggable GUI
    - Notifications
    - Duplicate Request Protection
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
-- GAME CHECK
--------------------------------------------------

if game.PlaceId ~= 7346416636 then
    warn("[POP IT BUYER] Wrong game!")
    return
end

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local Config = {
    AutoBuyDelay = 2,
    MinDelay = 1,
    MaxDelay = 10,
    PurchaseCooldown = 1.5
}

--------------------------------------------------
-- CLEANUP
--------------------------------------------------

local Env = getgenv and getgenv()

if Env and Env.PopItBuyerStop then
    Env.PopItBuyerStop()
end

local Old = PlayerGui:FindFirstChild("PopItBuyerV4")

if Old then
    Old:Destroy()
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

if Env then
    Env.PopItBuyerStop = function()
        Running = false
        AutoBuy = false
    end
end

--------------------------------------------------
-- COLORS
--------------------------------------------------

local C = {
    BG = Color3.fromRGB(17, 18, 27),
    Panel = Color3.fromRGB(28, 30, 43),
    Button = Color3.fromRGB(44, 46, 64),
    Purple = Color3.fromRGB(135, 95, 255),
    Green = Color3.fromRGB(45, 190, 120),
    Red = Color3.fromRGB(225, 75, 90),
    White = Color3.fromRGB(245, 245, 255),
    Gray = Color3.fromRGB(160, 160, 180)
}

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function New(class, props, parent)

    local obj = Instance.new(class)

    for k, v in pairs(props) do
        obj[k] = v
    end

    obj.Parent = parent
    return obj

end

local function Round(obj, radius)

    New("UICorner", {
        CornerRadius = UDim.new(0, radius or 8)
    }, obj)

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
-- PURCHASE REMOTE
--------------------------------------------------

local RemoteFolder = RS:WaitForChild("RemoteEvents", 10)

local BuyRemote = RemoteFolder
    and RemoteFolder:FindFirstChild("BuyItemCash")

if not BuyRemote or not BuyRemote:IsA("RemoteEvent") then

    warn("[POP IT BUYER] BuyItemCash not found!")

    Notify(
        "Item Buyer",
        "BuyItemCash remote not found"
    )

end

--------------------------------------------------
-- PRICE DETECTION
--------------------------------------------------

local PriceNames = {
    "Price",
    "price",
    "Cost",
    "cost",
    "Cash",
    "Coins",
    "Money",
    "Amount",
    "BuyPrice",
    "PurchasePrice"
}

local function GetPrice(obj)

    for _, name in ipairs(PriceNames) do

        local attribute = obj:GetAttribute(name)

        if type(attribute) == "number"
        and attribute >= 0 then

            return attribute

        end

    end

    for _, descendant in ipairs(obj:GetDescendants()) do

        if descendant:IsA("IntValue")
        or descendant:IsA("NumberValue") then

            for _, name in ipairs(PriceNames) do

                if descendant.Name == name
                and descendant.Value >= 0 then

                    return descendant.Value

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

    local folders = {
        "Items",
        "ShopItems",
        "ItemData",
        "Catalog",
        "Shop"
    }

    for _, folderName in ipairs(folders) do

        local folder = RS:FindFirstChild(
            folderName,
            true
        )

        if folder then

            for _, obj in ipairs(folder:GetChildren()) do

                if not seen[obj.Name] then

                    seen[obj.Name] = true

                    table.insert(found, {
                        Name = obj.Name,
                        Price = GetPrice(obj),
                        Object = obj
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
-- GUI
--------------------------------------------------

local Gui = New("ScreenGui", {
    Name = "PopItBuyerV4",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999
}, PlayerGui)

local Main = New("Frame", {
    Size = UDim2.fromOffset(390, 550),
    Position = UDim2.new(0.5, -195, 0.5, -275),
    BackgroundColor3 = C.BG,
    BorderSizePixel = 0
}, Gui)

Round(Main, 14)

New("UIStroke", {
    Color = C.Purple,
    Thickness = 1.5
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
        size.X / 420,
        size.Y / 580
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
    Size = UDim2.new(1, -100, 1, 0),
    Position = UDim2.fromOffset(15, 0),
    BackgroundTransparency = 1,
    Text = "POP IT | BUYER V4",
    TextColor3 = C.White,
    Font = Enum.Font.GothamBold,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left
}, Header)

local Close = New("TextButton", {
    Size = UDim2.fromOffset(34, 32),
    Position = UDim2.new(1, -43, 0, 9),
    BackgroundColor3 = C.Red,
    Text = "X",
    TextColor3 = C.White,
    Font = Enum.Font.GothamBold,
    TextSize = 14
}, Header)

Round(Close, 8)

--------------------------------------------------
-- OPEN BUTTON
--------------------------------------------------

local Open = New("TextButton", {
    Size = UDim2.fromOffset(125, 45),
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
local StartPos
local DragInput

Header.InputBegan:Connect(function(input)

    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then

        Dragging = true
        DragStart = input.Position
        StartPos = Main.Position
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
        StartPos.X.Scale,
        StartPos.X.Offset + delta.X,
        StartPos.Y.Scale,
        StartPos.Y.Offset + delta.Y
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
    PlaceholderText = "Search items...",
    PlaceholderColor3 = C.Gray,
    Text = "",
    TextColor3 = C.White,
    Font = Enum.Font.Gotham,
    TextSize = 14,
    ClearTextOnFocus = false
}, Main)

Round(Search, 8)

--------------------------------------------------
-- ITEM LIST
--------------------------------------------------

local List = New("ScrollingFrame", {
    Size = UDim2.new(1, -24, 0, 235),
    Position = UDim2.fromOffset(12, 112),
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = C.Purple,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.fromOffset(0, 0)
}, Main)

Round(List, 8)

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
-- SELECTED
--------------------------------------------------

local SelectedLabel = New("TextLabel", {
    Size = UDim2.new(1, -24, 0, 30),
    Position = UDim2.fromOffset(12, 355),
    BackgroundTransparency = 1,
    Text = "Selected: None",
    TextColor3 = C.White,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd
}, Main)

--------------------------------------------------
-- BUTTON FACTORY
--------------------------------------------------

local function Button(text, position, size, color)

    local b = New("TextButton", {
        Size = size,
        Position = position,
        BackgroundColor3 = color,
        Text = text,
        TextColor3 = C.White,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        BorderSizePixel = 0
    }, Main)

    Round(b, 8)

    return b

end

--------------------------------------------------
-- BUTTONS
--------------------------------------------------

local BuyButton = Button(
    "BUY SELECTED ITEM",
    UDim2.fromOffset(12, 392),
    UDim2.new(1, -24, 0, 42),
    C.Green
)

local AutoButton = Button(
    "AUTO BUY: OFF",
    UDim2.fromOffset(12, 442),
    UDim2.new(0.48, 0, 0, 36),
    C.Button
)

local RefreshButton = Button(
    "REFRESH",
    UDim2.new(0.52, 0, 0, 442),
    UDim2.new(0.45, 0, 0, 36),
    C.Purple
)

local DelayButton = Button(
    "DELAY: 2s",
    UDim2.fromOffset(12, 486),
    UDim2.new(1, -24, 0, 36),
    C.Button
)

--------------------------------------------------
-- RENDER
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

            local price = item.Price ~= nil
                and tostring(item.Price)
                or "Price N/A"

            local b = New("TextButton", {
                Size = UDim2.new(1, -2, 0, 37),
                BackgroundColor3 =
                    Selected == item and C.Purple
                    or C.Button,
                Text = "  " .. item.Name .. " | " .. price,
                TextColor3 = C.White,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                BorderSizePixel = 0
            }, List)

            Round(b, 7)

            b.MouseButton1Click:Connect(function()

                Selected = item

                SelectedLabel.Text =
                    "Selected: " .. item.Name
                    .. " | " .. price

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
            Font = Enum.Font.Gotham,
            TextSize = 14
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

    SelectedLabel.Text = Selected
        and ("Selected: " .. Selected.Name)
        or "Selected: None"

    Render()

    Notify(
        "Item Buyer V4",
        "Found " .. #Items .. " items"
    )

end

--------------------------------------------------
-- BALANCE
--------------------------------------------------

local function GetBalance()

    local stats = Player:FindFirstChild("leaderstats")

    if not stats then
        return nil
    end

    for _, name in ipairs({
        "Cash",
        "Coins",
        "Money",
        "Credits"
    }) do

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
-- REAL PURCHASE FUNCTION
--------------------------------------------------

local function PurchaseItem(item)

    if not BuyRemote then
        return false, "BuyItemCash unavailable"
    end

    if typeof(item.Name) ~= "string"
    or item.Name == "" then

        return false, "Invalid item name"

    end

    local ok, err = pcall(function()

        BuyRemote:FireServer(item.Name)

    end)

    if not ok then

        return false, tostring(err)

    end

    return true, "Request sent"

end

--------------------------------------------------
-- BUY
--------------------------------------------------

local function Buy()

    if Buying then
        return
    end

    if not Selected then

        Notify("Item Buyer", "Select an item first")
        return

    end

    local item = Selected

    if item.Price == nil then

        Notify(
            "Purchase Failed",
            "Price unavailable"
        )

        return

    end

    local balance = GetBalance()

    if balance ~= nil
    and balance < item.Price then

        Notify(
            "Purchase Failed",
            "Not enough currency"
        )

        return

    end

    local now = os.clock()

    if now - LastBuy < Config.PurchaseCooldown then
        return
    end

    Buying = true
    LastBuy = now

    BuyButton.Text = "BUYING..."

    local success, message = PurchaseItem(item)

    Buying = false
    BuyButton.Text = "BUY SELECTED ITEM"

    if success then

        Notify(
            "Purchase Request Sent",
            item.Name
        )

    else

        Notify(
            "Purchase Error",
            message
        )

    end

end

--------------------------------------------------
-- EVENTS
--------------------------------------------------

BuyButton.MouseButton1Click:Connect(function()
    task.spawn(Buy)
end)

RefreshButton.MouseButton1Click:Connect(Refresh)

Search:GetPropertyChangedSignal("Text"):Connect(Render)

--------------------------------------------------
-- AUTO BUY
--------------------------------------------------

AutoButton.MouseButton1Click:Connect(function()

    AutoBuy = not AutoBuy

    AutoButton.Text = AutoBuy
        and "AUTO BUY: ON"
        or "AUTO BUY: OFF"

    AutoButton.BackgroundColor3 = AutoBuy
        and C.Green
        or C.Button

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
-- START
--------------------------------------------------

Refresh()

Notify(
    "POP IT BUYER V4",
    "GUI loaded successfully!"
)

print("[POP IT BUYER V4] Loaded")
