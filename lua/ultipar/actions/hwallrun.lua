--------------------------------菜单
local UltiPar = UltiPar
local convars = {
	{
		name = 'wr_h_mustlookatwall',
		default = '1',
		widget = 'CheckBox'
	},

	{
		name = 'wr_h_lifetime',
		default = '1.2',
		widget = 'NumSlider',
		min = 0,
		max = 2
	},

	{
		name = 'wr_h_dietime',
		default = '1',
		widget = 'NumSlider',
		min = 1,
		max = 5,
        decimals = 0,
        help = true
	},

	{
		name = 'wr_h_diespeed',
		default = '600',
		widget = 'NumSlider',
		min = 10,
		max = 1000,
        decimals = 0,
        help = true
	},

}

UltiPar.CreateConVars(convars)
local wr_h_mustlookatwall = GetConVar('wr_h_mustlookatwall')
local wr_h_lifetime = GetConVar('wr_h_lifetime')
local wr_h_dietime = GetConVar('wr_h_dietime')
local wr_h_diespeed = GetConVar('wr_h_diespeed')

local actionName = 'HWallRun'
local action, _ = UltiPar.Register(actionName)

if CLIENT then
	action.label = '#wr.hwallrun'
	action.icon = 'wallrun/icon.jpg'

	action.CreateOptionMenu = function(panel)
		UltiPar.CreateConVarMenu(panel, convars)
	end
else
	convars = nil
end
----------------------------------动作逻辑
function action:JumpVel(ply, ref)
    local eyeXYDir = UltiPar.XYNormal(ply:EyeAngles():Forward())
    return eyeXYDir * math.max(
        ref:Length(),
        (ply:GetWalkSpeed() + ply:GetRunSpeed()) * 0.5
    ) + ply:GetJumpPower() * Vector(0, 0, 1.25)
end

function action:GetSpeed(ply, ref, rundir)
    local startspeed = math.max(
        ref:Dot(rundir), 
        ply:GetJumpPower() * 0.25 + ply:GetWalkSpeed()
    )
    return startspeed, startspeed
end

function action:Duration(ply)
    return wr_h_lifetime:GetFloat()
end

local function wallcoordinate(wallforward)
    local wallup = -wallforward[3] * wallforward + Vector(0, 0, math.sqrt(1 - wallforward[3] ^ 2))
    local wallright = wallup:Cross(wallforward)

    return wallforward, wallright, wallup
end

function action:Check(ply)
    if ply:GetMoveType() ~= MOVETYPE_WALK or not ply:KeyDown(IN_FORWARD) or ply:InVehicle() then
        return
    end
    
    if ply:GetVelocity()[3] < -math.abs(wr_h_diespeed:GetFloat()) then
        return
    end

    local traceground = util.QuickTrace(
        ply:GetPos(), 
        Vector(0, 0, -20), 
        ply
    )
    
    if traceground.Hit then 
        ply.LastWallForward = nil 
        ply.VWallDieTime = 0
    end

    local bmins, bmaxs = ply:GetHull()

    local traceleft = util.QuickTrace(
        ply:EyePos(), 
        -bmaxs[1] * 2 * ply:EyeAngles():Right() - Vector(0, 0, 0.5 * bmaxs[3]), 
        ply
    )

    local traceright = util.QuickTrace(
        ply:EyePos(), 
        bmaxs[1] * 2 * ply:EyeAngles():Right() - Vector(0, 0, 0.5 * bmaxs[3]), 
        ply
    )

    if traceright.StartSolid or traceleft.StartSolid or (not traceright.Hit and not traceleft.Hit) then
        return
    end

    local hittrace = traceright.Hit and traceright or traceleft

    -- 检查对准墙壁
    -- cos(45°) = 0.707
    -- sin(15°) = 0.26
    local wallForward, wallRight, wallUp = wallcoordinate(hittrace.HitNormal)
    local loscosRight = UltiPar.XYNormal(ply:EyeAngles():Forward()):Dot(wallRight)
    local loscosForward = UltiPar.XYNormal(ply:EyeAngles():Forward()):Dot(UltiPar.XYNormal(wallForward))

    local isright = (loscosRight > 0 and 1 or -1)
    local rundir = isright * wallRight

    if ply.LastWallForward and ply.LastWallForward:Dot(wallForward) > 0.64 then
        ply.HWallDieTime = (ply.HWallDieTime or 0) + 1

        if ply.HWallDieTime >= wr_h_dietime:GetInt() then
            return
        end
    end


    if wr_h_mustlookatwall:GetBool() and ply:GetEyeTrace().Normal:Dot(wallForward) > 0 then
        return 
    elseif -loscosForward > 0.5 then
        return 
    end


    local traceup = util.TraceHull({
        filter = ply, 
        mask = MASK_PLAYERSOLID,
        start = ply:GetPos() + 2 * wallForward,
        endpos = ply:GetPos() + (traceground.Hit and 25 or 0) * wallUp + 2 * wallForward + rundir * 25,
        mins = bmins,
        maxs = bmaxs,
    })

    if traceup.StartSolid or traceup.Hit then
        return
    end

 
    ply.LastWallForward = wallForward
    
    local duration = self:Duration(ply)
    
    
    local startspeed, endspeed = self:GetSpeed(ply, ply:GetVelocity(), rundir)
 
    return isright,
        traceup.HitPos, 
        startspeed,
        endspeed,
        rundir,
        duration,
        wallForward,
        CurTime()
end

function action:Start(ply, data)
    if CLIENT then return end
    UltiPar.WriteMoveControl(ply, true, true, IN_DUCK, 0)
end

function action:Play(ply, mv, cmd, 
        isright,
        startpos,
        startspeed,
        endspeed,
        dir,
        duration,
        dir2,
        starttime
    )
    if CLIENT then return end
    local acc = (endspeed - startspeed) / duration
    
    local curtime = CurTime()
    local dt = FrameTime()

    mv:SetVelocity(endspeed * dir)
    local target = ply.wr_h_target or 0
    local speed = ply.wr_h_speed or startspeed

    if curtime - starttime < duration then 
        target = target + speed * dt
        
        mv:SetOrigin(
            LerpVector(
                math.Clamp((curtime - starttime) / 1, 0, 1), 
                ply:GetPos(), 
                startpos + target * dir
            )
        ) 
        
        ply.wr_h_target = target
        ply.wr_h_speed = dt * acc + speed
    else
        return 'normal'
    end

    -- 检测跳跃键
    local keydown_injump = ply:KeyDown(IN_JUMP)
    if curtime - starttime > 0.1 and ply.wr_h_keydown_injump == false and keydown_injump then
        return 'jump'
    end
    ply.wr_h_keydown_injump = keydown_injump

    if curtime - (ply.wr_h_lasttime or 0) > 0.1 then
        ply.wr_h_lasttime = curtime
        local bmins, bmaxs = ply:GetHull()

        local hitwallforward = util.QuickTrace(ply:EyePos(), -dir2 * bmaxs[1] * 2, ply)
        if not hitwallforward.Hit then
            return 'hit'
        end

        local hitrundir = util.TraceHull({
            filter = ply, 
            mask = MASK_PLAYERSOLID,
            start = ply:GetPos() + 1 * dir2,
            endpos = ply:GetPos() + dir * 50 + 1 * dir2,
            mins = bmins,
            maxs = bmaxs,
        })

        if hitrundir.Hit or hitrundir.StartSolid then
            return 'hit'
        end
    end
end


function action:Clear(ply, mv, cmd, endtype)
    if CLIENT then return end

    ply.wr_h_target = nil
    ply.wr_h_speed = nil
    ply.wr_h_keydown_injump = nil
    ply.wr_h_lasttime = nil

    if endtype == 'jump' then
        mv:SetVelocity(self:JumpVel(ply, ply:GetVelocity())) 
    end
end

hook.Add('OnPlayerHitGround', 'hwallrun.reset', function(ply, key)
    ply.LastWallForward = nil
    ply.HWallDieTime = 0
end)

if SERVER then
    hook.Add('KeyPress', 'hwallrun.trigger', function(ply, key)
        if key == IN_JUMP then UltiPar.Trigger(ply, action) end
    end)
end