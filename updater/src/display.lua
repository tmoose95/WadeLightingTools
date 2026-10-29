-- Visual arrangement follows MA's Edit Display Preference panel.
local function display_icon(control)
    control.Text='▣'
    if type(FindTexture)=='function' then
        for _,name in ipairs({'display','screen','monitor','object_display'}) do
            local ok,texture=pcall(FindTexture,name)
            if ok and texture then control.Icon=name;control.Text='';break end
        end
    end
end
local function display_preference(overlay,display,moveCallback,cancelCallback,available)
    local theme=Root().ColorTheme.ColorGroups
    local chooser=overlay:Append('BaseInput')
    chooser.Name='EditDisplayPreference';chooser.W=600;chooser.H=660
    chooser.MaxSize=string.format('%s,%s',display.W*.94,display.H*.94)
    chooser.Columns,chooser.Rows=1,2;chooser.AutoClose='No';chooser.CloseOnEscape='Yes'
    chooser[1][1].SizePolicy='Fixed';chooser[1][1].Size='54';chooser[1][2].SizePolicy='Stretch'
    local top=chooser:Append('TitleBar');top.Anchors='0,0';top.Columns,top.Rows=3,1
    top[2][2].SizePolicy='Fixed';top[2][2].Size='105'
    top[2][3].SizePolicy='Fixed';top[2][3].Size='54'
    local caption=top:Append('TitleButton');caption.Anchors='0,0';caption.Text='Edit Display Preference';caption.Texture='corner1'
    button(top,1,0,'CancelMove','Clear',cancelCallback)
    local x=top:Append('CloseButton');x.Anchors='2,0';x.Texture='corner2'
    local grid=chooser:Append('UILayoutGrid');grid.Anchors='0,1';grid.Columns,grid.Rows=3,3
    grid.Margin={left=8,right=8,top=6,bottom=8}
    local cells={{5,0,0,'External 5'},{4,2,0,'External 4'},{3,0,1,'Internal 3'},
        {2,1,1,'Internal 2'},{1,2,1,'Internal 1'},{7,1,2,'Small 7'},{6,2,2,'Small 6'}}
    for _,cell in ipairs(cells) do
        local index,col,row,label=table.unpack(cell)
        local b=button(grid,col,row,'Display'..index,label,moveCallback,theme.Button.BackgroundNormal)
        b.Margin={left=3,right=3,top=3,bottom=3}
        b.Enabled=available(index) and 'Yes' or 'No'
        if index==Obj.Index(display) then
            b.State=1
            local ok,color=pcall(function()return theme.Button.TextPlease end)
            if ok and color then b.TextColor=color end
        end
    end
    return chooser
end

