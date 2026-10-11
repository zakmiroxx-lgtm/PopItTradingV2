--[[
    POP IT TRADING | ULTIMATE HUB V7
    Game ID: 7346416636

    FEATURES:
    - Item Buyer
    - Auto Buy
    - Item Search
    - Price Detection
    - Wheel Rewards
    - Redeem Codes
    - Find Game Codes
    - Custom Local Codes
    - Pinata Hit
    - Pinata Auto Hit
    - Hit Delay Settings
    - Dark GUI
    - Mobile / PC
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

if game.PlaceId ~= 7346416636 then
    warn("Wrong game!")
    return
end

--------------------------------------------------
-- CLEANUP
--------------------------------------------------

local Env = getgenv and getgenv()

if Env and Env.PopItHubStop then
    pcall(Env.PopItHubStop)
end

for _, gui in ipairs(PlayerGui:GetChildren()) do
    if gui.Name:match("^PopItUltimateV") then
        gui:Destroy()
    end
end

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local Config = {
    AutoBuyDelay = 2,
    BuyCooldown = 1.5,
    ClaimCooldown = 5,
    CodeCooldown = 3,

    HitDelayMS = 100,
    MinActualHitDelay = 0.1,

    SaveFile = "PopItCustomCodesV7.json"
}

--------------------------------------------------
-- STATE
--------------------------------------------------

local Running = true
local AutoBuy = false
local AutoHit = false

local Buying = false
local ClaimBusy = false
local HitBusy = false

local Items = {}
local Selected = nil

local FoundCodes = {}
local SelectedFoundCode = nil
local CustomCodes = {}

local LastBuy = 0
local LastClaim = 0
local LastCode = 0

local HitCount = 0

if Env then
    Env.PopItHubStop = function()
        Running = false
        AutoBuy = false
        AutoHit = false
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

local function Button(text, parent, pos, size, color)

    local b = New("TextButton", {
        Size = size,
        Position = pos,
        BackgroundColor3 = color or C.Button,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = C.White,
        Font = Enum.Font.GothamBold,
        TextSize = 13
    }, parent)

    Round(b, 8)
    return b

end

local function TextBox(placeholder, parent, pos, size)

    local box = New("TextBox", {
        Size = size,
        Position = pos,
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

local function Label(text, parent, pos, size, fontSize)

    return New("TextLabel", {
        Size = size,
        Position = pos,
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

local function MakeList(parent, pos, size)

    local list = New("ScrollingFrame", {
        Size = size,
        Position = pos,
        BackgroundColor3 = C.Panel,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = C.Purple,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromOffset(0, 0)
    }, parent)

    Round(list, 8)

    New("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, list)

    New("UIPadding", {
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6)
    }, list)

    return list

end

local function ClearList(list)

    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("TextButton")
        or child:IsA("Frame")
        or child.Name == "EmptyLabel" then
            child:Destroy()
        end
    end

end

--------------------------------------------------
-- REMOTES
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

local function GetPinataRemote()

    -- The observed path uses an object named
    -- "Minigames/Events".

    local folder = RS:FindFirstChild("Minigames/Events")

    if not folder then
        return nil
    end

    local remote = folder:FindFirstChild("HitPinata")

    if remote and remote:IsA("RemoteEvent") then
        return remote
    end

    return nil

end

--------------------------------------------------
-- ITEM SCANNER
--------------------------------------------------

local PriceNames = {
    "Price", "price",
    "Cost", "cost",
    "Cash", "Coins",
    "Money", "Amount",
    "BuyPrice", "PurchasePrice"
}

local function GetPrice(obj)

    for _, name in ipairs(PriceNames) do

        local value = obj:GetAttribute(name)

        if type(value) == "number" and value >= 0 then
            return value
        end

    end

    for _, child in ipairs(obj:GetDescendants()) do

        if child:IsA("NumberValue")
        or child:IsA("IntValue") then

            for _, name in ipairs(PriceNames) do

                if child.Name == name and child.Value >= 0 then
                    return child.Value
                end

            end

        end

    end

    return nil

end

local function ScanItems()

    local found = {}
    local seen = {}

    for _, folderName in ipairs({
        "Items",
        "ShopItems",
        "ItemData",
        "Catalog",
        "Shop"
    }) do

        local folder = RS:FindFirstChild(folderName, true)

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

    for _, name in ipairs({
        "Cash", "Coins", "Money", "Credits"
    }) do

        local value = stats:FindFirstChild(name)

        if value and (
            value:IsA("NumberValue")
            or value:IsA("IntValue")
        ) then
            return value.Value
        end

    end

    return nil

end

--------------------------------------------------
-- MAIN GUI
--------------------------------------------------

local Gui = New("ScreenGui", {
    Name = "PopItUltimateV7",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999
}, PlayerGui)

local Main = New("Frame", {
    Size = UDim2.fromOffset(430, 570),
    Position = UDim2.new(0.5, -215, 0.5, -285),
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
        size.X / 460,
        size.Y / 600
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

local Title = Label(
    "POP IT | ULTIMATE V7",
    Header,
    UDim2.fromOffset(15, 0),
    UDim2.new(1, -90, 1, 0),
    17
)

Title.TextXAlignment = Enum.TextXAlignment.Left

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
    "CUSTOM",
    "PINATA"
}

local Tabs = {}
local Pages = {}

for i, name in ipairs(TabNames) do

    Tabs[name] = Button(
        name,
        TabBar,
        UDim2.new((i - 1) * 0.202, 0, 0, 0),
        UDim2.new(0.19, 0, 1, 0),
        C.Button
    )

    Tabs[name].TextSize = 11

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
            tabName == name and C.Purple or C.Button

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

local ItemList = MakeList(
    Buyer,
    UDim2.fromOffset(0, 50),
    UDim2.new(1, 0, 0, 220)
)

local SelectedLabel = Label(
    "Selected: None",
    Buyer,
    UDim2.fromOffset(0, 278),
    UDim2.new(1, 0, 0, 30),
    13
)

SelectedLabel.TextXAlignment = Enum.TextXAlignment.Left
SelectedLabel.TextTruncate = Enum.TextTruncate.AtEnd

local BuyButton = Button(
    "BUY SELECTED ITEM",
    Buyer,
    UDim2.fromOffset(0, 315),
    UDim2.new(1, 0, 0, 40),
    C.Green
)

local AutoBuyButton = Button(
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

local BuyDelayButton = Button(
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

    ClearList(ItemList)

    local query = Search.Text:lower()
    local count = 0

    for _, item in ipairs(Items) do

        if item.Name:lower():find(query, 1, true) then

            count += 1

            local price = item.Price ~= nil
                and tostring(item.Price)
                or "Price N/A"

            local entry = Button(
                item.Name .. " | " .. price,
                ItemList,
                UDim2.new(),
                UDim2.new(1, -2, 0, 36),
                Selected == item and C.Purple or C.Button
            )

            entry.TextXAlignment = Enum.TextXAlignment.Left
            entry.TextTruncate = Enum.TextTruncate.AtEnd

            entry.MouseButton1Click:Connect(function()

                Selected = item

                SelectedLabel.Text =
                    "Selected: " .. item.Name .. " | " .. price

                RenderItems()

            end)

        end

    end

    if count == 0 then

        Label(
            "No items found",
            ItemList,
            UDim2.new(),
            UDim2.new(1, 0, 0, 40),
            14
        ).Name = "EmptyLabel"

    end

end

local function RefreshItems()

    local previous = Selected and Selected.Name

    Items = ScanItems()
    Selected = nil

    for _, item in ipairs(Items) do

        if item.Name == previous then
            Selected = item
            break
        end

    end

    SelectedLabel.Text = Selected
        and ("Selected: " .. Selected.Name)
        or "Selected: None"

    RenderItems()

    Notify("Item Buyer", "Found " .. #Items .. " items")

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

    local remote = GetRemote("BuyItemCash", "RemoteEvent")

    if not remote then
        Notify("Buyer", "BuyItemCash unavailable")
        return
    end

    if Selected.Price == nil then
        Notify("Buyer", "Price unavailable")
        return
    end

    local balance = GetBalance()

    if balance ~= nil and balance < Selected.Price then
        Notify("Buyer", "Not enough currency")
        return
    end

    if os.clock() - LastBuy < Config.BuyCooldown then
        return
    end

    Buying = true
    LastBuy = os.clock()

    local name = Selected.Name

    local ok, err = pcall(function()
        remote:FireServer(name)
    end)

    Buying = false

    if ok then
        Notify("Purchase Request Sent", name)
    else
        Notify("Purchase Error", tostring(err))
    end

end

BuyButton.MouseButton1Click:Connect(function()
    task.spawn(BuyItem)
end)

AutoBuyButton.MouseButton1Click:Connect(function()

    AutoBuy = not AutoBuy

    AutoBuyButton.Text = AutoBuy
        and "AUTO BUY: ON"
        or "AUTO BUY: OFF"

    AutoBuyButton.BackgroundColor3 = AutoBuy
        and C.Green or C.Button

end)

task.spawn(function()

    while Running do

        if AutoBuy and Selected then
            BuyItem()
        end

        task.wait(Config.AutoBuyDelay)

    end

end)

BuyDelayButton.MouseButton1Click:Connect(function()

    Config.AutoBuyDelay += 1

    if Config.AutoBuyDelay > 10 then
        Config.AutoBuyDelay = 1
    end

    BuyDelayButton.Text =
        "DELAY: " .. Config.AutoBuyDelay .. "s"

end)

RefreshButton.MouseButton1Click:Connect(RefreshItems)
Search:GetPropertyChangedSignal("Text"):Connect(RenderItems)

--------------------------------------------------
-- REWARDS PAGE
--------------------------------------------------

local Rewards = Pages.REWARDS

Label(
    "WHEEL OF FORTUNE\n\nClaim your available prize.",
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

    local remote = GetRemote("ClaimPrize", "RemoteFunction")

    if not remote then
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
            return remote:InvokeServer()
        end)

        ClaimBusy = false
        ClaimButton.Text = "CLAIM WHEEL PRIZE"

        if ok then
            Notify("Wheel Response", tostring(result))
        else
            Notify("Wheel Error", tostring(result))
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

    local remote = GetRemote("RequestCode", "RemoteEvent")

    if not remote then
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
        remote:FireServer(code)
    end)

    if ok then
        Notify("Code Request Sent", code)
    else
        Notify("Code Error", tostring(err))
    end

end)

--------------------------------------------------
-- FIND GAME CODES
--------------------------------------------------

local function FindGameCodes()

    local results = {}
    local seen = {}

    for _, obj in ipairs(RS:GetDescendants()) do

        local name = obj.Name:lower()

        local matches =
            name:find("code", 1, true)
            or name:find("promo", 1, true)
            or name:find("redeem", 1, true)

        if matches then

            local candidates = {obj}

            for _, child in ipairs(obj:GetChildren()) do
                table.insert(candidates, child)
            end

            for _, candidate in ipairs(candidates) do

                if candidate:IsA("StringValue") then

                    local value = candidate.Value

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

local FindCodesButton = Button(
    "FIND GAME CODES",
    Codes,
    UDim2.fromOffset(0, 145),
    UDim2.new(1, 0, 0, 38),
    C.Green
)

local FoundList = MakeList(
    Codes,
    UDim2.fromOffset(0, 195),
    UDim2.new(1, 0, 0, 175)
)

local function RenderFoundCodes()

    ClearList(FoundList)

    if #FoundCodes == 0 then

        Label(
            "No possible codes found",
            FoundList,
            UDim2.new(),
            UDim2.new(1, 0, 0, 40),
            13
        ).Name = "EmptyLabel"

    end

    for _, code in ipairs(FoundCodes) do

        local entry = Button(
            code,
            FoundList,
            UDim2.new(),
            UDim2.new(1, -2, 0, 34),
            SelectedFoundCode == code and C.Purple or C.Button
        )

        entry.MouseButton1Click:Connect(function()

            SelectedFoundCode = code
            CodeBox.Text = code

            RenderFoundCodes()

        end)

    end

end

FindCodesButton.MouseButton1Click:Connect(function()

    FoundCodes = FindGameCodes()
    SelectedFoundCode = nil

    RenderFoundCodes()

    Notify(
        "Code Finder",
        "Found " .. #FoundCodes .. " possible codes"
    )

end)

local CopyCodeButton = Button(
    "COPY SELECTED CODE",
    Codes,
    UDim2.fromOffset(0, 380),
    UDim2.new(1, 0, 0, 38),
    C.Purple
)

CopyCodeButton.MouseButton1Click:Connect(function()

    if not SelectedFoundCode then
        Notify("Codes", "Select a code")
        return
    end

    if type(setclipboard) == "function" then

        local ok = pcall(function()
            setclipboard(SelectedFoundCode)
        end)

        Notify(
            "Codes",
            ok and "Code copied" or "Copy failed"
        )

    else

        Notify("Codes", "Clipboard unavailable")

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

local CreateCodeButton = Button(
    "CREATE LOCAL CODE",
    Custom,
    UDim2.fromOffset(0, 155),
    UDim2.new(1, 0, 0, 40),
    C.Green
)

local CustomList = MakeList(
    Custom,
    UDim2.fromOffset(0, 205),
    UDim2.new(1, 0, 0, 200)
)

--------------------------------------------------
-- LOCAL STORAGE
--------------------------------------------------

local function SaveCodes()

    if type(writefile) ~= "function" then
        return
    end

    pcall(function()

        writefile(
            Config.SaveFile,
            HttpService:JSONEncode(CustomCodes)
        )

    end)

end

local function LoadCodes()

    if type(readfile) ~= "function"
    or type(isfile) ~= "function" then
        return
    end

    pcall(function()

        if isfile(Config.SaveFile) then

            local decoded = HttpService:JSONDecode(
                readfile(Config.SaveFile)
            )

            if type(decoded) == "table" then
                CustomCodes = decoded
            end

        end

    end)

end

local RenderCustomCodes

RenderCustomCodes = function()

    ClearList(CustomList)

    for index, entry in ipairs(CustomCodes) do

        if type(entry) == "table" then

            local row = New("Frame", {
                Size = UDim2.new(1, -2, 0, 45),
                BackgroundColor3 = C.Button,
                BorderSizePixel = 0
            }, CustomList)

            Round(row, 7)

            local text = Label(
                tostring(entry.Code) .. " -> " .. tostring(entry.Reward),
                row,
                UDim2.fromOffset(8, 0),
                UDim2.new(1, -100, 1, 0),
                12
            )

            text.TextXAlignment = Enum.TextXAlignment.Left
            text.TextTruncate = Enum.TextTruncate.AtEnd

            local Delete = Button(
                "DELETE",
                row,
                UDim2.new(1, -85, 0, 6),
                UDim2.fromOffset(78, 33),
                C.Red
            )

            Delete.MouseButton1Click:Connect(function()

                table.remove(CustomCodes, index)

                SaveCodes()
                RenderCustomCodes()

                Notify("Custom Codes", "Code deleted")

            end)

        end

    end

end

CreateCodeButton.MouseButton1Click:Connect(function()

    local code = Trim(CustomCodeBox.Text)
    local reward = Trim(RewardBox.Text)

    if code == "" or reward == "" then
        Notify("Custom Codes", "Fill both fields")
        return
    end

    for _, entry in ipairs(CustomCodes) do

        if type(entry) == "table"
        and tostring(entry.Code):lower() == code:lower() then

            Notify("Custom Codes", "Code already exists")
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

    Notify("Custom Codes", "Local code created")

end)

--------------------------------------------------
-- PINATA PAGE
--------------------------------------------------

local Pinata = Pages.PINATA

Label(
    "PINATA AUTO HIT",
    Pinata,
    UDim2.fromOffset(0, 10),
    UDim2.new(1, 0, 0, 45),
    20
)

Label(
    "Hit the pinata using the game's HitPinata event.",
    Pinata,
    UDim2.fromOffset(10, 60),
    UDim2.new(1, -20, 0, 55),
    13
)

--------------------------------------------------
-- HIT BUTTON
--------------------------------------------------

local HitButton = Button(
    "HIT",
    Pinata,
    UDim2.fromOffset(0, 130),
    UDim2.new(1, 0, 0, 50),
    C.Green
)

--------------------------------------------------
-- AUTO HIT BUTTON
--------------------------------------------------

local AutoHitButton = Button(
    "AUTO HIT: OFF",
    Pinata,
    UDim2.fromOffset(0, 195),
    UDim2.new(1, 0, 0, 45),
    C.Button
)

--------------------------------------------------
-- DELAY
--------------------------------------------------

local DelayLabel = Label(
    "HIT DELAY: 100 ms",
    Pinata,
    UDim2.fromOffset(0, 255),
    UDim2.new(1, 0, 0, 35),
    15
)

local DelayDown = Button(
    "-25 ms",
    Pinata,
    UDim2.fromOffset(0, 300),
    UDim2.new(0.48, 0, 0, 40),
    C.Purple
)

local DelayUp = Button(
    "+25 ms",
    Pinata,
    UDim2.new(0.52, 0, 0, 300),
    UDim2.new(0.48, 0, 0, 40),
    C.Purple
)

local function UpdateDelay()

    DelayLabel.Text =
        "HIT DELAY: " .. Config.HitDelayMS .. " ms"

end

DelayDown.MouseButton1Click:Connect(function()

    Config.HitDelayMS = math.max(
        0,
        Config.HitDelayMS - 25
    )

    UpdateDelay()

end)

DelayUp.MouseButton1Click:Connect(function()

    Config.HitDelayMS = math.min(
        100,
        Config.HitDelayMS + 25
    )

    UpdateDelay()

end)

--------------------------------------------------
-- HIT COUNTER
--------------------------------------------------

local HitCounter = Label(
    "Requests sent: 0",
    Pinata,
    UDim2.fromOffset(0, 355),
    UDim2.new(1, 0, 0, 40),
    15
)

--------------------------------------------------
-- HIT FUNCTION
--------------------------------------------------

local LastHit = 0

local function HitPinata()

    if not Running or HitBusy then
        return false
    end

    local delaySeconds = math.max(
        Config.HitDelayMS / 1000,
        Config.MinActualHitDelay
    )

    if os.clock() - LastHit < delaySeconds then
        return false
    end

    local remote = GetPinataRemote()

    if not remote then

        Notify(
            "Pinata",
            "HitPinata RemoteEvent not found"
        )

        AutoHit = false
        return false

    end

    HitBusy = true
    LastHit = os.clock()

    local ok, err = pcall(function()

        remote:FireServer()

    end)

    HitBusy = false

    if ok then

        HitCount += 1

        HitCounter.Text =
            "Requests sent: " .. HitCount

        return true

    else

        Notify(
            "Pinata Error",
            tostring(err)
        )

        AutoHit = false
        return false

    end

end

--------------------------------------------------
-- MANUAL HIT
--------------------------------------------------

HitButton.MouseButton1Click:Connect(function()

    HitPinata()

end)

--------------------------------------------------
-- AUTO HIT
--------------------------------------------------

local function UpdateAutoHitButton()

    AutoHitButton.Text = AutoHit
        and "AUTO HIT: ON"
        or "AUTO HIT: OFF"

    AutoHitButton.BackgroundColor3 = AutoHit
        and C.Green
        or C.Button

end

AutoHitButton.MouseButton1Click:Connect(function()

    AutoHit = not AutoHit

    UpdateAutoHitButton()

    Notify(
        "Pinata",
        AutoHit and "Auto Hit enabled"
        or "Auto Hit disabled"
    )

end)

task.spawn(function()

    while Running do

        if AutoHit then

            HitPinata()

            UpdateAutoHitButton()

        end

        task.wait(Config.MinActualHitDelay)

    end

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
    "POP IT ULTIMATE V7",
    "Hub loaded successfully!"
)

print("[POP IT ULTIMATE V7] Loaded")
