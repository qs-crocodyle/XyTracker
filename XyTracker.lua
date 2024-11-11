-- 定义插件的一些常量和全局变量
local XyInProgress, XyTracker_Options, XyOnlyMode, NewDKP, NowNotification, IsLeader, Xys, NoXyList
XY_BUTTON_HEIGHT = 25;
Xy_SortOptions = { ["method"] = "", ["itemway"] = "" };
UnitPopupButtons["GET_XY"] = { text = "Check SR", dist = 0 };
UnitPopupButtons["ADD_DKP"] = { text = "Add DKP", dist = 0 };
UnitPopupButtons["Minus_DKP"] = { text = "Minus DKP", dist = 0 };
NewDKP = false
NowNotification = 1

function autoMode_OnClick()
    if this:GetChecked() then
        XyOnlyMode = 1
    else
        XyOnlyMode = 0
    end
end
-- 通告许愿信息
function notificationXY()
    if NowNotification == 1 then
        SendChatMessage("受系统发言间隔限制，本插件一次最多通报8名成员许愿信息，如列表不完整请再次点击通告按钮", "RAID", this.language, nil)
    end
    local totalMembers = getn(XyArray)
    local name, xy, DKP, EndNowNotification
    EndNowNotification = NowNotification + 7
    if totalMembers then
        for i = NowNotification, EndNowNotification do
            name = XyArray[i]["name"]
            xy = XyArray[i]["xy"]
            DKP = XyArray[i]["dkp"]
            if xy == "" or xy == nil then
                xy = "无"
            end
            SendChatMessage("许愿通报:玩家" .. i .. "【" .. name .. "】许愿道具【" .. xy .. "】,剩余DKP【" .. DKP .. "】分", "RAID", this.language, nil)
            if i == totalMembers then
                NowNotification = 1
                break
            else
                NowNotification = EndNowNotification
            end
        end
        if NowNotification > 1 then
            NowNotification = NowNotification + 1
        else
            SendChatMessage("通知：玩家许愿列表已通报完毕，请再次点击通告按钮", "RAID", this.language, nil)
        end
    end
end
-- 调用默认DKP
function printDefaultDKP()
    getglobal("allDKPFrameTXT"):SetText(DefaultDKP);
end
-- 更新默认DKP
function NEWDefaultDKP()
    DefaultDKP = getglobal("allDKPFrameTXT"):GetNumber();
    NewDKP = true
    XyTracker_OnRefreshButtonClick()
    XyTracker_UpdateList() -- 更新DKP列表
    SendChatMessage("通知：当前默认DKP为每人" .. DefaultDKP .. "分，分数已初始化", "RAID", this.language, nil)
    SendChatMessage("通知：当前默认DKP为每人" .. DefaultDKP .. "分，分数已初始化", "RAID", this.language, nil)
    SendChatMessage("通知：当前默认DKP为每人" .. DefaultDKP .. "分，分数已初始化", "RAID", this.language, nil)
end
-- 检查列表中是否包含指定元素
function contain(v, l)
    if not l then
        return false
    end
    local n = getn(l)
    if n > 0 then
        for i = 1, n do
            local lv = l[i]
            if v == lv then
                return true
            end
        end
    end
    return false
end
-- 插件加载时的初始化函数
function XyTracker_OnLoad()
    -- 在单位弹出菜单中添加“查询许愿”和“修改分数”按钮
    if UnitPopupMenus["PARTY"] then
        if not contain("GET_XY", UnitPopupMenus["PARTY"]) then
            table.insert(UnitPopupMenus["PARTY"], "GET_XY")
        end
        if not contain("ADD_DKP", UnitPopupMenus["ADD_DKP"]) then
            table.insert(UnitPopupMenus["PARTY"], "ADD_DKP")
        end
        if not contain("Minus_DKP", UnitPopupMenus["Minus_DKP"]) then
            table.insert(UnitPopupMenus["PARTY"], "Minus_DKP")
        end
    end
    -- 设置命令行指令
    SlashCmdList["XYTRACKER"] = XyTracker_OnSlashCommand
    SLASH_XYTRACKER1 = "/xyt"
    SLASH_XYTRACKER2 = "/Xytrack"
    -- 注册事件监听
    this:RegisterEvent("CHAT_MSG_SYSTEM")
    this:RegisterEvent("CHAT_MSG_PARTY")
    this:RegisterEvent("CHAT_MSG_RAID")
    this:RegisterEvent("CHAT_MSG_RAID_LEADER")
    this:RegisterEvent("CHAT_MSG_RAID_WARNING")
    this:RegisterEvent("CHAT_MSG_ADDON")
    this:RegisterEvent("CHAT_MSG_WHISPER")
    this:RegisterForDrag("LeftButton");
    -- 设置界面样式
    this:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b);
    this:SetBackdropBorderColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
    -- 备份原始单位弹出窗口点击处理函数
    ori_unitpopup1 = UnitPopup_OnClick;
    -- 替换单位弹出窗口点击处理函数
    UnitPopup_OnClick = ple_unitpopup1;
    -- 初始化变量
    if XyArray == nil then
        XyArray = {}
    end
    XyInProgress = false
    NoXyList = ""
    Xys = 0
    local autoModeButtons = getglobal("autoModeButtons");
	if XyOnlyMode == nil then XyOnlyMode = 0 end
    autoModeButtons:SetChecked(XyOnlyMode);
    XyTracker_UpdateList()
    SendAddonMessage("XY_SYNC_NEW", "", "RAID")
end
-- 替换后的单位弹出窗口点击处理函数
function ple_unitpopup1()
    local dropdownFrame = getglobal(UIDROPDOWNMENU_INIT_MENU);
    local button = this.value;
    local unit = dropdownFrame.unit;
    local name = dropdownFrame.name;
    local server = dropdownFrame.server;
    -- 处理“查询许愿”和“修改分数”按钮的点击事件
    if (button == "GET_XY") then
        XyQuery(name);
    elseif button == "ADD_DKP" then
        local info = getXyInfo(name)
        if info then
            getglobal("XyAddMember"):SetText(name);
            getglobal("XyAddDkpFramePoint"):SetText("");
            XyAddDkpFrame:Show();
        end
    elseif button == "Minus_DKP" then
        local info = getXyInfo(name)
        if info then
            getglobal("XyMinusMember"):SetText(name);
            getglobal("XyMinusDkpFramePoint"):SetText("");
            XyMinusDkpFrame:Show();
        end
    else
        -- 对于其他按钮，调用原始处理函数
        return ori_unitpopup1();
    end
    -- 播放音效
    PlaySound("UChatScrollButton");
end

-- 获取指定名字的许愿信息
function getXyInfo(name)
    local n = getn(XyArray)
    if n > 0 then
        for i = 1, n do
            local info = XyArray[i]
            if info["name"] == name then
                return info
            end
        end
    end
    return nil
end

-- 更新许愿者列表
function XyTracker_UpdateList()
    NoXyList = ""
    Xys = 0
    local totalMembers = GetNumRaidMembers()
    if totalMembers and IsLeader then
        for i = 1, totalMembers do
            local name, rank, subgroup, level, class, fileName, zone, online = GetRaidRosterInfo(i);
            local info = getXyInfo(name);
            if info then
                if NewDKP then
                    info["dkp"] = DefaultDKP
                end
                if info["xy"] and info["xy"] ~= "---No SR---" then
                    Xys = Xys + 1
                else
                    NoXyList = NoXyList .. name .. " "
                end
            else
                info = {}
                info["name"] = name
                info["class"] = class
                info["xy"] = "---No SR---"
                info["dkp"] = DefaultDKP
                table.insert(XyArray, info)
                NoXyList = NoXyList .. name .. " "
            end
        end
        NewDKP = false
    end
    XyTrackerFrameStatusText:SetText(XyTracker_If(Xys == 0, "No SR yet", string.format("%dSR recorded", Xys)))
    FauxScrollFrame_Update(XyListScrollFrame, totalMembers, 15, 25);
    if getn(XyArray) > 0 then
        local offset = FauxScrollFrame_GetOffset(XyListScrollFrame);
        for i = 1, 15 do
            k = offset + i;
            if k > getn(XyArray) then
                getglobal("XyFrameListButton" .. i):Hide();
            else
                v = XyArray[k]
                getglobal("XyFrameListButton" .. i .. "Name"):SetText(v["name"]);
                getglobal("XyFrameListButton" .. i .. "Class"):SetText(v["class"]);
                getglobal("XyFrameListButton" .. i .. "Xy"):SetText(v["xy"]);
                getglobal("XyFrameListButton" .. i .. "DKP"):SetText(v["dkp"]);
                if IsLeader then
                    getglobal("XyFrameListButton" .. i .. "AddDkp"):Show();
                    getglobal("XyFrameListButton" .. i .. "MinusDkp"):Show();
                else
                    getglobal("XyFrameListButton" .. i .. "AddDkp"):Hide();
                    getglobal("XyFrameListButton" .. i .. "MinusDkp"):Hide();
                end
                getglobal("XyFrameListButton" .. i):Show();
            end
        end
    else
        for i = 1, 15 do
            getglobal("XyFrameListButton" .. i):Hide();
        end
    end
end

function XyTracker_Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end
end

function XyTracker_If(expr, a, b)
    if expr then
        return a
    else
        return b
    end
end
function XyTracker_OnSlashCommand(msg)
    if XyTrackerFrame:IsVisible() then
        XyTracker_HideXyWindow()
    else
        XyTracker_ShowXyWindow()
    end
end

function XyTracker_ShowXyWindow()
    if DefaultDKP == nil then
        DefaultDKP = 4
    end
    ShowUIPanel(XyTrackerFrame)
    XyTracker_OnRefreshButtonClick()
end

function XyTracker_HideXyWindow()
    HideUIPanel(XyTrackerFrame)
end

function XyButton_UpdatePosition()
    XyButtonFrame:SetPoint(
            "TOPLEFT",
            "Minimap",
            "TOPLEFT",
            54 - (78 * cos(200)),
            (78 * sin(200)) - 55
    );
end

function XyTracker_OnEvent(event)
    --许愿事件
    if event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
        if XyInProgress then
            XyTracker_OnSystemMessage()
        end
    end
    --查询许愿
    if event == "CHAT_MSG_WHISPER" then
        if arg1 == "cxxy" then
            XyQuery(arg2)
        end
    end
    --团长点开始许愿,所有团员的禁用团长权限,离开队伍后恢复
    if event == "CHAT_MSG_ADDON" and arg1 == "XY_START" and not IsLeader then
        DisableLeaderOperation()
    end
    --发送许愿
    if event == "CHAT_MSG_ADDON" and arg1 == "XY_SYNC_NEW" and IsLeader then
        syncXy()
    end
    --同步许愿
    if event == "CHAT_MSG_ADDON" and arg1 == "XY_SYNC" and not IsLeader then
        receiveXySync(arg2)
    end
    --加入团队的时候请求同步数据
    if event == "CHAT_MSG_SYSTEM" and arg1 == "你加入了一个团队。" then
        SendAddonMessage("XY_SYNC_NEW", "", "RAID")
    end
    --离开队伍后恢复团长功能
    if event == "CHAT_MSG_SYSTEM" and arg1 == "你已经离开了这个团队" then
        IsLeader = false
        EnableLeaderOperation()
    end
end

function receiveXySync(msg)
    DisableLeaderOperation()
    --获取同步开始
    for n, x in string.gfind(msg, "n=(.+),x=(.+)") do
        Xys = x
        XyArray = {}
        XyTracker_UpdateList()
        return
    end
    for p, c, x, s in string.gfind(msg, "p=(.+),c=(.+),x=(.+),s=(.+)") do
        local info = {}
        info["name"] = p
        info["class"] = c
        if x == "---No SR---" then
            info["xy"] = ""
        else
            info["xy"] = x
        end
        info["dkp"] = s
        table.insert(XyArray, info)
        XyTracker_UpdateList()
    end
end

function syncXy()
    local n = getn(XyArray)
    local msg = "";
    if n > 0 then
        msg = "n=" .. n .. ",x=" .. Xys
        SendAddonMessage("XY_SYNC", msg, "RAID")
        for i = 1, n do
            local info = XyArray[i]
            local player = info["name"]
            local xy = info["xy"] or "---No SR---"
            local dkp = info["dkp"] or 4
            local class = info["class"] or "无"
            msg = "p=" .. player .. ",c=" .. class .. ",x=" .. xy .. ",s=" .. dkp
            SendAddonMessage("XY_SYNC", msg, "RAID")
        end
    end
end

function DisableLeaderOperation()
    XyInProgress = false
    getglobal("XyTrackerFrameStartButton"):Hide();
    getglobal("XyTrackerFrameStopButton"):Hide();
    getglobal("XyTrackerFrameResetButton"):Hide();
    getglobal("XyTrackerFrameAnnounceButton"):Hide();
    getglobal("XyTrackerFrameExportButton"):Hide();
    getglobal("XyTrackerFrameChuShiHua_DKP"):Hide();
    -- getglobal("XyTrackerFrameBroadcastXY"):Hide();
end

function EnableLeaderOperation()
    XyInProgress = false
    getglobal("XyTrackerFrameStartButton"):Show();
    --getglobal("XyTrackerFrameStopButton"):Show();
    getglobal("XyTrackerFrameResetButton"):Show();
    getglobal("XyTrackerFrameAnnounceButton"):Show();
    getglobal("XyTrackerFrameExportButton"):Show();
    getglobal("XyTrackerFrameChuShiHua_DKP"):Show();
    -- getglobal("XyTrackerFrameBroadcastXY"):Show();
end

function XyQuery(player, dkpnumber)
    local n = getn(XyArray)
    for i = 1, n do
        local name = XyArray[i]["name"]
        local xy = XyArray[i]["xy"]
        if not xy then
            xy = ""
        end
        if player == name then
            if dkpnumber and dkpnumber ~= 0 then
                if dkpnumber > 0 then
                    SendChatMessage(player .. " Add[" .. dkpnumber .. "]points,Current Points：[" .. XyArray[i]["dkp"] .. "]", "RAID", this.language, nil);
                else
                    SendChatMessage(player .. " Remove[" .. 0 - dkpnumber .. "]points,Current Points：[" .. XyArray[i]["dkp"] .. "]", "RAID", this.language, nil);
                end
            else
                SendChatMessage(player .. " SR[" .. xy .. "],Current Points：[" .. XyArray[i]["dkp"] .. "]", "RAID", this.language, nil);
            end
        end
    end
end

-- 处理系统消息，更新许愿信息
function XyTracker_OnSystemMessage()
    local value1, value2 = string.match(arg1, "(%S+)%s+(.*)")
    if value1 then
        if string.lower(value1) == "xy" then
            local Xy = value2
            XyTracker_OnXy(arg2, Xy)
            XyTracker_UpdateList()
            syncXy()
        elseif XyOnlyMode == 0 and string.find(arg1, "|Hitem:") then
            local Xy = arg1
            XyTracker_OnXy(arg2, Xy)
            XyTracker_UpdateList()
            syncXy()
        end
    end
end

function XyTracker_OnXy(name, Xy)
    local info = getXyInfo(name)
    info["xy"] = Xy
    XyTracker_ShowXyWindow()
end

function XyTracker_OnStartButtonClick()
    if GetNumRaidMembers() > 1 then
        IsLeader = true
		if XyOnlyMode == 1 then
			SendChatMessage("开始许愿，仅允许在团队频道输入【XY 许愿装备】可以被记录", "RAID", this.language, nil);
            SendChatMessage("Start to record SR，please input [XY ItemName] in the raid chat", "RAID", this.language, nil);
		else
			SendChatMessage("开始许愿，在团队频道输入【XY 许愿装备】或者直接贴装备链接可以被记录", "RAID", this.language, nil);
            SendChatMessage("Start to record SR，please input [XY ItemName] or post the item link directly in the raid chat", "RAID", this.language, nil);
		end
        XyInProgress = true
        XyTracker_ShowXyWindow()
        --同步到团员端
        SendAddonMessage("XY_START", "", "RAID")
    end
end

function XyTracker_OnStopButtonClick()
    SendChatMessage("许愿结束，后续许愿无效", "RAID", this.language, nil)
    SendChatMessage("Locking SR list，new input will not be recorded", "RAID", this.language, nil)
    XyInProgress = false
end

function XyTracker_OnClearButtonClick()
    XyArray = {}
    local totalMembers = GetNumRaidMembers()
    if totalMembers then
        for i = 1, totalMembers do
            local name, rank, subgroup, level, class, fileName, zone, online = GetRaidRosterInfo(i);
            info = {}
            info["name"] = name
            info["class"] = class
            info["dkp"] = 4
            info["xy"] = "---No SR---"
            table.insert(XyArray, info)
            NoXyList = NoXyList .. name .. " "
        end
    end
    XyTracker_UpdateList()
    if IsLeader then
        syncXy()
    end
end

function XyTracker_OnRefreshButtonClick()
    local totalMembers = GetNumRaidMembers()
    if totalMembers and IsLeader then
        local newXyArray = {}
        --保留许愿了但是离开团队的人
        for i = 1, getn(XyArray) do
            local info = XyArray[i]
            local name = info["name"]
            local xy = info["xy"]
            if xy == nil or xy == "" then
                xy = "---No SR---"
            end
            local online = false
            for j = 1, totalMembers do
                local name2, rank, subgroup, level, class, fileName, zone, online2 = GetRaidRosterInfo(j);
                if name == name2 then
                    online = true
                    break
                end
            end
            if xy or online then
                table.insert(newXyArray, info)
            end
        end
        XyArray = newXyArray
        syncXy()
    end
    XyTracker_UpdateList()
end

function XyTracker_OnAnnounceButtonClick()
    if NoXyList == "" then
        SendChatMessage("所有人都已经许愿", "RAID", this.language, nil);
        SendChatMessage("Everyone has done their SR", "RAID", this.language, nil);
    else
        SendChatMessage("以下人员未许愿，请尽快许愿：" .. NoXyList, "RAID", this.language, nil);
        SendChatMessage("Missing SR from the following ppl：" .. NoXyList, "RAID", this.language, nil);
    end
end

function XyTracker_OnExportButtonClick()
    local n = getn(XyArray)
    local csvText = ""
    for i = 1, n do
        local xy = XyArray[i]["xy"]
        if not xy then
            xy = ""
        end
        csvText = csvText .. XyArray[i]["class"] .. "-" .. XyArray[i]["name"] .. "-" .. xy .. "-Current Points:[" .. XyArray[i]["dkp"] .. "]" .. "\n"
    end
    getglobal("XyExportEdit"):SetText(csvText);
    getglobal("XyExportFrame"):Show();
end

function Xy_FixZero(num)
    if (num < 10) then
        return "0" .. num;
    else
        return num;
    end
end

function Xy_Date()
    local t = date("*t");

    return strsub(t.year, 3) .. "-" .. Xy_FixZero(t.month) .. "-" .. Xy_FixZero(t.day) .. " " .. Xy_FixZero(t.hour) .. ":" .. Xy_FixZero(t.min) .. ":" .. Xy_FixZero(t.sec);
end

function XyAddDkp()
    player = getglobal("XyAddMember"):GetText(); -- 获取玩家姓名
    dkppoint = getglobal("XyAddDkpFramePoint"):GetNumber(); -- 获取要家增的DKP点数
    if dkppoint == nil then
        dkppoint = 0
    end
    local info = getXyInfo(player) -- 获取玩家信息
    if info then
        info["dkp"] = info["dkp"] + dkppoint -- 更新DKP点数
        XyTracker_UpdateList() -- 更新DKP列表
        XyQuery(player, dkppoint);
    end
    syncXy()
end

-- 为指定玩家扣除DKP点数
function XyMinusDkp()
    player = getglobal("XyMinusMember"):GetText(); -- 获取玩家姓名
    dkppoint = getglobal("XyMinusDkpFramePoint"):GetNumber(); -- 获取要扣除的DKP点数
    if dkppoint == nil then
        dkppoint = 0
    end
    local info = getXyInfo(player) -- 获取玩家信息
    if info then
        info["dkp"] = info["dkp"] - dkppoint -- 更新DKP点数
        XyTracker_UpdateList() -- 更新DKP列表
        XyQuery(player, 0 - dkppoint);
    end
    syncXy()
end
-- 设置DKP排序选项
function XySortOptions(method)

    if (Xy_SortOptions.method and Xy_SortOptions.method == method) then
        if (Xy_SortOptions.itemway and Xy_SortOptions.itemway == "asc") then
            Xy_SortOptions.itemway = "desc";
        else
            Xy_SortOptions.itemway = "asc";
        end
    else
        Xy_SortOptions.method = method;
        Xy_SortOptions.itemway = "asc";
    end
    Xy_SortDkp();
    XyTracker_UpdateList();
end

function Xy_SortDkp()
    table.sort(XyArray, Xy_CompareDkps);
end

function Xy_CompareDkps(a1, a2)
    local method, way = Xy_SortOptions["method"], Xy_SortOptions["itemway"];
    local c1, c2 = a1[method], a2[method];
    if (way == "asc") then
        return c1 < c2;
    else
        return c1 > c2;
    end
end