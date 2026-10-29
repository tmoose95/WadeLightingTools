-- Attribute Clone v1.2.1 | grandMA3 2.5.1
-- Four columns: source fixtures | source attribute | destination fixtures | destination attribute.
-- Clones only Sequences, Presets and Worlds; Groups and Layouts are never targeted.
local _, _, signalTable, myHandle = ...
local function alert(t,m) MessageBox({title=t,message=m,commands={{value=1,name='OK'}}}) end
local function parseFixtures(s)
    s=tostring(s or ''):gsub('^%s+',''):gsub('%s+$',''):lower()
    local a,b=s:match('^(%d+)%s+thru%s+(%d+)$')
    if not a then a,b=s:match('^(%d+)%s*%-%s*(%d+)$') end
    local out={}
    if a then
        a,b=tonumber(a),tonumber(b)
        if a>b or b-a>127 then return nil,'Use an ascending range of at most 128 fixtures.' end
        for n=a,b do out[#out+1]=n end
    else
        for n in s:gmatch('%d+') do out[#out+1]=tonumber(n) end
        if #out==0 or #out>128 or s:find('[^%d%s+,]') then return nil,'Enter fixture IDs, e.g. 6701 Thru 6704 or 6701 + 6702.' end
    end
    local seen={}
    for _,n in ipairs(out) do
        if seen[n] then return nil,'A fixture ID is repeated.' end
        seen[n]=true
        local ok,items=pcall(ObjectList,'Fixture '..n)
        if not ok or not items or not items[1] then return nil,'Fixture '..n..' is not in this show.' end
    end
    return out
end
local function attributes(fid)
    local ok,fixtures=pcall(ObjectList,'Fixture '..fid)
    if not ok or not fixtures or not fixtures[1] then return {} end
    local list,seen={},{}
    local ok2,channels=pcall(GetUIChannels,fixtures[1])
    if ok2 and type(channels)=='table' then
        for _,ch in pairs(channels) do
            local aok,attr=pcall(GetAttributeByUIChannel,ch)
            if aok and attr then
                local name=tostring(attr.Name or '')
                if name~='' and not seen[name] then seen[name]=true;list[#list+1]=name end
            end
        end
    end
    table.sort(list)
    return list
end
local function commonAttributes(ids)
    if not ids or #ids==0 then return {} end
    local first=attributes(ids[1]);local common={}
    for _,name in ipairs(first) do common[name]=true end
    for i=2,#ids do
        local available={}
        for _,name in ipairs(attributes(ids[i])) do available[name]=true end
        for name in pairs(common) do if not available[name] then common[name]=nil end end
    end
    local result={}
    for _,name in ipairs(first) do if common[name] then result[#result+1]=name end end
    return result
end
local SOURCE_KEY='AttributeClone_Source_v101'
local DEST_KEY='AttributeClone_Destination_v101'
local function loadList(key)
    local ok,value=pcall(GetVar,UserVars(),key)
    local list={}
    if ok and type(value)=='string' then
        for n in value:gmatch('%d+') do list[#list+1]=tonumber(n) end
    end
    return list
end
local function saveList(key,list)
    local parts={}
    for _,id in ipairs(list) do parts[#parts+1]=tostring(id) end
    SetVar(UserVars(),key,table.concat(parts,','))
end
local function selectedFixtures()
    local result,seen={},{}
    local idx=SelectionFirst()
    while idx do
        local ok,fixture=pcall(GetSubfixture,idx)
        if ok and fixture then
            local address=fixture:ToAddr()
            -- ToAddr supplies a fixture address (not a patch index).
            local id=tonumber(tostring(address):match('[Ff]ixture%s+(%d+)'))
            if id and not seen[id] then seen[id]=true;result[#result+1]=id end
        end
        idx=SelectionNext(idx)
    end
    return result
end
local function addUnique(list,more)
    local seen={}
    for _,n in ipairs(list) do seen[n]=true end
    for _,n in ipairs(more) do if not seen[n] then list[#list+1]=n;seen[n]=true end end
end
local function listText(list)
    if #list==0 then return '(empty)' end
    local parts={};for _,n in ipairs(list) do parts[#parts+1]=tostring(n) end
    return table.concat(parts,', ')
end
local function safeLabel(s) return tostring(s):gsub('["\n\r]','') end
local function button(parent,col,row,name,label,click,color)
    local b=parent:Append('Button');b.Name=name;b.Text=label
    b.Anchors={left=col,right=col,top=row,bottom=row};b.Font='Regular18'
    b.PluginComponent=myHandle;b.Clicked=click
    if color then b.BackColor=color end
    return b
end
-- Attribute definitions supply the feature-group hierarchy. Never infer a
-- category from an attribute name: e.g. media-server dimmers can be named freely.
local function safe(fn, default)
    local ok, value=pcall(fn)
    if ok and value~=nil then return value end
    return default
end
local function attributeTree(ids)
    local names=commonAttributes(ids)
    if #names==0 then return {} end
    local lookup={}
    local fixtures=ObjectList('Fixture '..ids[1])
    for _,channel in pairs(GetUIChannels(fixtures[1]) or {}) do
        local attr=GetAttributeByUIChannel(channel)
        if attr then lookup[tostring(attr.Name)]=attr end
    end
    local groups,byKey={},{}
    for _,name in ipairs(names) do
        local attr=lookup[name]
        local group=safe(function() return attr.Feature:Parent() end,nil)
        local number=group and safe(function() return Obj.Index(group) end,999) or 999
        local groupName=group and safe(function() return tostring(group.Name) end,'Other') or 'Other'
        local pretty=group and safe(function() return tostring(group.Pretty) end,groupName) or groupName
        if pretty=='' then pretty=groupName end
        local key=tostring(number)..':'..groupName
        if not byKey[key] then
            local item={key=key,number=number,name=pretty,attributes={}}
            byKey[key]=item;groups[#groups+1]=item
        end
        byKey[key].attributes[#byKey[key].attributes+1]={name=name,handle=attr}
    end
    table.sort(groups,function(a,b) if a.number==b.number then return a.name<b.name end return a.number<b.number end)
    return groups
end
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

local function editor()
    local state={src=loadList(SOURCE_KEY),dst=loadList(DEST_KEY),source={},destination={},
        sourceOrder={},destinationOrder={},expanded={[2]={},[4]={}},lists={},controls={},closed=false}
    local build,render,refresh,updateSelection
    local function destroy(object)
        if object and IsObjectValid(object) then
            local parent=object:Parent()
            if parent then Obj.Delete(parent,Obj.Index(object)) end
        end
    end
    local function close() destroy(state.base);state.base=nil end
    local function availableDisplay(index)
        local d=safe(function() return GetDisplayByIndex(index) end,nil)
        if not d then return end
        local overlay=safe(function() return d.ScreenOverlay end,nil)
        if not overlay or not IsObjectValid(overlay) then return end
        if (tonumber(d.W) or 0)<=0 or (tonumber(d.H) or 0)<=0 then return end
        return d
    end
    local function label(parent,col,row,text,color)
        local item=parent:Append('UIObject');item.Anchors={left=col,right=col,top=row,bottom=row}
        item.Text=text;item.Font='Regular18';item.TextalignmentH='Left'
        if color then item.BackColor=color end
        return item
    end
    local function chosen(col)
        return col==2 and state.source or state.destination,
               col==2 and state.sourceOrder or state.destinationOrder
    end
    local function prune(col,tree)
        local selected,order=chosen(col);local valid={}
        for _,g in ipairs(tree) do for _,attr in ipairs(g.attributes) do valid[attr.name]=true end end
        for i=#order,1,-1 do if not valid[order[i]] then selected[order[i]]=nil;table.remove(order,i) end end
    end
    local function attrLabel(col,name)
        local selected,order=chosen(col)
        if selected[name] then
            for index,value in ipairs(order) do if value==name then return '    ['..index..'] '..name end end
        end
        return '    [ ] '..name
    end
    updateSelection=function()
        for _,entry in pairs(state.controls) do
            if entry.kind=='attribute' and IsObjectValid(entry.control) then
                local selected=chosen(entry.col)
                entry.control.Text=attrLabel(entry.col,entry.name)
                entry.control.BackColor=selected[entry.name] and state.accent or state.normal
            end
        end
        state.info.Text='SOURCE '..#state.src..' fixtures / '..#state.sourceOrder..' attributes    |    DESTINATION '..#state.dst..' fixtures / '..#state.destinationOrder..' attributes'
    end
    render=function(col)
        local view=state.lists[col]
        destroy(view.content)
        -- Keep the ScrollBox itself alive so checking an attribute never resets
        -- native scrolling. Folder changes replace only its content grid.
        for name,entry in pairs(state.controls) do if entry.col==col then state.controls[name]=nil end end
        local rows={}
        if col==1 or col==3 then
            local fixtures=col==1 and state.src or state.dst
            for i,id in ipairs(fixtures) do rows[#rows+1]={kind='fixture',text=tostring(i)..'   Fixture '..id} end
        else
            local tree=state.trees[col]
            for _,group in ipairs(tree) do
                local expanded=state.expanded[col][group.key]==true
                rows[#rows+1]={kind='folder',key=group.key,text=(expanded and 'v  ' or '>  ')..group.number..' '..group.name..' ('..#group.attributes..')'}
                if expanded then
                    for _,attr in ipairs(group.attributes) do rows[#rows+1]={kind='attribute',name=attr.name} end
                end
            end
        end
        if #rows==0 then rows[1]={kind='empty',text='(empty)'} end
        local content=view.scroll:Append('UILayoutGrid');view.content=content
        content.Name='Rows'..col;content.Columns=1;content.Rows=#rows
        content.W='100%';content.H=#rows*36
        for i,row in ipairs(rows) do
            content[1][i].SizePolicy='Fixed';content[1][i].Size='36'
            if row.kind=='empty' or row.kind=='fixture' then
                label(content,0,i-1,row.text,row.kind=='fixture' and state.normal or nil)
            else
                local name='C'..col..'R'..i
                local control=button(content,0,i-1,name,row.kind=='folder' and row.text or attrLabel(col,row.name),'ACTree',state.normal)
                control.TextalignmentH='Left'
                if row.kind=='folder' then control.BackColor=state.accent end
                state.controls[name]={control=control,col=col,kind=row.kind,key=row.key,name=row.name}
            end
        end
        view.header.Text=view.title..' ('..((col==1 and #state.src) or (col==3 and #state.dst) or #commonAttributes(col==2 and state.src or state.dst))..')'
        updateSelection()
    end
    refresh=function()
        state.trees={[2]=attributeTree(state.src),[4]=attributeTree(state.dst)}
        prune(2,state.trees[2]);prune(4,state.trees[4])
        for col=1,4 do render(col) end
    end
    build=function(display)
        close()
        display=display or GetFocusDisplay() or availableDisplay(1)
        state.display=display;state.screen=Obj.Index(display);state.overlay=display.ScreenOverlay
        local theme=Root().ColorTheme.ColorGroups
        state.accent,state.normal=theme.Button.BackgroundPlease,theme.Button.BackgroundNormal
        local base=state.overlay:Append('BaseInput');state.base=base
        base.Name='AttributeCloneWindow'
        base.W=math.min(1260,math.floor(display.W*.94));base.H=math.min(900,math.floor(display.H*.88))
        base.MaxSize=string.format('%s,%s',display.W*.96,display.H*.96)
        base.MinSize='760,480';base.Columns,base.Rows=1,2
        base[1][1].SizePolicy='Fixed';base[1][1].Size='54'
        base[1][2].SizePolicy='Stretch'
        base.AutoClose='No';base.CloseOnEscape='Yes'
        local title=base:Append('TitleBar');title.Columns,title.Rows,title.Anchors=3,1,'0,0'
        title[2][2].SizePolicy='Fixed';title[2][2].Size='55'
        title[2][3].SizePolicy='Fixed';title[2][3].Size='55'
        local brand=title:Append('TitleButton');brand.Anchors='0,0';brand.Text='ATTRIBUTE CLONE  |  v1.2.1';brand.Texture='corner1'
        display_icon(button(title,1,0,'Move','','ACMove'))
        local x=title:Append('CloseButton');x.Anchors='2,0';x.Texture='corner2'
        local frame=base:Append('DialogFrame');frame.Anchors={left=0,right=0,top=1,bottom=1}
        frame.Columns,frame.Rows=1,4
        for index,size in ipairs({54,46,0,58}) do
            frame[1][index].SizePolicy=index==3 and 'Stretch' or 'Fixed'
            if index~=3 then frame[1][index].Size=tostring(size) end
        end
        local actions=frame:Append('UILayoutGrid');actions.Anchors='0,0';actions.Columns,actions.Rows=6,1
        button(actions,0,0,'AddSrc','ADD SOURCE','ACAdd',state.accent)
        button(actions,1,0,'ClearSrc','CLEAR SOURCE','ACClear',state.normal)
        button(actions,2,0,'Pick','SELECT IN LAYOUT','ACClose',state.normal)
        button(actions,3,0,'AddDst','ADD DEST','ACAdd',state.accent)
        button(actions,4,0,'ClearDst','CLEAR DEST','ACClear',state.normal)
        button(actions,5,0,'Input','ENTER IDS','ACInput',state.normal)
        state.info=label(frame,0,1,'')
        local cols=frame:Append('UILayoutGrid');cols.Anchors='0,2';cols.Columns,cols.Rows=4,1
        state.lists={};state.controls={}
        local titles={'SOURCE FIXTURES','SOURCE ATTRIBUTES','DESTINATION FIXTURES','DESTINATION ATTRIBUTES'}
        for col=1,4 do
            local panel=cols:Append('UILayoutGrid');panel.Anchors={left=col-1,right=col-1,top=0,bottom=0}
            panel.Columns,panel.Rows=2,2
            panel[1][1].SizePolicy='Fixed';panel[1][1].Size='36'
            panel[1][2].SizePolicy='Stretch'
            panel[2][1].SizePolicy='Stretch'
            panel[2][2].SizePolicy='Fixed';panel[2][2].Size='18'
            local header=label(panel,0,0,titles[col],state.accent)
            header.Anchors={left=0,right=1,top=0,bottom=0}
            local scroll=panel:Append('ScrollBox');scroll.Name='Scroll'..col;scroll.Anchors='0,1'
            local bar=panel:Append('ScrollBarV');bar.Name='Bar'..col;bar.Anchors='1,1';bar.ScrollTarget=scroll
            state.lists[col]={scroll=scroll,bar=bar,header=header,title=titles[col]}
        end
        local footer=frame:Append('UILayoutGrid');footer.Anchors='0,3';footer.Columns,footer.Rows=3,1
        button(footer,0,0,'Review','REVIEW & CLONE','ACReview',state.accent)
        button(footer,1,0,'Refresh','REFRESH','ACRefresh',state.normal)
        button(footer,2,0,'Close','CLOSE','ACClose',state.normal)
        refresh()
    end
    signalTable.ACTree=function(caller)
        local entry=state.controls[caller.Name];if not entry then return end
        if entry.kind=='folder' then
            state.expanded[entry.col][entry.key]=not state.expanded[entry.col][entry.key]
            render(entry.col)
        elseif entry.kind=='attribute' then
            local selected,order=chosen(entry.col)
            if selected[entry.name] then
                selected[entry.name]=nil
                for i=#order,1,-1 do if order[i]==entry.name then table.remove(order,i) end end
            else selected[entry.name]=true;order[#order+1]=entry.name end
            updateSelection()
        end
    end
    signalTable.ACAdd=function(caller)
        local selected=selectedFixtures()
        if #selected==0 then alert('Selection','Select fixtures in a Layout or Fixture Sheet first.');return end
        local side=caller.Name=='AddSrc' and 'src' or 'dst';addUnique(state[side],selected)
        saveList(side=='src' and SOURCE_KEY or DEST_KEY,state[side]);refresh()
    end
    signalTable.ACClear=function(caller)
        local side=caller.Name=='ClearSrc' and 'src' or 'dst';state[side]={}
        saveList(side=='src' and SOURCE_KEY or DEST_KEY,state[side]);refresh()
    end
    signalTable.ACMove=function()
        if state.chooser and IsObjectValid(state.chooser) then return end
        state.chooser=display_preference(state.overlay,state.display,'ACDisplay','ACCancelMove',availableDisplay)
    end
    signalTable.ACDisplay=function(caller)
        local index=tonumber(caller.Name:match('Display(%d+)'))
        local display=index and availableDisplay(index)
        if not display then return end
        destroy(state.chooser);state.chooser=nil
        if index~=state.screen then build(display) end
    end
    signalTable.ACCancelMove=function() destroy(state.chooser);state.chooser=nil end
    signalTable.ACRefresh=refresh
    signalTable.ACClose=function() close();state.closed=true end
    signalTable.ACInput=function()
        local r=MessageBox({title='ADD FIXTURE IDS',inputs={{name='IDs',value='6701 Thru 6704'}},commands={{value=1,name='SOURCE'},{value=2,name='DESTINATION'},{value=0,name='CANCEL'}}})
        if not r or r.result==0 then return end
        local ids,err=parseFixtures(r.inputs['IDs']);if not ids then alert('Fixture IDs',err);return end
        local side=r.result==1 and 'src' or 'dst';addUnique(state[side],ids)
        saveList(side=='src' and SOURCE_KEY or DEST_KEY,state[side]);refresh()
    end
    signalTable.ACReview=function()
        if #state.src==0 or #state.src~=#state.dst then alert('Fixtures','Add equal numbers of source and destination fixtures.');return end
        if #state.sourceOrder==0 or #state.sourceOrder~=#state.destinationOrder then alert('Attributes','Choose equal numbers of source and destination attributes. Matching numbers form each clone pair.');return end
        state.result={state.src,state.dst,state.sourceOrder,state.destinationOrder};close();state.closed=true
    end
    build()
    repeat coroutine.yield({ui=1}) until state.closed or not (state.base and IsObjectValid(state.base))
    destroy(state.chooser);close()
    for _,name in ipairs({'ACTree','ACAdd','ACClear','ACMove','ACDisplay','ACCancelMove','ACRefresh','ACClose','ACInput','ACReview'}) do signalTable[name]=nil end
    if state.result then return table.unpack(state.result) end
end
local function targetObjects()
    local objects={};local pool=DataPool()
    local function add(handle)
        if not handle then return end
        local ok,kids=pcall(function() return handle:Children() end)
        if ok and kids then for _,item in ipairs(kids) do
            local emptyOk,empty=pcall(function() return item:IsEmpty() end)
            if not emptyOk or not empty then
                local addr=item:ToAddr()
                if addr and addr~='' then objects[#objects+1]=addr end
            end
        end end
    end
    add(pool and pool.Sequences)
    if pool and pool.PresetPools then
        local ok,kids=pcall(function() return pool.PresetPools:Children() end)
        if ok and kids then for _,presetPool in ipairs(kids) do add(presetPool) end end
    end
    add(pool and pool.Worlds)
    return objects
end
local function run()
    local src,dst,from,to=editor();if not src then return end
    local objects=targetObjects()
    if #objects==0 then alert('No show objects','No sequences, presets, or worlds found.');return end
    local pairs={}
    for i=1,#from do pairs[#pairs+1]=i..': '..from[i]..' -> '..to[i] end
    local r=MessageBox({title='REVIEW ATTRIBUTE CLONE',message=table.concat(pairs,'\n')..'\n\n'..#src..' fixture pairs, '..#from..' attribute pairs, '..#objects..' show objects.\nGroups and layouts excluded. Save a show backup first.',commands={{value=1,name='CLONE'},{value=0,name='CANCEL'}}})
    if not r or r.result~=1 then return end
    local completed,failed=0,0;local undo=CreateUndo('Attribute Clone')
    for i=1,#src do for j=1,#from do for _,object in ipairs(objects) do
        local cmd=string.format('Clone Fixture %d Attribute "%s" At Fixture %d Attribute "%s" If %s /MergeLowPriority /NoDependencies',src[i],safeLabel(from[j]),dst[i],safeLabel(to[j]),object)
        local ok,status=pcall(Cmd,cmd,undo)
        if ok and status=='Ok' then completed=completed+1 else failed=failed+1;ErrPrintf('Attribute Clone: '..cmd..' => '..tostring(status)) end
    end end end
    CloseUndo(undo)
    alert('Attribute Clone',completed..' commands completed; '..failed..' failed. Inspect a representative cue.')
end
return run
