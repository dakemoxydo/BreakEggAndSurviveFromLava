local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local e = React.createElement
local BLACK = Color3.fromRGB(35, 35, 35)
local OUTLINE = 6
local RADIUS = 6
local INNER_STROKE = 3
local DEPTH = 5
local CART_IMAGE = "rbxassetid://82216367327862"
-- The generated contour is about 3 px at this display size; extend its alpha silhouette.
local CART_OUTLINE_EXTENSION = 3
local function cartIcon()
    local children = {}
    local function layer(position, color, z)
        return e("ImageLabel", {
            BackgroundTransparency=1, Image=CART_IMAGE, ScaleType=Enum.ScaleType.Fit,
            ImageRectOffset=Vector2.new(23,97),ImageRectSize=Vector2.new(1213,1117),
            Position=position,Size=UDim2.fromScale(1,1),ImageColor3=color,ZIndex=z,
        })
    end
    for index=1,16 do
        local angle=2*math.pi*index/16
        children["Contour"..index]=layer(UDim2.fromOffset(math.cos(angle)*CART_OUTLINE_EXTENSION,math.sin(angle)*CART_OUTLINE_EXTENSION),Color3.new(0,0,0),6)
    end
    children.Image=layer(UDim2.fromOffset(0,0),Color3.new(1,1,1),7)
    return e("Frame",{Name="Cart",BackgroundTransparency=1,Position=UDim2.fromOffset(15,6),Size=UDim2.fromOffset(73,70),ZIndex=6},children)
end

local function useHoverMotion()
    local binding, update = React.useBinding(0)
    local motion = React.useMemo(function()
        return Ripple.createSpring(0, {frequency = 5, dampingRatio = 1, start = true})
    end, {})
    React.useEffect(function()
        local disconnect = motion:onChange(update)
        return function() disconnect(); motion:destroy() end
    end, {motion})
    return binding, motion
end

local function ShopButton()
    local hover, motion = useHoverMotion()
    local selected = React.useRef(false)
    local function target(value) motion:setGoal(value) end
    return e("TextButton", {
        Name = "ShopButton", AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 24, 0.5, 0), Size = UDim2.fromOffset(256, 86),
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
        [React.Event.MouseEnter] = function() target(1) end,
        [React.Event.MouseLeave] = function() if not selected.current then target(0) end end,
        [React.Event.SelectionGained] = function() selected.current = true; target(1) end,
        [React.Event.SelectionLost] = function() selected.current = false; target(0) end,
    }, {
        Scale = e("UIScale", {Scale = hover:map(function(t) return 1 + 0.12*t end)}),
        -- One outer silhouette keeps the black contour continuous around the lower depth.
        Depth = e("Frame", {
            Name="Depth", Size=UDim2.new(1,0,1,DEPTH),
            BackgroundColor3=hover:map(function(t) return Color3.fromRGB(12,135,0):Lerp(Color3.fromRGB(8,92,0),t) end),
            BorderSizePixel=0, ZIndex=1,
        }, {
            Corner=e("UICorner",{CornerRadius=UDim.new(0,RADIUS)}),
            Outline=e("UIStroke",{Color=BLACK,Thickness=OUTLINE,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Round}),
        }),
        -- A rounded light frame around a smaller rounded surface forms an inset stroke.
        Face = e("Frame", {
            Name="Face", Size=UDim2.fromScale(1,1), BorderSizePixel=0, ZIndex=2,
            BackgroundColor3=hover:map(function(t) return Color3.fromRGB(218,255,107):Lerp(Color3.fromRGB(168,206,72),t) end),
        }, {
            Corner=e("UICorner",{CornerRadius=UDim.new(0,RADIUS)}),
            Surface=e("Frame",{
                Name="Surface",Position=UDim2.fromOffset(INNER_STROKE,INNER_STROKE),
                Size=UDim2.new(1,-2*INNER_STROKE,1,-2*INNER_STROKE),BorderSizePixel=0,ZIndex=3,
                BackgroundColor3=hover:map(function(t) return Color3.new(1,1,1):Lerp(Color3.fromRGB(155,167,150),t) end),
            },{
                Corner=e("UICorner",{CornerRadius=UDim.new(0,RADIUS-INNER_STROKE)}),
                Gradient=e("UIGradient",{Rotation=90,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(222,255,0)),ColorSequenceKeypoint.new(0.45,Color3.fromRGB(159,255,0)),ColorSequenceKeypoint.new(1,Color3.fromRGB(22,231,0))})}),
                -- A full-size rounded gradient mask keeps diagonal highlights inside the face.
                -- Tinted alpha blending approximates the reference's Soft Light appearance.
                Shine=e("Frame",{
                    Name="Shine",Size=UDim2.fromScale(1,1),BorderSizePixel=0,ZIndex=4,
                    BackgroundColor3=Color3.fromRGB(235,255,155),
                    BackgroundTransparency=hover:map(function(t) return 0.62 + 0.02*t end),
                },{
                    Corner=e("UICorner",{CornerRadius=UDim.new(0,RADIUS-INNER_STROKE)}),
                    Bands=e("UIGradient",{
                        Rotation=30,
                        Transparency=NumberSequence.new({
                            NumberSequenceKeypoint.new(0,1),
                            NumberSequenceKeypoint.new(0.26,1),
                            NumberSequenceKeypoint.new(0.264,0),
                            NumberSequenceKeypoint.new(0.55,0),
                            NumberSequenceKeypoint.new(0.554,1),
                            NumberSequenceKeypoint.new(0.59,1),
                            NumberSequenceKeypoint.new(0.594,0),
                            NumberSequenceKeypoint.new(0.79,0),
                            NumberSequenceKeypoint.new(0.794,1),
                            NumberSequenceKeypoint.new(1,1),
                        }),
                    }),
                }),
                Studs=e("ImageLabel",{
                    Name="Studs",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=5,
                    Image="rbxassetid://103946336580493",ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(52,52),
                    ImageColor3=Color3.fromRGB(76,126,0),ImageTransparency=hover:map(function(t) return 0.90 - 0.13*t end),
                },{Corner=e("UICorner",{CornerRadius=UDim.new(0,RADIUS-INNER_STROKE)})}),
            }),
            Cart=cartIcon(),
            Label=e("TextLabel",{
                Name="Label",BackgroundTransparency=1,Position=UDim2.fromOffset(96,0),Size=UDim2.new(1,-109,1,0),
                Text="Shop",Font=Enum.Font.GothamBlack,TextSize=52,TextXAlignment=Enum.TextXAlignment.Left,TextColor3=Color3.new(1,1,1),ZIndex=7,
            },{Outline=e("UIStroke",{Color=BLACK,Thickness=OUTLINE,LineJoinMode=Enum.LineJoinMode.Round})}),
        }),
    })
end
return ShopButton

