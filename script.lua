--[[
    POP IT TRADING | ULTIMATE HUB V6.1
    PlaceId: 7346416636

    FEATURES:
    - Dark Mode GUI
    - Mobile / PC
    - Draggable Window
    - Item Buyer
    - Item Search
    - Auto Buy
    - Price Detection
    - Refresh
    - Wheel Prize
    - Redeem Codes
    - Find Game Codes
    - Copy Codes
    - Custom Local Codes
    - Local JSON Storage
    - Notifications

    IMPORTANT:
    Free rewards and purchases are subject
    to the game's server-side validation.

    Custom codes are local only.
]]

--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--------------------------------------------------
-- GAME CHECK
--------------------------------------------------

if game.PlaceId ~= 7346416636 then
    warn("[POP IT V6.1] Unsupported game")
    return
end

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local Config = {
    AutoBuyDelay = 2,
    MinDelay = 1,
    MaxDelay = 10,

    BuyCooldown = 1.5,
    ClaimCooldown = 5,
    CodeCooldown = 3,

    SaveFile = "PopItCustomCodesV61.json"
}

--------------------------------------------------
-- CLEANUP
--------------------------------------------------

local Env = getgenv and getgenv()

if Env and Env.PopItHubStop then
    pcall(Env.PopItHubStop)
end

local Old = PlayerGui:FindFirstChild("PopItUltimateV61")

if Old then
    Old:Destroy()
end

--------------------------------------------------
-- STATE
--------------------------------------------------

local Running = true

local AutoBuy = false
local Buying = false
local ClaimBusy = false

local Items = {}
local Selected = nil

local CustomCodes = {}
local FoundCodes = {}
local SelectedFoundCode = nil

local LastBuy = 0
local LastClaim = 0
local LastCode = 0

if Env then

    Env.PopItHubStop = function()
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

    for property, value in pairs(props) do
        obj[property] = value
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

local function Button(text, parent, position, size, color)

    local button = New("TextButton", {
        Size = size,
        Position = position,

        BackgroundColor3 = color or C.Button,
        BorderSizePixel = 0,

        Text = text,
        TextColor3 = C.White,

        Font = Enum.Font.GothamBold,
        TextSize = 13,

        AutoButtonColor = true
    }, parent)

    Round(button, 8)

    return button

end

local function TextBox(placeholder, parent, position, size)

    local box = New("TextBox", {
        Size = size,
        Position = position,

        BackgroundColor3 = C.Panel,
        BorderSizePixel = 0,

        PlaceholderText = placeholder,
        PlaceholderColor3 = C.Gray,

        Text = "",
        TextColor3 = C.White,

        Font = Enum.Font.Gotham,
        TextSize = 14,

        ClearTextOnFocus = false
    }, parent)

    Round(box, 8)

    return box

end

local function Label(text, parent, position, size, fontSize)

    return New("TextLabel", {
        Size = size,
        Position = position,

        BackgroundTransparency = 1,

        Text = text,
        TextColor3 = C.White,

        Font = Enum.Font.GothamBold,
        TextSize = fontSize or 14,

        TextWrapped = true
    }, parent)

end

local function Trim(text)

    return tostring(text):match("^%s*(.-)%s*$")

end

--------------------------------------------------
-- REMOTE DETECTION
--------------------------------------------------

local function GetRemote(name, class)

    local folder = RS:FindFirstChild("RemoteEvents")

    if not folder then
        return nil
    end

    local remote = folder:FindFirstChild(name)

    if remote and remote:IsA(class) then
        return remote
    end

    return nil

end

local BuyRemote
local ClaimRemote
local CodeRemote

local function RefreshRemotes()

    BuyRemote = GetRemote(
        "BuyItemCash",
        "RemoteEvent"
    )

    ClaimRemote = GetRemote(
        "ClaimPrize",
        "RemoteFunction"
    )

    CodeRemote = GetRemote(
        "RequestCode",
        "RemoteEvent"
    )

end

RefreshRemotes()

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

        local value = obj:GetAttribute(name)

        if type(value) == "number"
        and value >= 0 then

            return value

        end

    end

    for _, child in ipairs(obj:GetDescendants()) do

        if child:IsA("IntValue")
        or child:IsA("NumberValue") then

            for _, name in ipairs(PriceNames) do

                if child.Name == name
                and child.Value >= 0 then

                    return child.Value

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

    for _, folderName in ipairs(containers) do

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
                        Price = GetPrice(obj)
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
-- BALANCE
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
-- GUI
--------------------------------------------------

local Gui = New("ScreenGui", {
    Name = "PopItUltimateV61",

    ResetOnSpawn = false,
    IgnoreGuiInset = true,

    DisplayOrder = 999
}, PlayerGui)

local Main = New("Frame", {
    Size = UDim2.fromOffset(420, 560),

    Position = UDim2.new(
        0.5, -210,
        0.5, -280
    ),

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
        size.X / 450,
        size.Y / 590
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
    Size = UDim2.new(1, 0, 0, 52),

    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0
}, Main)

Round(Header, 14)

Label(
    "POP IT | ULTIMATE V6.1",
    Header,
    UDim2.fromOffset(15, 0),
    UDim2.new(1, -100, 1, 0),
    17
).TextXAlignment = Enum.TextXAlignment.Left

local Close = Button(
    "X",
    Header,
    UDim2.new(1, -43, 0, 10),
    UDim2.fromOffset(34, 32),
    C.Red
)

local Open = Button(
    "POP IT HUB",
    Gui,
    UDim2.new(0, 10, 0.5, -22),
    UDim2.fromOffset(120, 44),
    C.Purple
)

Open.Visible = false

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
-- TABS
--------------------------------------------------

local TabBar = New("Frame", {
    Size = UDim2.new(1, -24, 0, 42),

    Position = UDim2.fromOffset(12, 64),

    BackgroundTransparency = 1
}, Main)

local TabNames = {
    "BUYER",
    "REWARDS",
    "CODES",
    "CUSTOM"
}

local Tabs = {}
local Pages = {}

for i, name in ipairs(TabNames) do

    Tabs[name] = Button(
        name,
        TabBar,

        UDim2.new(
            (i - 1) * 0.253,
            0,
            0,
            0
        ),

        UDim2.new(0.24, 0, 1, 0),

        C.Button
    )

    Pages[name] = New("Frame", {
        Size = UDim2.new(1, -24, 1, -125),

        Position = UDim2.fromOffset(12, 115),

        BackgroundTransparency = 1,
        Visible = false
    }, Main)

end

local function SwitchTab(name)

    for pageName, page in pairs(Pages) do

        page.Visible = pageName == name

    end

    for tabName, button in pairs(Tabs) do

        button.BackgroundColor3 =
            tabName == name
            and C.Purple
            or C.Button

    end

end

for name, button in pairs(Tabs) do

    button.MouseButton1Click:Connect(function()

        SwitchTab(name)

    end)

end

--------------------------------------------------
-- BUYER PAGE
--------------------------------------------------

local Buyer = Pages.BUYER

local Search = TextBox(
    "Search items...",
    Buyer,

    UDim2.fromOffset(0, 0),

    UDim2.new(1, 0, 0, 40)
)

local ItemList = New("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 220),

    Position = UDim2.fromOffset(0, 50),

    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,

    ScrollBarThickness = 4,
    ScrollBarImageColor3 = C.Purple,

    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.fromOffset(0, 0)
}, Buyer)

Round(ItemList, 8)

New("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder
}, ItemList)

New("UIPadding", {
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),

    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6)
}, ItemList)

local SelectedLabel = Label(
    "Selected: None",
    Buyer,

    UDim2.fromOffset(0, 278),

    UDim2.new(1, 0, 0, 30),
    13
)

SelectedLabel.TextXAlignment =
    Enum.TextXAlignment.Left

SelectedLabel.TextTruncate =
    Enum.TextTruncate.AtEnd

local BuyButton = Button(
    "BUY SELECTED ITEM",
    Buyer,

    UDim2.fromOffset(0, 315),

    UDim2.new(1, 0, 0, 40),

    C.Green
)

local AutoButton = Button(
    "AUTO BUY: OFF",
    Buyer,

    UDim2.fromOffset(0, 363),

    UDim2.new(0.48, 0, 0, 35),

    C.Button
)

local RefreshButton = Button(
    "REFRESH",
    Buyer,

    UDim2.new(0.52, 0, 0, 363),

    UDim2.new(0.48, 0, 0, 35),

    C.Purple
)

local DelayButton = Button(
    "DELAY: 2s",
    Buyer,

    UDim2.fromOffset(0, 405),

    UDim2.new(1, 0, 0, 32),

    C.Button
)

--------------------------------------------------
-- RENDER ITEMS
--------------------------------------------------

local RenderItems

RenderItems = function()

    for _, child in ipairs(ItemList:GetChildren()) do

        if child:IsA("TextButton")
        or child.Name == "EmptyLabel" then

            child:Destroy()

        end

    end

    local query = Search.Text:lower()
    local count = 0

    for _, item in ipairs(Items) do

        if item.Name:lower():find(
            query,
            1,
            true
        ) then

            count += 1

            local price = item.Price ~= nil
                and tostring(item.Price)
                or "Price N/A"

            local entry = Button(
                item.Name .. " | " .. price,

                ItemList,

                UDim2.new(),

                UDim2.new(1, -2, 0, 36),

                Selected == item
                    and C.Purple
                    or C.Button
            )

            entry.TextXAlignment =
                Enum.TextXAlignment.Left

            entry.TextTruncate =
                Enum.TextTruncate.AtEnd

            entry.MouseButton1Click:Connect(function()

                Selected = item

                SelectedLabel.Text =
                    "Selected: "
                    .. item.Name
                    .. " | "
                    .. price

                RenderItems()

            end)

        end

    end

    if count == 0 then

        New("TextLabel", {
            Name = "EmptyLabel",

            Size = UDim2.new(1, 0, 0, 40),

            BackgroundTransparency = 1,

            Text = "No items found",

            TextColor3 = C.Gray,
            TextSize = 14,

            Font = Enum.Font.Gotham
        }, ItemList)

    end

end

--------------------------------------------------
-- REFRESH ITEMS
--------------------------------------------------

local function RefreshItems()

    local previousName = Selected and Selected.Name

    Items = ScanItems()

    Selected = nil

    if previousName then

        for _, item in ipairs(Items) do

            if item.Name == previousName then

                Selected = item
                break

            end

        end

    end

    SelectedLabel.Text = Selected
        and ("Selected: " .. Selected.Name)
        or "Selected: None"

    RenderItems()

    Notify(
        "Item Buyer",
        "Found " .. #Items .. " items"
    )

end

--------------------------------------------------
-- BUY SYSTEM
--------------------------------------------------

local function BuyItem()

    if Buying or not Running then
        return
    end

    if not Selected then

        Notify("Buyer", "Select an item")
        return

    end

    RefreshRemotes()

    if not BuyRemote then

        Notify("Buyer", "BuyItemCash unavailable")
        return

    end

    if Selected.Price == nil then

        Notify("Buyer", "Price unavailable")
        return

    end

    local balance = GetBalance()

    if balance ~= nil
    and balance < Selected.Price then

        Notify("Buyer", "Not enough currency")
        return

    end

    if os.clock() - LastBuy < Config.BuyCooldown then
        return
    end

    Buying = true
    LastBuy = os.clock()

    BuyButton.Text = "SENDING..."

    local itemName = Selected.Name

    local ok, err = pcall(function()

        BuyRemote:FireServer(itemName)

    end)

    Buying = false
    BuyButton.Text = "BUY SELECTED ITEM"

    if ok then

        Notify(
            "Purchase Request Sent",
            itemName
        )

    else

        Notify(
            "Purchase Error",
            tostring(err)
        )

    end

end

BuyButton.MouseButton1Click:Connect(function()

    task.spawn(BuyItem)

end)

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

            BuyItem()

        end

        task.wait(Config.AutoBuyDelay)

    end

end)

DelayButton.MouseButton1Click:Connect(function()

    Config.AutoBuyDelay += 1

    if Config.AutoBuyDelay > Config.MaxDelay then

        Config.AutoBuyDelay = Config.MinDelay

    end

    DelayButton.Text =
        "DELAY: "
        .. Config.AutoBuyDelay
        .. "s"

end)

RefreshButton.MouseButton1Click:Connect(
    RefreshItems
)

Search:GetPropertyChangedSignal("Text"):Connect(
    RenderItems
)

--------------------------------------------------
-- REWARDS PAGE
--------------------------------------------------

local Rewards = Pages.REWARDS

Label(
    "WHEEL OF FORTUNE\n\nClaim an available wheel prize.",
    Rewards,

    UDim2.fromOffset(0, 20),

    UDim2.new(1, 0, 0, 100),

    17
)

local ClaimButton = Button(
    "CLAIM WHEEL PRIZE",
    Rewards,

    UDim2.fromOffset(0, 145),

    UDim2.new(1, 0, 0, 45),

    C.Green
)

ClaimButton.MouseButton1Click:Connect(function()

    if ClaimBusy then
        return
    end

    RefreshRemotes()

    if not ClaimRemote then

        Notify("Wheel", "ClaimPrize unavailable")
        return

    end

    if os.clock() - LastClaim < Config.ClaimCooldown then

        Notify("Wheel", "Please wait")
        return

    end

    ClaimBusy = true
    LastClaim = os.clock()

    ClaimButton.Text = "CLAIMING..."

    task.spawn(function()

        local ok, result = pcall(function()

            return ClaimRemote:InvokeServer()

        end)

        ClaimBusy = false

        ClaimButton.Text = "CLAIM WHEEL PRIZE"

        if ok then

            Notify(
                "Wheel Server Response",
                tostring(result)
            )

        else

            Notify(
                "Wheel Error",
                tostring(result)
            )

        end

    end)

end)

--------------------------------------------------
-- CODES PAGE
--------------------------------------------------

local Codes = Pages.CODES

Label(
    "REDEEM PROMO CODES",
    Codes,

    UDim2.fromOffset(0, 5),

    UDim2.new(1, 0, 0, 35),

    17
)

local CodeBox = TextBox(
    "Enter promo code...",
    Codes,

    UDim2.fromOffset(0, 45),

    UDim2.new(1, 0, 0, 40)
)

local RedeemButton = Button(
    "REDEEM CODE",
    Codes,

    UDim2.fromOffset(0, 95),

    UDim2.new(1, 0, 0, 40),

    C.Purple
)

RedeemButton.MouseButton1Click:Connect(function()

    RefreshRemotes()

    if not CodeRemote then

        Notify("Codes", "RequestCode unavailable")
        return

    end

    if os.clock() - LastCode < Config.CodeCooldown then

        Notify("Codes", "Please wait")
        return

    end

    local code = Trim(CodeBox.Text)

    if code == "" then

        Notify("Codes", "Enter a code")
        return

    end

    LastCode = os.clock()

    local ok, err = pcall(function()

        CodeRemote:FireServer(code)

    end)

    if ok then

        Notify(
            "Code Request Sent",
            code
        )

    else

        Notify(
            "Code Error",
            tostring(err)
        )

    end

end)

--------------------------------------------------
-- GAME CODE FINDER
--------------------------------------------------

local CodePatterns = {
    "code",
    "promo",
    "redeem",
    "rewardcode"
}

local function IsCodeContainer(name)

    name = name:lower()

    for _, pattern in ipairs(CodePatterns) do

        if name:find(pattern, 1, true) then

            return true

        end

    end

    return false

end

local function FindGameCodes()

    local results = {}
    local seen = {}

    for _, obj in ipairs(RS:GetDescendants()) do

        if IsCodeContainer(obj.Name) then

            if obj:IsA("StringValue") then

                local value = obj.Value

                if value ~= ""
                and #value <= 50
                and not seen[value] then

                    seen[value] = true

                    table.insert(results, value)

                end

            end

            for _, child in ipairs(obj:GetChildren()) do

                if child:IsA("StringValue") then

                    local value = child.Value

                    if value ~= ""
                    and #value <= 50
                    and not seen[value] then

                        seen[value] = true

                        table.insert(results, value)

                    end

                end

            end

        end

    end

    table.sort(results)

    return results

end

--------------------------------------------------
-- FIND CODES BUTTON
--------------------------------------------------

local FindCodesButton = Button(
    "FIND GAME CODES",
    Codes,

    UDim2.fromOffset(0, 145),

    UDim2.new(1, 0, 0, 38),

    C.Green
)

--------------------------------------------------
-- FOUND CODES LIST
--------------------------------------------------

local FoundCodeList = New("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 175),

    Position = UDim2.fromOffset(0, 195),

    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,

    ScrollBarThickness = 4,
    ScrollBarImageColor3 = C.Purple,

    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.fromOffset(0, 0)
}, Codes)

Round(FoundCodeList, 8)

New("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder
}, FoundCodeList)

New("UIPadding", {
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),

    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6)
}, FoundCodeList)

--------------------------------------------------
-- RENDER FOUND CODES
--------------------------------------------------

local function RenderFoundCodes()

    for _, child in ipairs(FoundCodeList:GetChildren()) do

        if child:IsA("TextButton")
        or child.Name == "EmptyCodes" then

            child:Destroy()

        end

    end

    if #FoundCodes == 0 then

        New("TextLabel", {
            Name = "EmptyCodes",

            Size = UDim2.new(1, 0, 0, 50),

            BackgroundTransparency = 1,

            Text = "No possible codes found",

            TextColor3 = C.Gray,
            TextSize = 13,

            Font = Enum.Font.Gotham
        }, FoundCodeList)

        return

    end

    for _, code in ipairs(FoundCodes) do

        local entry = Button(
            code,
            FoundCodeList,

            UDim2.new(),

            UDim2.new(1, -2, 0, 34),

            SelectedFoundCode == code
                and C.Purple
                or C.Button
        )

        entry.MouseButton1Click:Connect(function()

            SelectedFoundCode = code

            CodeBox.Text = code

            RenderFoundCodes()

        end)

    end

end

--------------------------------------------------
-- FIND CODES EVENT
--------------------------------------------------

FindCodesButton.MouseButton1Click:Connect(function()

    FoundCodes = FindGameCodes()

    SelectedFoundCode = nil

    RenderFoundCodes()

    Notify(
        "Game Code Finder",
        "Found "
        .. #FoundCodes
        .. " possible codes"
    )

end)

--------------------------------------------------
-- COPY CODE
--------------------------------------------------

local CopyCodeButton = Button(
    "COPY SELECTED CODE",
    Codes,

    UDim2.fromOffset(0, 380),

    UDim2.new(1, 0, 0, 38),

    C.Purple
)

CopyCodeButton.MouseButton1Click:Connect(function()

    if not SelectedFoundCode then

        Notify(
            "Codes",
            "Select a code first"
        )

        return

    end

    if type(setclipboard) == "function" then

        local ok = pcall(function()

            setclipboard(SelectedFoundCode)

        end)

        if ok then

            Notify("Codes", "Code copied!")

        else

            Notify("Codes", "Copy failed")

        end

    else

        Notify(
            "Codes",
            "Clipboard unavailable"
        )

    end

end)

--------------------------------------------------
-- CUSTOM CODES PAGE
--------------------------------------------------

local Custom = Pages.CUSTOM

Label(
    "CUSTOM CODES (LOCAL ONLY)",
    Custom,

    UDim2.fromOffset(0, 5),

    UDim2.new(1, 0, 0, 40),

    16
)

local CustomCodeBox = TextBox(
    "Custom code name...",
    Custom,

    UDim2.fromOffset(0, 55),

    UDim2.new(1, 0, 0, 40)
)

local RewardBox = TextBox(
    "Reward description...",
    Custom,

    UDim2.fromOffset(0, 105),

    UDim2.new(1, 0, 0, 40)
)

local CreateButton = Button(
    "CREATE LOCAL CODE",
    Custom,

    UDim2.fromOffset(0, 155),

    UDim2.new(1, 0, 0, 40),

    C.Green
)

local CustomList = New("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 200),

    Position = UDim2.fromOffset(0, 205),

    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,

    ScrollBarThickness = 4,
    ScrollBarImageColor3 = C.Purple,

    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.fromOffset(0, 0)
}, Custom)

Round(CustomList, 8)

New("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder
}, CustomList)

New("UIPadding", {
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),

    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6)
}, CustomList)

--------------------------------------------------
-- LOCAL CODE STORAGE
--------------------------------------------------

local function SaveCodes()

    if type(writefile) ~= "function" then
        return
    end

    pcall(function()

        local json = HttpService:JSONEncode(
            CustomCodes
        )

        writefile(Config.SaveFile, json)

    end)

end

local function LoadCodes()

    if type(readfile) ~= "function"
    or type(isfile) ~= "function" then

        return

    end

    pcall(function()

        if isfile(Config.SaveFile) then

            local data = readfile(Config.SaveFile)

            local decoded = HttpService:JSONDecode(
                data
            )

            if type(decoded) == "table" then

                CustomCodes = decoded

            end

        end

    end)

end

--------------------------------------------------
-- RENDER CUSTOM CODES
--------------------------------------------------

local RenderCustomCodes

RenderCustomCodes = function()

    for _, child in ipairs(CustomList:GetChildren()) do

        if child:IsA("Frame") then
            child:Destroy()
        end

    end

    for index, entry in ipairs(CustomCodes) do

        local row = New("Frame", {
            Size = UDim2.new(1, -2, 0, 45),

            BackgroundColor3 = C.Button,
            BorderSizePixel = 0
        }, CustomList)

        Round(row, 7)

        local nameLabel = Label(
            tostring(entry.Code)
            .. " -> "
            .. tostring(entry.Reward),

            row,

            UDim2.fromOffset(8, 0),

            UDim2.new(1, -100, 1, 0),

            12
        )

        nameLabel.TextXAlignment =
            Enum.TextXAlignment.Left

        nameLabel.TextTruncate =
            Enum.TextTruncate.AtEnd

        local DeleteButton = Button(
            "DELETE",
            row,

            UDim2.new(1, -85, 0, 6),

            UDim2.fromOffset(78, 33),

            C.Red
        )

        DeleteButton.MouseButton1Click:Connect(function()

            table.remove(CustomCodes, index)

            SaveCodes()
            RenderCustomCodes()

            Notify(
                "Custom Codes",
                "Code deleted"
            )

        end)

    end

end

--------------------------------------------------
-- CREATE CUSTOM CODE
--------------------------------------------------

CreateButton.MouseButton1Click:Connect(function()

    local code = Trim(CustomCodeBox.Text)
    local reward = Trim(RewardBox.Text)

    if code == "" or reward == "" then

        Notify(
            "Custom Codes",
            "Fill both fields"
        )

        return

    end

    for _, entry in ipairs(CustomCodes) do

        if tostring(entry.Code):lower()
        == code:lower() then

            Notify(
                "Custom Codes",
                "Code already exists"
            )

            return

        end

    end

    table.insert(CustomCodes, {
        Code = code,
        Reward = reward
    })

    SaveCodes()
    RenderCustomCodes()

    CustomCodeBox.Text = ""
    RewardBox.Text = ""

    Notify(
        "Custom Codes",
        "Local code created: " .. code
    )

end)

--------------------------------------------------
-- START
--------------------------------------------------

LoadCodes()

RenderCustomCodes()
RenderFoundCodes()

SwitchTab("BUYER")

RefreshItems()

Notify(
    "POP IT ULTIMATE V6.1",
    "Hub loaded successfully!"
)

print("[POP IT ULTIMATE V6.1] Loaded")
