from pathlib import Path
p=Path('src/shared/ShopButton.luau')
s=p.read_text(encoding='utf-8-sig')
s=s.replace('local DEPTH = 5','''local DEPTH = 5
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
        children["Contour"..index]=layer(UDim2.fromOffset(math.cos(angle)*CART_OUTLINE_EXTENSION,math.sin(angle)*CART_OUTLINE_EXTENSION),Color3.new(0,0,0),5)
    end
    children.Image=layer(UDim2.fromOffset(0,0),Color3.new(1,1,1),6)
    return e("Frame",{Name="Cart",BackgroundTransparency=1,Position=UDim2.fromOffset(15,6),Size=UDim2.fromOffset(73,70),ZIndex=5},children)
end''')
start=s.index('            Cart=e("ImageLabel"')
end=s.index('\n',start)
s=s[:start]+'            Cart=cartIcon(),'+s[end:]
p.write_text(s,encoding='utf-8')
