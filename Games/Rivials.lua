-- Control Settings
local Settings = {
    Highlight = {
        Enabled = true;
        Teamcheck = false;
        Transparency = .7;
        EnemyColor = Color3.fromRGB(255, 0, 0);
        EnemyColorRainbow = true;
        TeamColor = Color3.fromRGB(0, 255, 0);
        TeamColorRainbow = false;
    };

    Aimbot = {
        Enabled = true;
        Radius = 200;
        TargetPart = 'Head';
        VisibleCheck = true;
        TimeToTarget = .5;
        Teamcheck = true;
        Color = Color3.fromRGB(225, 106, 255);
        Rainbow = true;
    }
}

repeat task.wait() until game:IsLoaded()

-- Unload script if loaded
if(getgenv().RivalsScript and getgenv().RivalsScript.Unload) then
    local unloaded = getgenv().RivalsScript.Unload()
    if(unloaded ~= true) then
        print('Attempt to unload script failed, errors may occur')
    end
end

-- Globals
getgenv().RivalsScript = {}

-- Services
local WorkspaceService = game:GetService("Workspace")
local PlayersService = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

-- Vars
local LocalPlayer = PlayersService.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local GuiInset = GuiService:GetGuiInset()
local Camera = WorkspaceService.CurrentCamera
local WorldToScreen = Camera.WorldToScreenPoint

-- Internal Vars
local Internals = {
    Connections = {};
    HiddenGui = gethui();
    Highlights = {};
    Drawings = {};

    Aimbot = {
        On = false;
        FovDrawing = nil;
        ElapsedTime = 0;
        Target = nil;
    }
}

-- Internal Functions
local function Unload()
    print('Unloading Script')

    -- Disconnect all connections
    for _, v in pairs(Internals.Connections) do
        v:Disconnect()
    end

    -- Destroy hidden ui children
    for _, v in pairs(Internals.HiddenGui:GetChildren()) do
        v:Destroy()
    end

    -- Destroy drawings
    for _, v in pairs(Internals.Drawings) do
        v:Remove()
    end

    -- Clear global space
    getgenv().RivalsScript = nil

    print('Unloaded Script')

    return true
end
getgenv().RivalsScript.Unload = Unload

-- Functions

function IsTeammate(player)
    if(player.Character and player.Character:FindFirstChild('HumanoidRootPart')) then
        return player.Character.HumanoidRootPart:FindFirstChild('TeammateLabel') ~= nil
    end

    return false
end

-- Highlight Functions
function AddPlayerHighlight(player)
    local hl = Instance.new('Highlight')
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = Internals.HiddenGui
    hl.FillTransparency = (IsTeammate(player) and Settings.Highlight.Teamcheck) and 1 or Settings.Highlight.Transparency
    hl.OutlineTransparency = (IsTeammate(player) and Settings.Highlight.Teamcheck) and 1 or 0
    hl.OutlineColor = (IsTeammate(player)) and Settings.Highlight.TeamColor or Settings.Highlight.EnemyColor
    hl.FillColor = (IsTeammate(player)) and Settings.Highlight.TeamColor or Settings.Highlight.EnemyColor
    Internals.Highlights[player.Name] = hl

    if(player.Character) then
        hl.Adornee = player.Character
    end

    local con = player.CharacterAdded:Connect(function(character)
        hl.Adornee = character
    end)
    table.insert(Internals.Connections, con)

end

function RemovePlayerHighlight(player)
    if(Internals.Highlights[player.Name]) then
        Internals.Highlights[player.Name]:Destroy()
        Internals.Highlights[player.Name] = nil
    end
end

function UpdatePlayerHighlight(player)
    local hl = Internals.Highlights[player.Name]
    local rainbowColor = Color3.fromHSV((os.clock()/5) % 1, 1, 1)
    local color = nil
    local isTeammate = IsTeammate(player)

    if(isTeammate and Settings.Highlight.TeamColorRainbow) then
        color = rainbowColor
    elseif(not isTeammate and Settings.Highlight.EnemyColorRainbow) then
        color = rainbowColor
    else
        color = (isTeammate) and Settings.Highlight.TeamColor or Settings.Highlight.EnemyColor
    end

    hl.FillTransparency = (isTeammate and Settings.Highlight.Teamcheck) and 1 or Settings.Highlight.Transparency
    hl.OutlineTransparency = (isTeammate and Settings.Highlight.Teamcheck) and 1 or 0
    hl.OutlineColor = color
    hl.FillColor = color
end

-- Aimbot Functions
function FindClosestPlayer()
    local closestPlayer = nil
    local closestDist = nil

    for _, v in pairs(PlayersService:GetPlayers()) do 
        if((Settings.Aimbot.Teamcheck and IsTeammate(v)) or (v == LocalPlayer) or (v.Character == nil) or (v.Character:FindFirstChild(Settings.Aimbot.TargetPart) == nil)) then continue end

        local screenPoint, _ = WorldToScreen(Camera, v.Character:FindFirstChild(Settings.Aimbot.TargetPart).CFrame.Position)
        if(screenPoint.Z < 0) then continue end
        if(Settings.Aimbot.VisibleCheck and not IsVisible(v)) then continue end;

        local dist = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(screenPoint.X, screenPoint.Y)).Magnitude
        if(dist > Settings.Aimbot.Radius) then continue end

        if(closestPlayer == nil) then 
            closestPlayer = v
            closestDist = dist
            continue
        end

        if(closestDist > dist) then
            closestDist = dist
            closestPlayer = v
        end
    end

    return closestPlayer
end

function IsVisible(player)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {player.Character, LocalPlayer.Character}

    local origin = Camera.CFrame.Position
    local target = player.Character:FindFirstChild(Settings.Aimbot.TargetPart).Position
    local result = WorkspaceService:Raycast(origin, (target-origin), raycastParams)

    if(result == nil) then
        return true
    end

    return false
end

-- Main

-- Settup Highlight
if(Settings.Highlight.Enabled) then
    -- Settup existing players
    for _, v in pairs(PlayersService:GetPlayers()) do
        if(v == LocalPlayer) then continue end

        AddPlayerHighlight(v)
    end

    -- Settup new players
    local con = PlayersService.PlayerAdded:Connect(AddPlayerHighlight)
    table.insert(Internals.Connections, con)

    -- Cleanup on leave
    local con = PlayersService.PlayerRemoving:Connect(RemovePlayerHighlight)
    table.insert(Internals.Connections, con)
end

-- Settup Aimbot
if(Settings.Aimbot.Enabled) then
    local fovDrawing = Drawing.new('Circle')
    fovDrawing.Transparency = 1
    fovDrawing.Thickness = 2
    fovDrawing.NumSides = 100
    fovDrawing.Radius = Settings.Aimbot.Radius
    fovDrawing.Filled = false
    fovDrawing.Color = Color3.fromRGB(100,255,100)
    fovDrawing.Position = Vector2.new(100, 100)
    fovDrawing.Visible = true
    Internals.Aimbot.FovDrawing = fovDrawing
    table.insert(Internals.Drawings, fovDrawing)

    local con = Mouse.Button2Down:Connect(function()
        Internals.Aimbot.On = true
    end)
    table.insert(Internals.Connections, con)

    local con = Mouse.Button2Up:Connect(function()
        Internals.Aimbot.On = false
        Internals.Aimbot.ElapsedTime = 0
        Internals.Aimbot.Target = nil;
    end)
    table.insert(Internals.Connections, con)

    local con = Mouse.Move:Connect(function()
        fovDrawing.Position = Vector2.new(Mouse.X, Mouse.Y + GuiInset.Y)
    end)
    table.insert(Internals.Connections, con)
end

-- Main Loop
local con = RunService.RenderStepped:Connect(function(dt)
    -- Update player highlight
    for i, v in pairs(Internals.Highlights) do
        local player = PlayersService:FindFirstChild(i)
        if player == nil then continue end

        UpdatePlayerHighlight(player)
    end

    -- Aimbot
    if(Settings.Aimbot.Enabled) then
        -- Update aimbot visuals
        if(Settings.Aimbot.Rainbow) then
            Internals.Aimbot.FovDrawing.Color = Color3.fromHSV((os.clock()/5) % 1, 1, 1)
        end

        -- Move mouse
        if(Internals.Aimbot.On) then
            local alpha = math.clamp(Internals.Aimbot.ElapsedTime / Settings.Aimbot.TimeToTarget, 0, 1)
            local targetPlayer = Internals.Aimbot.Target

            if(targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild(Settings.Aimbot.TargetPart) and targetPlayer:FindFirstChild('Humanoid') and targetPlayer:FindFirstChild('Humanoid').Health > 0) then
                targetPlayer = Internals.Aimbot.Target
            else
                targetPlayer = FindClosestPlayer()
            end

            if(targetPlayer) then
                Internals.Aimbot.Target = targetPlayer
                Internals.Aimbot.ElapsedTime += dt

                local targetPart = targetPlayer.Character:FindFirstChild(Settings.Aimbot.TargetPart)
                local screenPoint, visible = WorldToScreen(Camera, targetPart.CFrame.Position)
                
                if((Settings.Aimbot.VisibleCheck and IsVisible(targetPlayer)) or not Settings.Aimbot.VisibleCheck) then 
                    local mouseDelta = Vector2.new(screenPoint.X - Mouse.X, screenPoint.Y - Mouse.Y)
                    mousemoverel(mouseDelta.X * alpha, mouseDelta.Y * alpha)
                end
            else
                Internals.Aimbot.ElapsedTime = 0
            end
        end
    end

    task.wait()
end)
table.insert(Internals.Connections, con)

print('Script Loaded' )