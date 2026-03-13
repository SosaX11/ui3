-- Services 
local InputService  = game:GetService("UserInputService")
local HttpService   = game:GetService("HttpService")
local GuiService    = game:GetService("GuiService")
local RunService    = game:GetService("RunService")
local CoreGui       = game:GetService("CoreGui")
local TweenService  = game:GetService("TweenService")
local Workspace     = game:GetService("Workspace")
local Players       = game:GetService("Players")

local lp            = Players.LocalPlayer
local mouse         = lp:GetMouse()

-- Short aliases
local vec2          = Vector2.new
local dim2          = UDim2.new
local dim           = UDim.new
local rect          = Rect.new
local dim_offset    = UDim2.fromOffset
local rgb           = Color3.fromRGB
local hex           = Color3.fromHex

-- Library init / globals
getgenv().StackHub = getgenv().StackHub or {}
local StackHub = getgenv().StackHub

StackHub.Directory    = "StackHub"
StackHub.Folders      = {"/configs"}
StackHub.Flags        = {}
StackHub.ConfigFlags  = {}
StackHub.Connections  = {}
StackHub.DynamicTheming = {} 
StackHub.Notifications= {Notifs = {}}
StackHub.__index      = StackHub

local Flags          = StackHub.Flags
local ConfigFlags    = StackHub.ConfigFlags
local Notifications  = StackHub.Notifications

local themes = {
    preset = {
        accent       = rgb(70, 150, 255),    -- Neon electric blue
        glow         = rgb(70, 150, 255),    -- Matching glow
        
        background   = rgb(10, 12, 18),      -- Deep dark navy background
        sidebar      = rgb(14, 18, 26),      -- Slightly brighter sidebar
        section      = rgb(20, 24, 34),      -- Card sections
        element      = rgb(28, 32, 44),      -- UI element base
        element_hover= rgb(38, 44, 58),      -- Hover highlight
        
        outline      = rgb(48, 58, 74),      -- Soft blue-gray outline
        text         = rgb(255, 255, 255),   -- Primary text
        subtext      = rgb(140, 155, 180),   -- Muted blue-gray text
        
        tab_active   = rgb(255, 255, 255),   -- Active tab
        tab_inactive = rgb(120, 135, 160),   -- Inactive tab
    },
    utility = {}
}

for property, _ in themes.preset do
    themes.utility[property] = {
        BackgroundColor3 = {}, TextColor3 = {}, ImageColor3 = {}, Color = {}, ScrollBarImageColor3 = {}
    }
end

local Keys = {
    [Enum.KeyCode.LeftShift] = "LS", [Enum.KeyCode.RightShift] = "RS",
    [Enum.KeyCode.LeftControl] = "LC", [Enum.KeyCode.RightControl] = "RC",
    [Enum.KeyCode.Insert] = "INS", [Enum.KeyCode.Backspace] = "BS",
    [Enum.KeyCode.Return] = "Ent", [Enum.KeyCode.Escape] = "ESC",
    [Enum.KeyCode.Space] = "SPC", [Enum.UserInputType.MouseButton1] = "MB1",
    [Enum.UserInputType.MouseButton2] = "MB2", [Enum.UserInputType.MouseButton3] = "MB3"
}

for _, path in StackHub.Folders do
    pcall(function() makefolder(StackHub.Directory .. path) end)
end

-- 🌟 Sexy Tween Helper
function StackHub:Tween(Object, Properties, Info)
    if not Object then return end
    local tween = TweenService:Create(Object, Info or TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), Properties)
    tween:Play()
    return tween
end

-- Component Builder
function StackHub:Create(instance, options)
    local ins = Instance.new(instance)
    for prop, value in options do ins[prop] = value end
    if ins:IsA("TextButton") or ins:IsA("ImageButton") then ins.AutoButtonColor = false end
    return ins
end

-- Hover Effect Builder (Micro-interactions)
function StackHub:AddHover(element, targetColor, originalColor)
    element.MouseEnter:Connect(function()
        StackHub:Tween(element, {BackgroundColor3 = targetColor}, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
    end)
    element.MouseLeave:Connect(function()
        StackHub:Tween(element, {BackgroundColor3 = originalColor}, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
    end)
end

-- Click Pop Effect
function StackHub:AddPop(element, scaleFactor)
    scaleFactor = scaleFactor or 0.96
    local originalSize = element.Size
    element.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            StackHub:Tween(element, {Size = dim2(originalSize.X.Scale, originalSize.X.Offset * scaleFactor, originalSize.Y.Scale, originalSize.Y.Offset * scaleFactor)}, TweenInfo.new(0.15, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out))
        end
    end)
    element.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            StackHub:Tween(element, {Size = originalSize}, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out))
        end
    end)
end

function StackHub:Themify(instance, theme, property)
    if not themes.utility[theme] then return end
    table.insert(themes.utility[theme][property], instance)
    instance[property] = themes.preset[theme]
end

function StackHub:RefreshTheme(theme, color3)
    themes.preset[theme] = color3
    for property, instances in themes.utility[theme] do
        for _, object in instances do object[property] = color3 end
    end
    for _, updateFunc in ipairs(StackHub.DynamicTheming) do updateFunc() end
end

function StackHub:Resizify(Parent)
    local Resizing = StackHub:Create("TextButton", {
        AnchorPoint = vec2(1, 1), Position = dim2(1, 0, 1, 0), Size = dim2(0, 20, 0, 20),
        BorderSizePixel = 0, BackgroundTransparency = 1, Text = "", Parent = Parent, ZIndex = 999,
    })
    
    StackHub:Create("ImageLabel", {
        Parent = Resizing, AnchorPoint = vec2(1, 1), Position = dim2(1, -6, 1, -6), Size = dim2(0, 10, 0, 10),
        BackgroundTransparency = 1, Image = "rbxthumb://type=Asset&id=6153965706&w=150&h=150", ImageColor3 = themes.preset.subtext, ImageTransparency = 0.5
    })

    local IsResizing, StartInputPos, StartSize = false, nil, nil
    local MIN_SIZE = vec2(750, 500)
    local MAX_SIZE = vec2(1200, 900)

    Resizing.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            IsResizing = true; StartInputPos = input.Position; StartSize = Parent.AbsoluteSize
        end
    end)
    Resizing.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then IsResizing = false end
    end)
    InputService.InputChanged:Connect(function(input)
        if not IsResizing then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - StartInputPos
            Parent.Size = UDim2.fromOffset(math.clamp(StartSize.X + delta.X, MIN_SIZE.X, MAX_SIZE.X), math.clamp(StartSize.Y + delta.Y, MIN_SIZE.Y, MAX_SIZE.Y))
        end
    end)
end

-- Main Window
function StackHub:Window(properties)
    local Cfg = {
        Title = properties.Title or properties.title or properties.Prefix or "StackHub", 
        Subtitle = properties.Subtitle or properties.subtitle or properties.Suffix or ".cc",
        Size = properties.Size or properties.size or dim2(0, 850, 0, 550), 
        TabInfo = nil, Items = {}, Tweening = false, IsSwitchingTab = false;
    }

    if StackHub.Gui then StackHub.Gui:Destroy() end
    if StackHub.Other then StackHub.Other:Destroy() end
    if StackHub.ToggleGui then StackHub.ToggleGui:Destroy() end

    StackHub.Gui = StackHub:Create("ScreenGui", { Parent = CoreGui, Name = "StackHub", Enabled = true, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
    StackHub.Other = StackHub:Create("ScreenGui", { Parent = CoreGui, Name = "ExternalOther", Enabled = false, IgnoreGuiInset = true })
    
    local Items = Cfg.Items
    local uiVisible = true

    Items.Wrapper = StackHub:Create("Frame", {
        Parent = StackHub.Gui, Position = dim2(0.5, -Cfg.Size.X.Offset / 2, 0.5, -Cfg.Size.Y.Offset / 2),
        Size = Cfg.Size, BackgroundTransparency = 1, BorderSizePixel = 0
    })
    
    -- Main Glow
    Items.Glow = StackHub:Create("ImageLabel", {
        ImageColor3 = themes.preset.glow, ScaleType = Enum.ScaleType.Slice, ImageTransparency = 0.45,
        Parent = Items.Wrapper, Size = dim2(1, 60, 1, 60), Image = "rbxassetid://18245826428",
        BackgroundTransparency = 1, Position = dim2(0, -30, 0, -30), BorderSizePixel = 0,
        SliceCenter = rect(vec2(21, 21), vec2(79, 79)), ZIndex = 0
    })
    StackHub:Themify(Items.Glow, "glow", "ImageColor3")

    -- Window Background
    Items.Window = StackHub:Create("Frame", {
        Parent = Items.Wrapper, Size = dim2(1, 0, 1, 0), BackgroundColor3 = themes.preset.background, BorderSizePixel = 0, ZIndex = 1
    })
    StackHub:Themify(Items.Window, "background", "BackgroundColor3")
    StackHub:Create("UICorner", { Parent = Items.Window, CornerRadius = dim(0, 12) }) -- Increased CornerRadius
    StackHub:Themify(StackHub:Create("UIStroke", { Parent = Items.Window, Color = themes.preset.outline, Thickness = 1 }), "outline", "Color")

    -- Sidebar
    Items.Sidebar = StackHub:Create("Frame", {
        Parent = Items.Window, Size = dim2(0, 220, 1, 0), BackgroundColor3 = themes.preset.sidebar, BorderSizePixel = 0, ZIndex = 2, ClipsDescendants = true
    })
    StackHub:Themify(Items.Sidebar, "sidebar", "BackgroundColor3")
    StackHub:Create("UICorner", { Parent = Items.Sidebar, CornerRadius = dim(0, 12) })
    
    -- Hide right-side corner of sidebar to blend into main content
    StackHub:Themify(StackHub:Create("Frame", {
        Parent = Items.Sidebar, AnchorPoint = vec2(1, 0), Position = dim2(1, 0, 0, 0), Size = dim2(0, 10, 1, 0), 
        BackgroundColor3 = themes.preset.sidebar, BorderSizePixel = 0, ZIndex = 2
    }), "sidebar", "BackgroundColor3")
    
    -- Sidebar subtle border divider (Now using an alpha fading gradient for modern look)
    local SidebarLine = StackHub:Create("Frame", {
        Parent = Items.Sidebar, AnchorPoint = vec2(1, 0), Position = dim2(1, 0, 0, 0), Size = dim2(0, 1, 1, 0), 
        BackgroundColor3 = themes.preset.outline, BorderSizePixel = 0, ZIndex = 3
    })
    StackHub:Themify(SidebarLine, "outline", "BackgroundColor3")
    StackHub:Create("UIGradient", {
        Parent = SidebarLine, Rotation = 90, Transparency = ColorSequence.new({
            ColorSequenceKeypoint.new(0, 1), ColorSequenceKeypoint.new(0.2, 0),
            ColorSequenceKeypoint.new(0.8, 0), ColorSequenceKeypoint.new(1, 1)
        })
    })

    -- Header (Titles shifted slightly to the left)
    Items.SideHeader = StackHub:Create("Frame", { Parent = Items.Sidebar, Size = dim2(1, 0, 0, 80), BackgroundTransparency = 1, Active = true, ZIndex = 4 })
    
    Items.LogoBlock = StackHub:Create("Frame", { Parent = Items.SideHeader, AnchorPoint = vec2(0, 0.5), Position = dim2(0, 18, 0.5, 0), Size = dim2(0, 24, 0, 24), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4 })
    StackHub:Create("UICorner", { Parent = Items.LogoBlock, CornerRadius = dim(0, 6) })
    StackHub:Themify(Items.LogoBlock, "accent", "BackgroundColor3")

    Items.LogoText = StackHub:Create("TextLabel", {
        Parent = Items.SideHeader, Text = Cfg.Title, TextColor3 = themes.preset.text, AnchorPoint = vec2(0, 0), Position = dim2(0, 52, 0, 24), Size = dim2(0, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.ExtraBold), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4
    })
    StackHub:Themify(Items.LogoText, "text", "TextColor3")

    Items.SubLogoText = StackHub:Create("TextLabel", {
        Parent = Items.SideHeader, Text = Cfg.Subtitle, TextColor3 = themes.preset.accent, AnchorPoint = vec2(0, 0), Position = dim2(0, 52, 0, 44), Size = dim2(0, 0, 0, 12), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4
    })
    StackHub:Themify(Items.SubLogoText, "accent", "TextColor3")

    -- Tabs Holder
    Items.TabHolder = StackHub:Create("ScrollingFrame", { 
        Parent = Items.Sidebar, Position = dim2(0, 0, 0, 80), Size = dim2(1, 0, 1, -160), 
        BackgroundTransparency = 1, ScrollBarThickness = 0, ZIndex = 4 
    })
    StackHub:Create("UIListLayout", { Parent = Items.TabHolder, Padding = dim(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center })
    StackHub:Create("UIPadding", { Parent = Items.TabHolder, PaddingTop = dim(0, 10), PaddingLeft = dim(0, 16), PaddingRight = dim(0, 16) })

    -- Footer (Items shifted left)
    Items.Footer = StackHub:Create("Frame", { 
        Parent = Items.Sidebar, AnchorPoint = vec2(0, 1), Position = dim2(0, 0, 1, 0), 
        Size = dim2(1, 0, 0, 80), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4 
    })
    
    local headshot = "rbxthumb://type=AvatarHeadShot&id="..lp.UserId.."&w=48&h=48"
    Items.AvatarFrame = StackHub:Create("Frame", { Parent = Items.Footer, AnchorPoint = vec2(0, 0.5), Position = dim2(0, 18, 0.5, 0), Size = dim2(0, 36, 0, 36), BackgroundColor3 = themes.preset.element, BorderSizePixel = 0, ZIndex = 5 })
    StackHub:Themify(Items.AvatarFrame, "element", "BackgroundColor3")
    StackHub:Create("UICorner", { Parent = Items.AvatarFrame, CornerRadius = dim(1, 0) }) -- Circle avatar
    
    Items.Avatar = StackHub:Create("ImageLabel", { Parent = Items.AvatarFrame, AnchorPoint = vec2(0.5, 0.5), Position = dim2(0.5, 0, 0.5, 0), Size = dim2(1, 0, 1, 0), BackgroundTransparency = 1, Image = headshot, ZIndex = 6 })
    StackHub:Create("UICorner", { Parent = Items.Avatar, CornerRadius = dim(1, 0) })

    Items.Username = StackHub:Create("TextLabel", {
        Parent = Items.Footer, Text = lp.Name, TextColor3 = themes.preset.text, AnchorPoint = vec2(0, 0), Position = dim2(0, 64, 0, 24), Size = dim2(0, 100, 0, 16),
        BackgroundTransparency = 1, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5
    })
    StackHub:Themify(Items.Username, "text", "TextColor3")

    Items.Status = StackHub:Create("TextLabel", {
        Parent = Items.Footer, Text = "Premium", TextColor3 = themes.preset.accent, AnchorPoint = vec2(0, 0), Position = dim2(0, 64, 0, 42), Size = dim2(0, 100, 0, 12),
        BackgroundTransparency = 1, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5
    })
    StackHub:Themify(Items.Status, "accent", "TextColor3")

    Items.SettingsBtn = StackHub:Create("ImageButton", {
        Parent = Items.Footer, AnchorPoint = vec2(1, 0.5), Position = dim2(1, -20, 0.5, 0), Size = dim2(0, 20, 0, 20), BackgroundTransparency = 1, Image = "rbxassetid://11293977610", ImageColor3 = themes.preset.subtext, ZIndex = 5
    })
    StackHub:Themify(Items.SettingsBtn, "subtext", "ImageColor3")
    
    Items.SettingsBtn.MouseButton1Click:Connect(function()
        if Cfg.SettingsTabOpen then Cfg.SettingsTabOpen() end
    end)
    Items.SettingsBtn.MouseEnter:Connect(function() StackHub:Tween(Items.SettingsBtn, {ImageColor3 = themes.preset.text, Rotation = 45}, TweenInfo.new(0.3, Enum.EasingStyle.Back)) end)
    Items.SettingsBtn.MouseLeave:Connect(function() StackHub:Tween(Items.SettingsBtn, {ImageColor3 = themes.preset.subtext, Rotation = 0}, TweenInfo.new(0.3, Enum.EasingStyle.Back)) end)

    -- Main Content Area
    Items.MainContent = StackHub:Create("Frame", {
        Parent = Items.Window, Position = dim2(0, 220, 0, 0), Size = dim2(1, -220, 1, 0), BackgroundTransparency = 1, ZIndex = 2
    })

    -- Drag Logic
    local Dragging, DragStart, StartPos
    local function initDrag(element)
        element.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                Dragging = true; DragStart = input.Position; StartPos = Items.Wrapper.Position
            end
        end)
        element.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then Dragging = false end
        end)
    end
    initDrag(Items.SideHeader)
    
    Items.ContentHeader = StackHub:Create("Frame", { Parent = Items.MainContent, Size = dim2(1, 0, 0, 80), BackgroundTransparency = 1, Active = true })
    initDrag(Items.ContentHeader)

    -- Tab Title shifted to the left (from 36 to 24)
    Items.CurrentTabTitle = StackHub:Create("TextLabel", {
        Parent = Items.ContentHeader, Text = "Dashboard", TextColor3 = themes.preset.text, AnchorPoint = vec2(0, 0.5), Position = dim2(0, 24, 0.5, 0), Size = dim2(0.5, 0, 0, 30),
        BackgroundTransparency = 1, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.ExtraBold), TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left
    })
    StackHub:Themify(Items.CurrentTabTitle, "text", "TextColor3")

    InputService.InputChanged:Connect(function(input)
        if Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - DragStart
            Items.Wrapper.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
        end
    end)
    StackHub:Resizify(Items.Wrapper)

    Items.PageHolder = StackHub:Create("Frame", { 
        Parent = Items.MainContent, Position = dim2(0, 0, 0, 80), Size = dim2(1, 0, 1, -80), BackgroundTransparency = 1, ClipsDescendants = true 
    })

    function Cfg.ToggleMenu(bool)
        if Cfg.Tweening then return end
        if bool == nil then uiVisible = not uiVisible else uiVisible = bool end
        Items.Wrapper.Visible = uiVisible
    end

    return setmetatable(Cfg, StackHub)
end

-- Tabs
function StackHub:Tab(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Tab", 
        Icon = properties.Icon or properties.icon or "11293977610", 
        Hidden = properties.Hidden or properties.hidden or false, 
        Items = {} 
    }
    if tonumber(Cfg.Icon) then Cfg.Icon = "rbxassetid://" .. tostring(Cfg.Icon) end
    local Items = Cfg.Items

    if not Cfg.Hidden then
        -- Tab Pill
        Items.Button = StackHub:Create("TextButton", { 
            Parent = self.Items.TabHolder, Size = dim2(1, 0, 0, 40), BackgroundColor3 = themes.preset.accent, 
            BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 5 
        })
        StackHub:Themify(Items.Button, "accent", "BackgroundColor3")
        StackHub:Create("UICorner", { Parent = Items.Button, CornerRadius = dim(0, 8) })

        Items.IconImg = StackHub:Create("ImageLabel", { 
            Parent = Items.Button, AnchorPoint = vec2(0, 0.5), Position = dim2(0, 12, 0.5, 0),
            Size = dim2(0, 18, 0, 18), BackgroundTransparency = 1, Image = Cfg.Icon, ImageColor3 = themes.preset.tab_inactive, ZIndex = 6 
        })
        StackHub:Themify(Items.IconImg, "tab_inactive", "ImageColor3")

        Items.Title = StackHub:Create("TextLabel", {
            Parent = Items.Button, AnchorPoint = vec2(0, 0.5), Position = dim2(0, 40, 0.5, 0), Size = dim2(1, -44, 1, 0),
            BackgroundTransparency = 1, Text = Cfg.Name, TextColor3 = themes.preset.tab_inactive, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6
        })
        StackHub:Themify(Items.Title, "tab_inactive", "TextColor3")

        -- Hover on inactive tabs
        Items.Button.MouseEnter:Connect(function()
            if self.TabInfo ~= Cfg.Items then
                StackHub:Tween(Items.Button, {BackgroundTransparency = 0.95}, TweenInfo.new(0.2))
                StackHub:Tween(Items.Title, {TextColor3 = themes.preset.text}, TweenInfo.new(0.2))
                StackHub:Tween(Items.IconImg, {ImageColor3 = themes.preset.text}, TweenInfo.new(0.2))
            end
        end)
        Items.Button.MouseLeave:Connect(function()
            if self.TabInfo ~= Cfg.Items then
                StackHub:Tween(Items.Button, {BackgroundTransparency = 1}, TweenInfo.new(0.2))
                StackHub:Tween(Items.Title, {TextColor3 = themes.preset.tab_inactive}, TweenInfo.new(0.2))
                StackHub:Tween(Items.IconImg, {ImageColor3 = themes.preset.tab_inactive}, TweenInfo.new(0.2))
            end
        end)
    end

    Items.Pages = StackHub:Create("CanvasGroup", { Parent = StackHub.Other, Size = dim2(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, GroupTransparency = 1 })
    StackHub:Create("UIListLayout", { Parent = Items.Pages, FillDirection = Enum.FillDirection.Horizontal, Padding = dim(0, 24) })
    StackHub:Create("UIPadding", { Parent = Items.Pages, PaddingTop = dim(0, 5), PaddingBottom = dim(0, 20), PaddingRight = dim(0, 36), PaddingLeft = dim(0, 36) })

    Items.Left = StackHub:Create("ScrollingFrame", { 
        Parent = Items.Pages, Size = dim2(0.5, -12, 1, 0), BackgroundTransparency = 1, 
        ScrollBarThickness = 0, CanvasSize = dim2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y
    })
    StackHub:Create("UIListLayout", { Parent = Items.Left, Padding = dim(0, 18) })
    StackHub:Create("UIPadding", { Parent = Items.Left, PaddingBottom = dim(0, 10) })

    Items.Right = StackHub:Create("ScrollingFrame", { 
        Parent = Items.Pages, Size = dim2(0.5, -12, 1, 0), BackgroundTransparency = 1, 
        ScrollBarThickness = 0, CanvasSize = dim2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y
    })
    StackHub:Create("UIListLayout", { Parent = Items.Right, Padding = dim(0, 18) })
    StackHub:Create("UIPadding", { Parent = Items.Right, PaddingBottom = dim(0, 10) })

    function Cfg.OpenTab()
        if self.IsSwitchingTab or self.TabInfo == Cfg.Items then return end
        local oldTab = self.TabInfo
        self.IsSwitchingTab = true
        self.TabInfo = Cfg.Items

        if not Cfg.Hidden then
            self.Items.CurrentTabTitle.Text = Cfg.Name
            self.Items.CurrentTabTitle.Position = dim2(0, 14, 0.5, 0) -- Starts slightly further left
            self.Items.CurrentTabTitle.TextTransparency = 1
            -- Sweeps rightwards to rest at `24`
            StackHub:Tween(self.Items.CurrentTabTitle, {Position = dim2(0, 24, 0.5, 0), TextTransparency = 0}, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
        else
            self.Items.CurrentTabTitle.Text = "Settings"
        end

        local buttonTween = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

        if oldTab and oldTab.Button then
            StackHub:Tween(oldTab.Button, {BackgroundTransparency = 1}, buttonTween)
            StackHub:Tween(oldTab.IconImg, {ImageColor3 = themes.preset.tab_inactive}, buttonTween)
            StackHub:Tween(oldTab.Title, {TextColor3 = themes.preset.tab_inactive}, buttonTween)
        end

        if Items.Button then 
            StackHub:Tween(Items.Button, {BackgroundTransparency = 0}, buttonTween)
            StackHub:Tween(Items.IconImg, {ImageColor3 = rgb(255, 255, 255)}, buttonTween) 
            StackHub:Tween(Items.Title, {TextColor3 = rgb(255, 255, 255)}, buttonTween) 
        end
        
        task.spawn(function()
            if oldTab then
                StackHub:Tween(oldTab.Pages, {GroupTransparency = 1, Position = dim2(0, 0, 0, 15)}, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
                task.wait(0.2)
                oldTab.Pages.Visible = false
                oldTab.Pages.Parent = StackHub.Other
            end

            Items.Pages.Position = dim2(0, 0, 0, 15) 
            Items.Pages.GroupTransparency = 1
            Items.Pages.Parent = self.Items.PageHolder
            Items.Pages.Visible = true

            StackHub:Tween(Items.Pages, {GroupTransparency = 0, Position = dim2(0, 0, 0, 0)}, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out))
            task.wait(0.45)
            
            Items.Pages.GroupTransparency = 0 
            self.IsSwitchingTab = false
        end)
    end

    if Items.Button then StackHub:AddPop(Items.Button); Items.Button.MouseButton1Down:Connect(Cfg.OpenTab) end
    if not self.TabInfo and not Cfg.Hidden then Cfg.OpenTab() end
    return setmetatable(Cfg, StackHub)
end

-- Sections (Floating Cards)
function StackHub:Section(properties)
    local Cfg = { 
        Name = string.upper(properties.Name or properties.name or "Section"), 
        Side = properties.Side or properties.side or "Left", 
        Items = {} 
    }
    Cfg.Side = (Cfg.Side:lower() == "right") and "Right" or "Left"
    local Items = Cfg.Items

    Items.SectionBlock = StackHub:Create("Frame", { 
        Parent = self.Items[Cfg.Side], Size = dim2(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, 
        BackgroundTransparency = 1, BorderSizePixel = 0 
    })
    StackHub:Create("UIListLayout", { Parent = Items.SectionBlock, Padding = dim(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })

    -- Clean Uppercase Floating Header
    Items.Header = StackHub:Create("TextLabel", { 
        Parent = Items.SectionBlock, Size = dim2(1, 0, 0, 16), BackgroundTransparency = 1, 
        Text = Cfg.Name, TextColor3 = themes.preset.subtext, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left 
    })
    StackHub:Themify(Items.Header, "subtext", "TextColor3")
    StackHub:Create("UIPadding", { Parent = Items.Header, PaddingLeft = dim(0, 4) })

    Items.Container = StackHub:Create("Frame", { 
        Parent = Items.SectionBlock, Size = dim2(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, 
        BackgroundColor3 = themes.preset.section, BorderSizePixel = 0, ClipsDescendants = true 
    })
    StackHub:Themify(Items.Container, "section", "BackgroundColor3")
    StackHub:Create("UICorner", { Parent = Items.Container, CornerRadius = dim(0, 12) }) -- Modern rounding
    StackHub:Themify(StackHub:Create("UIStroke", { Parent = Items.Container, Color = themes.preset.outline, Thickness = 1 }), "outline", "Color")

    StackHub:Create("UIListLayout", { Parent = Items.Container, Padding = dim(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
    StackHub:Create("UIPadding", { Parent = Items.Container, PaddingTop = dim(0, 14), PaddingBottom = dim(0, 16), PaddingLeft = dim(0, 16), PaddingRight = dim(0, 16) })

    return setmetatable(Cfg, StackHub)
end

-- Toggles (Smooth iOS Pill)
function StackHub:Toggle(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Toggle", 
        Flag = properties.Flag or properties.flag, 
        Default = properties.Default or properties.default or false, 
        Callback = properties.Callback or properties.callback or function() end, 
        Items = {} 
    }
    local Items = Cfg.Items

    Items.Button = StackHub:Create("TextButton", { Parent = self.Items.Container, Size = dim2(1, 0, 0, 32), BackgroundTransparency = 1, Text = "" })
    
    Items.Title = StackHub:Create("TextLabel", { 
        Parent = Items.Button, Position = dim2(0, 0, 0.5, 0), AnchorPoint = vec2(0, 0.5), Size = dim2(1, -50, 1, 0), 
        BackgroundTransparency = 1, Text = Cfg.Name, TextColor3 = themes.preset.subtext, TextSize = 14, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold), TextXAlignment = Enum.TextXAlignment.Left 
    })

    Items.Pill = StackHub:Create("Frame", { 
        Parent = Items.Button, AnchorPoint = vec2(1, 0.5), Position = dim2(1, 0, 0.5, 0), Size = dim2(0, 44, 0, 24), 
        BackgroundColor3 = themes.preset.element, BorderSizePixel = 0 
    })
    StackHub:Create("UICorner", { Parent = Items.Pill, CornerRadius = dim(1, 0) })
    Items.PillStroke = StackHub:Create("UIStroke", { Parent = Items.Pill, Color = themes.preset.outline, Thickness = 1 })
    StackHub:Themify(Items.PillStroke, "outline", "Color")

    Items.Knob = StackHub:Create("Frame", {
        Parent = Items.Pill, AnchorPoint = vec2(0, 0.5), Position = dim2(0, 4, 0.5, 0), Size = dim2(0, 16, 0, 16),
        BackgroundColor3 = themes.preset.subtext, BorderSizePixel = 0
    })
    StackHub:Create("UICorner", { Parent = Items.Knob, CornerRadius = dim(1, 0) })
    -- Drop shadow
    StackHub:Create("ImageLabel", { Parent = Items.Knob, AnchorPoint = vec2(0.5, 0.5), Position = dim2(0.5, 0, 0.5, 2), Size = dim2(1, 12, 1, 12), BackgroundTransparency = 1, Image = "rbxassetid://6014261993", ImageColor3 = rgb(0,0,0), ImageTransparency = 0.5, ZIndex = -1 })

    local State = false
    function Cfg.set(bool)
        State = bool
        StackHub:Tween(Items.Pill, {BackgroundColor3 = State and themes.preset.accent or themes.preset.element}, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
        StackHub:Tween(Items.PillStroke, {Transparency = State and 1 or 0}, TweenInfo.new(0.2))
        StackHub:Tween(Items.Knob, {Position = State and dim2(1, -20, 0.5, 0) or dim2(0, 4, 0.5, 0), BackgroundColor3 = State and rgb(255,255,255) or themes.preset.subtext}, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
        StackHub:Tween(Items.Title, {TextColor3 = State and themes.preset.text or themes.preset.subtext}, TweenInfo.new(0.2))
        
        if Cfg.Flag then Flags[Cfg.Flag] = State end
        Cfg.Callback(State)
    end

    table.insert(StackHub.DynamicTheming, function()
        Items.Pill.BackgroundColor3 = State and themes.preset.accent or themes.preset.element
        Items.Title.TextColor3 = State and themes.preset.text or themes.preset.subtext
        Items.Knob.BackgroundColor3 = State and rgb(255,255,255) or themes.preset.subtext
    end)

    Items.Button.MouseButton1Click:Connect(function() Cfg.set(not State) end)
    
    Items.Button.MouseEnter:Connect(function() if not State then StackHub:Tween(Items.Title, {TextColor3 = themes.preset.text}, TweenInfo.new(0.2)) end end)
    Items.Button.MouseLeave:Connect(function() if not State then StackHub:Tween(Items.Title, {TextColor3 = themes.preset.subtext}, TweenInfo.new(0.2)) end end)

    if Cfg.Default then Cfg.set(true) end
    if Cfg.Flag then ConfigFlags[Cfg.Flag] = Cfg.set end

    return setmetatable(Cfg, StackHub)
end

-- Buttons (Sleek Gradient & Pop)
function StackHub:Button(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Button", 
        Callback = properties.Callback or properties.callback or function() end, 
        Items = {} 
    }
    local Items = Cfg.Items

    Items.Button = StackHub:Create("TextButton", { 
        Parent = self.Items.Container, Size = dim2(1, 0, 0, 36), BackgroundColor3 = themes.preset.element, 
        Text = Cfg.Name, TextColor3 = themes.preset.text, TextSize = 14, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold), AutoButtonColor = false 
    })
    StackHub:Themify(Items.Button, "element", "BackgroundColor3")
    StackHub:Themify(Items.Button, "text", "TextColor3")
    StackHub:Create("UICorner", { Parent = Items.Button, CornerRadius = dim(0, 8) })
    StackHub:Themify(StackHub:Create("UIStroke", { Parent = Items.Button, Color = themes.preset.outline, Thickness = 1 }), "outline", "Color")

    -- Better, smoother transparent overlay for depth
    StackHub:Create("UIGradient", {
        Parent = Items.Button, Rotation = 90,
        Color = ColorSequence.new({ColorSequenceKeypoint.new(0, rgb(255,255,255)), ColorSequenceKeypoint.new(1, rgb(180,180,180))}),
        Transparency = ColorSequence.new({ColorSequenceKeypoint.new(0, 0.95), ColorSequenceKeypoint.new(1, 1)})
    })

    StackHub:AddHover(Items.Button, themes.preset.element_hover, themes.preset.element)
    StackHub:AddPop(Items.Button, 0.97)

    Items.Button.MouseButton1Click:Connect(function() Cfg.Callback() end)
    return setmetatable(Cfg, StackHub)
end

-- Sliders
function StackHub:Slider(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Slider", 
        Flag = properties.Flag or properties.flag, 
        Min = properties.Min or properties.min or 0, 
        Max = properties.Max or properties.max or 100, 
        Default = properties.Default or properties.default or properties.Value or properties.value or 0, 
        Increment = properties.Increment or properties.increment or 1, 
        Suffix = properties.Suffix or properties.suffix or "", 
        Callback = properties.Callback or properties.callback or function() end, 
        Items = {} 
    }
    local Items = Cfg.Items

    Items.Container = StackHub:Create("Frame", { Parent = self.Items.Container, Size = dim2(1, 0, 0, 44), BackgroundTransparency = 1 })
    Items.Title = StackHub:Create("TextLabel", { Parent = Items.Container, Size = dim2(1, 0, 0, 20), BackgroundTransparency = 1, Text = Cfg.Name, TextColor3 = themes.preset.subtext, TextSize = 14, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold), TextXAlignment = Enum.TextXAlignment.Left })
    StackHub:Themify(Items.Title, "subtext", "TextColor3")

    Items.Val = StackHub:Create("TextLabel", { Parent = Items.Container, Size = dim2(1, 0, 0, 20), BackgroundTransparency = 1, Text = tostring(Cfg.Default)..Cfg.Suffix, TextColor3 = themes.preset.text, TextSize = 14, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold), TextXAlignment = Enum.TextXAlignment.Right })
    StackHub:Themify(Items.Val, "text", "TextColor3")

    -- Thin Track
    Items.Track = StackHub:Create("TextButton", { Parent = Items.Container, Position = dim2(0, 0, 0, 32), Size = dim2(1, 0, 0, 6), BackgroundColor3 = themes.preset.element, Text = "", AutoButtonColor = false })
    StackHub:Themify(Items.Track, "element", "BackgroundColor3")
    StackHub:Create("UICorner", { Parent = Items.Track, CornerRadius = dim(1, 0) })
    StackHub:Themify(StackHub:Create("UIStroke", { Parent = Items.Track, Color = themes.preset.outline, Thickness = 1 }), "outline", "Color")

    Items.Fill = StackHub:Create("Frame", { Parent = Items.Track, Size = dim2(0, 0, 1, 0), BackgroundColor3 = themes.preset.accent })
    StackHub:Themify(Items.Fill, "accent", "BackgroundColor3")
    StackHub:Create("UICorner", { Parent = Items.Fill, CornerRadius = dim(1, 0) })
    
    -- Glowing Knob
    Items.Knob = StackHub:Create("Frame", { Parent = Items.Fill, AnchorPoint = vec2(0.5, 0.5), Position = dim2(1, 0, 0.5, 0), Size = dim2(0, 14, 0, 14), BackgroundColor3 = rgb(255, 255, 255) })
    StackHub:Create("UICorner", { Parent = Items.Knob, CornerRadius = dim(1, 0) })
    StackHub:Themify(StackHub:Create("UIStroke", { Parent = Items.Knob, Color = themes.preset.outline, Thickness = 1 }), "outline", "Color")
    StackHub:Create("ImageLabel", { Parent = Items.Knob, AnchorPoint = vec2(0.5, 0.5), Position = dim2(0.5, 0, 0.5, 2), Size = dim2(1, 12, 1, 12), BackgroundTransparency = 1, Image = "rbxassetid://6014261993", ImageColor3 = rgb(0,0,0), ImageTransparency = 0.5, ZIndex = -1 })

    -- Hover effect on knob
    Items.Track.MouseEnter:Connect(function() StackHub:Tween(Items.Knob, {Size = dim2(0, 18, 0, 18)}, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)) end)
    Items.Track.MouseLeave:Connect(function() StackHub:Tween(Items.Knob, {Size = dim2(0, 14, 0, 14)}, TweenInfo.new(0.2)) end)

    local Value = Cfg.Default
    function Cfg.set(val)
        Value = math.clamp(math.round(val / Cfg.Increment) * Cfg.Increment, Cfg.Min, Cfg.Max)
        Items.Val.Text = tostring(Value) .. Cfg.Suffix
        StackHub:Tween(Items.Fill, {Size = dim2((Value - Cfg.Min) / (Cfg.Max - Cfg.Min), 0, 1, 0)}, TweenInfo.new(0.15))
        if Cfg.Flag then Flags[Cfg.Flag] = Value end
        Cfg.Callback(Value)
    end

    local Dragging = false
    Items.Track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then Dragging = true; Cfg.set(Cfg.Min + (Cfg.Max - Cfg.Min) * math.clamp((input.Position.X - Items.Track.AbsolutePosition.X) / Items.Track.AbsoluteSize.X, 0, 1)) end
    end)
    InputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then Dragging = false end
    end)
    InputService.InputChanged:Connect(function(input)
        if Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            Cfg.set(Cfg.Min + (Cfg.Max - Cfg.Min) * math.clamp((input.Position.X - Items.Track.AbsolutePosition.X) / Items.Track.AbsoluteSize.X, 0, 1))
        end
    end)

    Cfg.set(Cfg.Default)
    if Cfg.Flag then ConfigFlags[Cfg.Flag] = Cfg.set end
    return setmetatable(Cfg, StackHub)
end

function StackHub:Textbox(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "", 
        Placeholder = properties.Placeholder or properties.placeholder or "Enter text...", 
        Default = properties.Default or properties.default or "", 
        Flag = properties.Flag or properties.flag, 
        Numeric = properties.Numeric or properties.numeric or false, 
        Callback = properties.Callback or properties.callback or function() end, 
        Items = {} 
    }
    local Items = Cfg.Items

    Items.Container = StackHub:Create("Frame", { Parent = self.Items.Container, Size = dim2(1, 0, 0, 38), BackgroundTransparency = 1 })
    Items.Bg = StackHub:Create("Frame", { Parent = Items.Container, Size = dim2(1, 0, 1, 0), BackgroundColor3 = themes.preset.element })
    StackHub:Themify(Items.Bg, "element", "BackgroundColor3")
    StackHub:Create("UICorner", { Parent = Items.Bg, CornerRadius = dim(0, 8) })
    local stroke = StackHub:Create("UIStroke", { Parent = Items.Bg, Color = themes.preset.outline, Thickness = 1 })
    StackHub:Themify(stroke, "outline", "Color")

    Items.Input = StackHub:Create("TextBox", { 
        Parent = Items.Bg, Position = dim2(0, 14, 0, 0), Size = dim2(1, -28, 1, 0), BackgroundTransparency = 1, 
        Text = Cfg.Default, PlaceholderText = Cfg.Placeholder, TextColor3 = themes.preset.text, PlaceholderColor3 = themes.preset.subtext, 
        TextSize = 13, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false 
    })
    StackHub:Themify(Items.Input, "text", "TextColor3")

    -- Focus Effect
    Items.Input.Focused:Connect(function() StackHub:Tween(stroke, {Color = themes.preset.accent}, TweenInfo.new(0.3)) end)
    Items.Input.FocusLost:Connect(function() 
        StackHub:Tween(stroke, {Color = themes.preset.outline}, TweenInfo.new(0.3))
        Cfg.set(Items.Input.Text) 
    end)

    function Cfg.set(val)
        if Cfg.Numeric and tonumber(val) == nil and val ~= "" then return end
        Items.Input.Text = tostring(val)
        if Cfg.Flag then Flags[Cfg.Flag] = val end
        Cfg.Callback(val)
    end
    
    if Cfg.Default ~= "" then Cfg.set(Cfg.Default) end
    if Cfg.Flag then ConfigFlags[Cfg.Flag] = Cfg.set end

    return setmetatable(Cfg, StackHub)
end

-- Dropdown (Floating Shadow Menu)
function StackHub:Dropdown(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Dropdown", 
        Flag = properties.Flag or properties.flag, 
        Options = properties.Options or properties.options or properties.items or {}, 
        Default = properties.Default or properties.default, 
        Callback = properties.Callback or properties.callback or function() end, 
        Items = {} 
    }
    local Items = Cfg.Items
    
    Items.Container = StackHub:Create("Frame", { Parent = self.Items.Container, Size = dim2(1, 0, 0, 60), BackgroundTransparency = 1 })
    Items.Title = StackHub:Create("TextLabel", { Parent = Items.Container, Size = dim2(1, 0, 0, 18), BackgroundTransparency = 1, Text = Cfg.Name, TextColor3 = themes.preset.subtext, TextSize = 14, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold), TextXAlignment = Enum.TextXAlignment.Left })
    StackHub:Themify(Items.Title, "subtext", "TextColor3")

    Items.Main = StackHub:Create("TextButton", { 
        Parent = Items.Container, Position = dim2(0, 0, 0, 24), Size = dim2(1, 0, 0, 36), 
        BackgroundColor3 = themes.preset.element, Text = "", AutoButtonColor = false 
    })
    StackHub:Themify(Items.Main, "element", "BackgroundColor3")
    StackHub:Create("UICorner", { Parent = Items.Main, CornerRadius = dim(0, 8) })
    local stroke = StackHub:Create("UIStroke", { Parent = Items.Main, Color = themes.preset.outline, Thickness = 1 })
    StackHub:Themify(stroke, "outline", "Color")

    StackHub:AddHover(Items.Main, themes.preset.element_hover, themes.preset.element)

    Items.SelectedText = StackHub:Create("TextLabel", { Parent = Items.Main, Position = dim2(0, 14, 0, 0), Size = dim2(1, -30, 1, 0), BackgroundTransparency = 1, Text = "...", TextColor3 = themes.preset.text, TextSize = 13, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold), TextXAlignment = Enum.TextXAlignment.Left })
    StackHub:Themify(Items.SelectedText, "text", "TextColor3")
    
    Items.Icon = StackHub:Create("ImageLabel", { Parent = Items.Main, Position = dim2(1, -20, 0.5, 0), AnchorPoint = vec2(0, 0.5), Size = dim2(0, 14, 0, 14), BackgroundTransparency = 1, Image = "rbxassetid://11293977610", ImageColor3 = themes.preset.subtext, Rotation = 180 })

    -- Dropdown Menu
    Items.DropFrame = StackHub:Create("Frame", { 
        Parent = StackHub.Gui, Size = dim2(1, 0, 0, 0), Position = dim2(0, 0, 0, 0), 
        BackgroundColor3 = themes.preset.element, Visible = false, ZIndex = 200, ClipsDescendants = true 
    })
    StackHub:Themify(Items.DropFrame, "element", "BackgroundColor3")
    StackHub:Create("UICorner", { Parent = Items.DropFrame, CornerRadius = dim(0, 8) })
    StackHub:Themify(StackHub:Create("UIStroke", { Parent = Items.DropFrame, Color = themes.preset.outline, Thickness = 1 }), "outline", "Color")

    -- Dropdown Drop Shadow
    Items.DropShadow = StackHub:Create("ImageLabel", {
        ImageColor3 = rgb(0,0,0), ScaleType = Enum.ScaleType.Slice, ImageTransparency = 0.5,
        Parent = Items.DropFrame, Size = dim2(1, 40, 1, 40), Image = "rbxassetid://18245826428",
        BackgroundTransparency = 1, Position = dim2(0, -20, 0, -20), BorderSizePixel = 0,
        SliceCenter = rect(vec2(21, 21), vec2(79, 79)), ZIndex = 199
    })

    Items.Scroll = StackHub:Create("ScrollingFrame", { 
        Parent = Items.DropFrame, Size = dim2(1, -4, 1, -8), Position = dim2(0, 2, 0, 4), 
        BackgroundTransparency = 1, ScrollBarThickness = 2, ScrollBarImageColor3 = themes.preset.subtext, BorderSizePixel = 0, ZIndex = 201 
    })
    StackHub:Create("UIListLayout", { Parent = Items.Scroll, SortOrder = Enum.SortOrder.LayoutOrder, Padding = dim(0, 2) })

    local Open = false
    local isTweening = false

    function Cfg.UpdatePosition()
        local absPos = Items.Main.AbsolutePosition
        local absSize = Items.Main.AbsoluteSize
        Items.DropFrame.Position = dim2(0, absPos.X, 0, absPos.Y + absSize.Y + 8)
        Items.Scroll.CanvasSize = dim2(0, 0, 0, #Cfg.Options * 30)
    end

    local function ToggleDropdown()
        if isTweening then return end
        Open = not Open
        isTweening = true

        if Open then
            Items.DropFrame.Visible = true
            Cfg.UpdatePosition()
            Items.DropFrame.Size = dim2(0, Items.Main.AbsoluteSize.X, 0, 0)
            local targetHeight = math.clamp(#Cfg.Options * 30 + 8, 0, 180)
            StackHub:Tween(stroke, {Color = themes.preset.accent}, TweenInfo.new(0.3))
            StackHub:Tween(Items.Icon, {Rotation = 0}, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
            local tw = StackHub:Tween(Items.DropFrame, {Size = dim2(0, Items.Main.AbsoluteSize.X, 0, targetHeight)}, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
            tw.Completed:Wait()
        else
            StackHub:Tween(stroke, {Color = themes.preset.outline}, TweenInfo.new(0.3))
            StackHub:Tween(Items.Icon, {Rotation = 180}, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
            local tw = StackHub:Tween(Items.DropFrame, {Size = dim2(0, Items.Main.AbsoluteSize.X, 0, 0)}, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
            tw.Completed:Wait()
            Items.DropFrame.Visible = false
        end
        isTweening = false
    end
    Items.Main.MouseButton1Click:Connect(ToggleDropdown)

    InputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if Open and not isTweening then
                local mx, my = input.Position.X, input.Position.Y
                local p0, s0 = Items.DropFrame.AbsolutePosition, Items.DropFrame.AbsoluteSize
                local p1, s1 = Items.Main.AbsolutePosition, Items.Main.AbsoluteSize
                
                if not (mx >= p0.X and mx <= p0.X + s0.X and my >= p0.Y and my <= p0.Y + s0.Y) and 
                   not (mx >= p1.X and mx <= p1.X + s1.X and my >= p1.Y and my <= p1.Y + s1.Y) then
                    ToggleDropdown()
                end
            end
        end
    end)

    local OptionBtns = {}
    function Cfg.RefreshOptions(newList)
        Cfg.Options = newList or Cfg.Options
        for _, btn in ipairs(OptionBtns) do btn:Destroy() end
        table.clear(OptionBtns)
        for _, opt in ipairs(Cfg.Options) do
            local btn = StackHub:Create("TextButton", { 
                Parent = Items.Scroll, Size = dim2(1, 0, 0, 28), BackgroundColor3 = themes.preset.accent, BackgroundTransparency = 1,
                Text = "    " .. tostring(opt), TextColor3 = themes.preset.subtext, TextSize = 13, 
                FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 202 
            })
            StackHub:Create("UICorner", { Parent = btn, CornerRadius = dim(0, 4) })
            StackHub:Themify(btn, "subtext", "TextColor3")
            btn.MouseButton1Click:Connect(function() Cfg.set(opt); ToggleDropdown() end)
            
            btn.MouseEnter:Connect(function() StackHub:Tween(btn, {BackgroundTransparency = 0.8, TextColor3 = themes.preset.text}, TweenInfo.new(0.2)) end)
            btn.MouseLeave:Connect(function() StackHub:Tween(btn, {BackgroundTransparency = 1, TextColor3 = themes.preset.subtext}, TweenInfo.new(0.2)) end)

            table.insert(OptionBtns, btn)
        end
    end

    function Cfg.set(val)
        Items.SelectedText.Text = tostring(val)
        if Cfg.Flag then Flags[Cfg.Flag] = val end
        Cfg.Callback(val)
    end

    Cfg.RefreshOptions(Cfg.Options)
    if Cfg.Default then Cfg.set(Cfg.Default) end
    if Cfg.Flag then ConfigFlags[Cfg.Flag] = Cfg.set end

    RunService.RenderStepped:Connect(function() 
        if Open or isTweening then 
            Items.DropFrame.Position = dim2(0, Items.Main.AbsolutePosition.X, 0, Items.Main.AbsolutePosition.Y + Items.Main.AbsoluteSize.Y + 8)
        end 
    end)
    return setmetatable(Cfg, StackHub)
end

function StackHub:Label(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Label", 
        Wrapped = properties.Wrapped or properties.wrapped or false, 
        Items = {} 
    }
    local Items = Cfg.Items
    Items.Title = StackHub:Create("TextLabel", { 
        Parent = self.Items.Container, Size = dim2(1, 0, 0, Cfg.Wrapped and 26 or 20), BackgroundTransparency = 1, 
        Text = Cfg.Name, TextColor3 = themes.preset.subtext, TextSize = 14, TextWrapped = Cfg.Wrapped, 
        FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), TextXAlignment = Enum.TextXAlignment.Left, 
        TextYAlignment = Cfg.Wrapped and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center 
    })
    StackHub:Themify(Items.Title, "subtext", "TextColor3")
    
    function Cfg.set(val) Items.Title.Text = tostring(val) end
    return setmetatable(Cfg, StackHub)
end

function StackHub:Colorpicker(properties)
    local Cfg = { 
        Color = properties.Color or properties.color or rgb(255, 255, 255), 
        Callback = properties.Callback or properties.callback or function() end, 
        Flag = properties.Flag or properties.flag, 
        Items = {} 
    }
    local Items = Cfg.Items

    local btn = StackHub:Create("TextButton", { Parent = self.Items.Title or self.Items.Button or self.Items.Container, AnchorPoint = vec2(1, 0.5), Position = dim2(1, 0, 0.5, 0), Size = dim2(0, 36, 0, 18), BackgroundColor3 = Cfg.Color, Text = "" })
    StackHub:Create("UICorner", {Parent = btn, CornerRadius = dim(0, 6)})
    StackHub:Themify(StackHub:Create("UIStroke", { Parent = btn, Color = themes.preset.outline, Thickness = 1 }), "outline", "Color")

    local h, s, v = Color3.toHSV(Cfg.Color)
    
    Items.DropFrame = StackHub:Create("Frame", { Parent = StackHub.Gui, Size = dim2(0, 180, 0, 0), BackgroundColor3 = themes.preset.element, Visible = false, ZIndex = 200, ClipsDescendants = true })
    StackHub:Themify(Items.DropFrame, "element", "BackgroundColor3")
    StackHub:Create("UICorner", { Parent = Items.DropFrame, CornerRadius = dim(0, 8) })
    StackHub:Themify(StackHub:Create("UIStroke", { Parent = Items.DropFrame, Color = themes.preset.outline, Thickness = 1 }), "outline", "Color")

    Items.DropShadow = StackHub:Create("ImageLabel", {
        ImageColor3 = rgb(0,0,0), ScaleType = Enum.ScaleType.Slice, ImageTransparency = 0.5,
        Parent = Items.DropFrame, Size = dim2(1, 40, 1, 40), Image = "rbxassetid://18245826428",
        BackgroundTransparency = 1, Position = dim2(0, -20, 0, -20), BorderSizePixel = 0,
        SliceCenter = rect(vec2(21, 21), vec2(79, 79)), ZIndex = 199
    })

    Items.SVMap = StackHub:Create("TextButton", { Parent = Items.DropFrame, Position = dim2(0, 10, 0, 10), Size = dim2(1, -20, 1, -44), AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.fromHSV(h, 1, 1), ZIndex = 201 })
    StackHub:Create("UICorner", { Parent = Items.SVMap, CornerRadius = dim(0, 6) })
    Items.SVImage = StackHub:Create("ImageLabel", { Parent = Items.SVMap, Size = dim2(1, 0, 1, 0), Image = "rbxassetid://4155801252", BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 202 })
    StackHub:Create("UICorner", { Parent = Items.SVImage, CornerRadius = dim(0, 6) })
    
    Items.SVKnob = StackHub:Create("Frame", { Parent = Items.SVMap, AnchorPoint = vec2(0.5, 0.5), Size = dim2(0, 8, 0, 8), BackgroundColor3 = rgb(255,255,255), ZIndex = 203 })
    StackHub:Create("UICorner", { Parent = Items.SVKnob, CornerRadius = dim(1, 0) })
    StackHub:Create("UIStroke", { Parent = Items.SVKnob, Color = rgb(0,0,0) })

    Items.HueBar = StackHub:Create("TextButton", { Parent = Items.DropFrame, Position = dim2(0, 10, 1, -24), Size = dim2(1, -20, 0, 14), AutoButtonColor = false, Text = "", BorderSizePixel = 0, BackgroundColor3 = rgb(255, 255, 255), ZIndex = 201 })
    StackHub:Create("UICorner", { Parent = Items.HueBar, CornerRadius = dim(0, 6) })
    StackHub:Create("UIGradient", { Parent = Items.HueBar, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, rgb(255,0,0)), ColorSequenceKeypoint.new(0.167, rgb(255,0,255)), ColorSequenceKeypoint.new(0.333, rgb(0,0,255)), ColorSequenceKeypoint.new(0.5, rgb(0,255,255)), ColorSequenceKeypoint.new(0.667, rgb(0,255,0)), ColorSequenceKeypoint.new(0.833, rgb(255,255,0)), ColorSequenceKeypoint.new(1, rgb(255,0,0))}) })
    
    Items.HueKnob = StackHub:Create("Frame", { Parent = Items.HueBar, AnchorPoint = vec2(0.5, 0.5), Size = dim2(0, 4, 1, 4), BackgroundColor3 = rgb(255,255,255), ZIndex = 203 })
    StackHub:Create("UICorner", { Parent = Items.HueKnob, CornerRadius = dim(0, 2) })
    StackHub:Create("UIStroke", { Parent = Items.HueKnob, Color = rgb(0,0,0) })

    local Open = false
    local isTweening = false

    local function Toggle() 
        if isTweening then return end
        Open = not Open
        isTweening = true
        
        if Open then
            Items.DropFrame.Visible = true
            local tw = StackHub:Tween(Items.DropFrame, {Size = dim2(0, 180, 0, 160)}, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
            tw.Completed:Wait()
        else
            local tw = StackHub:Tween(Items.DropFrame, {Size = dim2(0, 180, 0, 0)}, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
            tw.Completed:Wait()
            Items.DropFrame.Visible = false
        end
        isTweening = false
    end
    btn.MouseButton1Click:Connect(Toggle)

    InputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if Open and not isTweening then
                local mx, my = input.Position.X, input.Position.Y
                local p0, s0 = Items.DropFrame.AbsolutePosition, dim2(0, 180, 0, 160)
                local p1, s1 = btn.AbsolutePosition, btn.AbsoluteSize
                if not (mx >= p0.X and mx <= p0.X + s0.X.Offset and my >= p0.Y and my <= p0.Y + s0.Y.Offset) and not (mx >= p1.X and mx <= p1.X + s1.X and my >= p1.Y and my <= p1.Y + s1.Y) then
                    Toggle()
                end
            end
        end
    end)

    function Cfg.set(color3)
        Cfg.Color = color3
        btn.BackgroundColor3 = color3
        if Cfg.Flag then Flags[Cfg.Flag] = color3 end
        Cfg.Callback(color3)
    end

    local svDragging, hueDragging = false, false
    Items.SVMap.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then svDragging = true end end)
    Items.HueBar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then hueDragging = true end end)
    InputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then svDragging = false; hueDragging = false end end)

    InputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if svDragging then
                local x = math.clamp((input.Position.X - Items.SVMap.AbsolutePosition.X) / Items.SVMap.AbsoluteSize.X, 0, 1)
                local y = math.clamp((input.Position.Y - Items.SVMap.AbsolutePosition.Y) / Items.SVMap.AbsoluteSize.Y, 0, 1)
                s, v = x, 1 - y
                Items.SVKnob.Position = dim2(x, 0, y, 0)
                Cfg.set(Color3.fromHSV(h, s, v))
            elseif hueDragging then
                local x = math.clamp((input.Position.X - Items.HueBar.AbsolutePosition.X) / Items.HueBar.AbsoluteSize.X, 0, 1)
                h = 1 - x
                Items.HueKnob.Position = dim2(x, 0, 0.5, 0)
                Items.SVMap.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                Cfg.set(Color3.fromHSV(h, s, v))
            end
        end
    end)

    RunService.RenderStepped:Connect(function()
        if Open or isTweening then Items.DropFrame.Position = dim2(0, btn.AbsolutePosition.X - 180 + btn.AbsoluteSize.X, 0, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 6) end
    end)
    
    Items.SVKnob.Position = dim2(s, 0, 1 - v, 0)
    Items.HueKnob.Position = dim2(1 - h, 0, 0.5, 0)
    
    Cfg.set(Cfg.Color)
    if Cfg.Flag then ConfigFlags[Cfg.Flag] = Cfg.set end
    return setmetatable(Cfg, StackHub)
end

function StackHub:Keybind(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Keybind", 
        Flag = properties.Flag or properties.flag, 
        Default = properties.Default or properties.default or Enum.KeyCode.Unknown, 
        Callback = properties.Callback or properties.callback or function() end, 
        Items = {} 
    }
    local KeyBtn = StackHub:Create("TextButton", { Parent = self.Items.Title or self.Items.Container, AnchorPoint = vec2(1, 0.5), Position = dim2(1, 0, 0.5, 0), Size = dim2(0, 46, 0, 22), BackgroundColor3 = themes.preset.element, TextColor3 = themes.preset.text, Text = Keys[Cfg.Default] or "None", TextSize = 12, FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold) })
    StackHub:Themify(KeyBtn, "element", "BackgroundColor3")
    StackHub:Themify(KeyBtn, "text", "TextColor3")

    StackHub:Create("UICorner", {Parent = KeyBtn, CornerRadius = dim(0, 6)})
    StackHub:Themify(StackHub:Create("UIStroke", { Parent = KeyBtn, Color = themes.preset.outline, Thickness = 1 }), "outline", "Color")
    StackHub:AddHover(KeyBtn, themes.preset.element_hover, themes.preset.element)

    local binding = false
    KeyBtn.MouseButton1Click:Connect(function() binding = true; KeyBtn.Text = "..." end)
    
    InputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed and not binding then return end
        if binding then
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
                binding = false; Cfg.set(input.KeyCode)
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                binding = false; Cfg.set(input.UserInputType)
            end
        elseif (input.KeyCode == Cfg.Default or input.UserInputType == Cfg.Default) and not binding then
            Cfg.Callback()
        end
    end)
    
    function Cfg.set(val)
        if not val or type(val) == "boolean" then return end
        Cfg.Default = val
        local keyName = Keys[val] or (typeof(val) == "EnumItem" and val.Name) or tostring(val)
        KeyBtn.Text = keyName
        if Cfg.Flag then Flags[Cfg.Flag] = val end
    end
    
    Cfg.set(Cfg.Default)
    if Cfg.Flag then ConfigFlags[Cfg.Flag] = Cfg.set end
    return setmetatable(Cfg, StackHub)
end

-- Notifications (Glassy)
function Notifications:RefreshNotifications()
    local offset = 50
    for _, v in ipairs(Notifications.Notifs) do
        local ySize = math.max(v.AbsoluteSize.Y, 40)
        StackHub:Tween(v, {Position = dim_offset(20, offset)}, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
        offset += (ySize + 12)
    end
end

function Notifications:Create(properties)
    local Cfg = { 
        Name = properties.Name or properties.name or "Notification"; 
        Lifetime = properties.LifeTime or properties.lifetime or 3; 
        Items = {}; 
    }
    local Items = Cfg.Items
   
    Items.Outline = StackHub:Create("Frame", { Parent = StackHub.Gui; Position = dim_offset(-500, 50); Size = dim2(0, 320, 0, 0); AutomaticSize = Enum.AutomaticSize.Y; BackgroundColor3 = themes.preset.section; BorderSizePixel = 0; ZIndex = 300, ClipsDescendants = true })
    StackHub:Themify(Items.Outline, "section", "BackgroundColor3")
    StackHub:Create("UICorner", { Parent = Items.Outline, CornerRadius = dim(0, 10) })
    StackHub:Themify(StackHub:Create("UIStroke", { Parent = Items.Outline, Color = themes.preset.outline, Thickness = 1 }), "outline", "Color")
   
    Items.Name = StackHub:Create("TextLabel", {
        Parent = Items.Outline; Text = Cfg.Name; TextColor3 = themes.preset.text; FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold);
        BackgroundTransparency = 1; Size = dim2(1, 0, 1, 0); AutomaticSize = Enum.AutomaticSize.None; TextWrapped = true; TextSize = 14; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 302
    })
    StackHub:Themify(Items.Name, "text", "TextColor3")
   
    StackHub:Create("UIPadding", { Parent = Items.Name; PaddingTop = dim(0, 14); PaddingBottom = dim(0, 14); PaddingRight = dim(0, 16); PaddingLeft = dim(0, 16); })
   
    Items.TimeBar = StackHub:Create("Frame", { Parent = Items.Outline, AnchorPoint = vec2(0, 1), Position = dim2(0, 0, 1, 0), Size = dim2(1, 0, 0, 3), BackgroundColor3 = themes.preset.accent, BorderSizePixel = 0, ZIndex = 303 })
    StackHub:Themify(Items.TimeBar, "accent", "BackgroundColor3")
    table.insert(Notifications.Notifs, Items.Outline)
   
    task.spawn(function()
        RunService.RenderStepped:Wait()
        Items.Outline.Position = dim_offset(-Items.Outline.AbsoluteSize.X - 20, 50)
        Notifications:RefreshNotifications()
        StackHub:Tween(Items.TimeBar, {Size = dim2(0, 0, 0, 3)}, TweenInfo.new(Cfg.Lifetime, Enum.EasingStyle.Linear))
        task.wait(Cfg.Lifetime)
        StackHub:Tween(Items.Outline, {Position = dim_offset(-Items.Outline.AbsoluteSize.X - 50, Items.Outline.Position.Y.Offset)}, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In))
        task.wait(0.4)
        local idx = table.find(Notifications.Notifs, Items.Outline)
        if idx then table.remove(Notifications.Notifs, idx) end
        Items.Outline:Destroy()
        task.wait(0.05)
        Notifications:RefreshNotifications()
    end)
end

-- configs and server menu
local ConfigHolder
function StackHub:UpdateConfigList()
    if not ConfigHolder then return end
    local List = {}
    for _, file in listfiles(StackHub.Directory .. "/configs") do
        local Name = file:gsub(StackHub.Directory .. "/configs\\", ""):gsub(".cfg", ""):gsub(StackHub.Directory .. "\\configs\\", "")
        List[#List + 1] = Name
    end
    ConfigHolder.RefreshOptions(List)
end

function StackHub:GetConfig()
    local g = {}
    for Idx, Value in Flags do g[Idx] = Value end
    return HttpService:JSONEncode(g)
end

function StackHub:LoadConfig(JSON)
    local g = HttpService:JSONDecode(JSON)
    for Idx, Value in g do
        if Idx == "config_Name_list" or Idx == "config_Name_text" then continue end
        local Function = ConfigFlags[Idx]
        if Function then Function(Value) end
    end
end

function StackHub:Configs(window)
    local Text

    local Tab = window:Tab({ Name = "Settings", Hidden = true })
    window.SettingsTabOpen = Tab.OpenTab

    local Section = Tab:Section({Name = "Config Manager", Side = "Left"})

    ConfigHolder = Section:Dropdown({
        Name = "Available Configs", Options = {}, Flag = "config_Name_list",
        Callback = function(option) if Text then Text.set(option) end end
    })

    StackHub:UpdateConfigList()

    Text = Section:Textbox({ Name = "Config Name:", Flag = "config_Name_text", Default = "" })

    Section:Button({
        Name = "Save Config",
        Callback = function()
            if Flags["config_Name_text"] == "" then return end
            writefile(StackHub.Directory .. "/configs/" .. Flags["config_Name_text"] .. ".cfg", StackHub:GetConfig())
            StackHub:UpdateConfigList()
            Notifications:Create({Name = "Saved Config: " .. Flags["config_Name_text"]})
        end
    })

    Section:Button({
        Name = "Load Config",
        Callback = function()
            if Flags["config_Name_text"] == "" then return end
            StackHub:LoadConfig(readfile(StackHub.Directory .. "/configs/" .. Flags["config_Name_text"] .. ".cfg"))
            StackHub:UpdateConfigList()
            Notifications:Create({Name = "Loaded Config: " .. Flags["config_Name_text"]})
        end
    })

    Section:Button({
        Name = "Delete Config",
        Callback = function()
            if Flags["config_Name_text"] == "" then return end
            delfile(StackHub.Directory .. "/configs/" .. Flags["config_Name_text"] .. ".cfg")
            StackHub:UpdateConfigList()
            Notifications:Create({Name = "Deleted Config: " .. Flags["config_Name_text"]})
        end
    })

    local SectionRight = Tab:Section({Name = "Theming", Side = "Right"})

    SectionRight:Label({Name = "Accent Color"}):Colorpicker({ Callback = function(color3) StackHub:RefreshTheme("accent", color3) end, Color = themes.preset.accent })
    SectionRight:Label({Name = "Glow Color"}):Colorpicker({ Callback = function(color3) StackHub:RefreshTheme("glow", color3) end, Color = themes.preset.glow })
    SectionRight:Label({Name = "Background Color"}):Colorpicker({ Callback = function(color3) StackHub:RefreshTheme("background", color3) end, Color = themes.preset.background })
    SectionRight:Label({Name = "Section Color"}):Colorpicker({ Callback = function(color3) StackHub:RefreshTheme("section", color3) end, Color = themes.preset.section })
    SectionRight:Label({Name = "Element Color"}):Colorpicker({ Callback = function(color3) StackHub:RefreshTheme("element", color3) end, Color = themes.preset.element })

    window.Tweening = true
    SectionRight:Label({Name = "Menu Bind"}):Keybind({
        Name = "Menu Bind",
        Callback = function(bool) if window.Tweening then return end window.ToggleMenu(bool) end,
        Default = Enum.KeyCode.RightShift
    })

    task.delay(1, function() window.Tweening = false end)

    local ServerSection = Tab:Section({Name = "Utility", Side = "Right"})
    ServerSection:Button({ Name = "Rejoin Server", Callback = function() game:GetService("TeleportService"):Teleport(game.PlaceId, Players.LocalPlayer) end })
    ServerSection:Button({
        Name = "Server Hop",
        Callback = function()
            local servers, cursor = {}, ""
            repeat
                local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100" .. (cursor ~= "" and "&cursor=" .. cursor or "")
                local data = HttpService:JSONDecode(game:HttpGet(url))
                for _, server in ipairs(data.data) do
                    if server.id ~= game.JobId and server.playing < server.maxPlayers then table.insert(servers, server) end
                end
                cursor = data.nextPageCursor
            until not cursor or #servers > 0
            if #servers > 0 then game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)].id, Players.LocalPlayer) end
        end
    })
end

return StackHub
