from pathlib import Path
p=Path('src/shared/ShopButton.luau')
s=p.read_text(encoding='utf-8-sig')
s=s.replace('Color3.new(0,0,0),5)', 'Color3.new(0,0,0),6)').replace('Color3.new(1,1,1),6)', 'Color3.new(1,1,1),7)')
s=s.replace('Size=UDim2.fromOffset(73,70),ZIndex=5}', 'Size=UDim2.fromOffset(73,70),ZIndex=6}')
s=s.replace('Name="Studs",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=4,','Name="Studs",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=5,')
s=s.replace('TextColor3=Color3.new(1,1,1),ZIndex=5,','TextColor3=Color3.new(1,1,1),ZIndex=7,')
needle='                Studs=e("ImageLabel",{'
shine='''                -- A full-size rounded gradient mask keeps diagonal highlights inside the face.
                -- Tinted alpha blending approximates the reference's Soft Light appearance.
                Shine=e("Frame",{
                    Name="Shine",Size=UDim2.fromScale(1,1),BorderSizePixel=0,ZIndex=4,
                    BackgroundColor3=Color3.fromRGB(235,255,155),
                    BackgroundTransparency=hover:map(function(t) return 0.82 - 0.04*t end),
                },{
                    Corner=e("UICorner",{CornerRadius=UDim.new(0,RADIUS-INNER_STROKE)}),
                    Bands=e("UIGradient",{
                        Rotation=30,
                        Transparency=NumberSequence.new({
                            NumberSequenceKeypoint.new(0,1),
                            NumberSequenceKeypoint.new(0.34,1),
                            NumberSequenceKeypoint.new(0.344,0),
                            NumberSequenceKeypoint.new(0.55,0),
                            NumberSequenceKeypoint.new(0.554,1),
                            NumberSequenceKeypoint.new(0.59,1),
                            NumberSequenceKeypoint.new(0.594,0),
                            NumberSequenceKeypoint.new(0.71,0),
                            NumberSequenceKeypoint.new(0.714,1),
                            NumberSequenceKeypoint.new(1,1),
                        }),
                    }),
                }),
'''
assert needle in s
s=s.replace(needle,shine+needle)
p.write_text(s,encoding='utf-8')
