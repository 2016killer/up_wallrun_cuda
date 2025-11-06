--------------------------------菜单
local UltiPar = UltiPar
local convars = {
	{
		name = 'wr_h_mustlookatwall',
		default = '0',
		widget = 'CheckBox'
	},

	{
		name = 'wr_h_lifetime',
		default = '1.2',
		widget = 'NumSlider',
		min = 0,
		max = 2
	},
}

UltiPar.CreateConVars(convars)
local wr_h_mustlookatwall = GetConVar('wr_h_mustlookatwall')
local wr_h_lifetime = GetConVar('wr_h_lifetime')
local sv_gravity = GetConVar('sv_gravity')

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
        eyeXYDir:Dot(ref),
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
    
    if ply:GetVelocity()[3] < -math.abs(sv_gravity:GetFloat()) then
        return
    end

    local traceground = util.QuickTrace(
        ply:GetPos(), 
        Vector(0, 0, -20), 
        ply
    )
    
    if traceground.Hit then 
        ply.LastWallForward = nil 
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

    if ply.LastWallForward and ply.LastWallForward:Dot(wallForward) > 0.64 then
        return
    end

    if wr_h_mustlookatwall:GetBool() and ply:GetEyeTrace().HitNormal:Dot(wallForward) < 0.07 then
        return 
    elseif -loscosForward > 0.5 then
        return 
    end


    local traceup = util.TraceHull({
        filter = ply, 
        mask = MASK_PLAYERSOLID,
        start = ply:GetPos() + 2 * wallForward,
        endpos = ply:GetPos() + (traceground.Hit and 25 or 0) * wallUp + 2 * wallForward,
        mins = bmins,
        maxs = bmaxs,
    })

    if traceup.StartSolid or traceup.Hit then
        return
    end

 
    ply.LastWallForward = wallForward
    
    local duration = self:Duration(ply)
    local isright = (loscosRight > 0 and 1 or -1)
    local rundir = isright * wallRight
    
    return {
        traceup.HitPos, 
        wallForward,
        rundir,
        duration,
        isright
    }
end

function action:Start(ply, data)
    if CLIENT then return end
    local startpos, wallForward, rundir, duration, isright = unpack(data)
    local startspeed, endspeed = self:GetSpeed(ply, ply:GetVelocity(), rundir)
 
    UltiPar.SetMoveControl(ply, true, true, IN_DUCK, 0)

    ply.wr_h_data = {
        startpos = startpos,
        speed = startspeed,
        endspeed = endspeed,
        dir = rundir,
        duration = duration,
        dir2 = wallForward,
        acc = (endspeed - startspeed) / duration
    }

    return {isright}
end

function action:Play(ply, mv, cmd, _, starttime)
    if CLIENT then return end
    if not ply.wr_h_data then 
        return 
    end
    
    local movedata = ply.wr_h_data
    local curtime = CurTime()
    local dt = FrameTime()

    mv:SetVelocity(movedata.speed * movedata.dir)
    local target = movedata.target or 0

    if curtime - starttime < movedata.duration then 
        target = target + movedata.speed * dt
        
        mv:SetOrigin(
            LerpVector(
                math.Clamp((curtime - starttime) / 1, 0, 1), 
                ply:GetPos(), 
                movedata.startpos + target * movedata.dir
            )
        ) 
        
        movedata.target = target
        movedata.speed = dt * movedata.acc + movedata.speed
    else
        return {type = 'normal', mv = mv}
    end

    -- 检测跳跃键
    local keydown_injump = ply:KeyDown(IN_JUMP)
    if curtime - starttime > 0.1 and movedata.keydown_injump == false and keydown_injump then
        return {type = 'jump', mv = mv}
    end
    movedata.keydown_injump = keydown_injump

    if curtime - (movedata.lasttime or 0) > 0.1 then
        movedata.lasttime = curtime
        local bmins, bmaxs = ply:GetHull()

        local hitwallforward = util.QuickTrace(ply:EyePos(), -movedata.dir2 * bmaxs[1] * 2, ply)
        if not hitwallforward.Hit then
            return {type = 'hit', mv = mv}
        end

        local hitrundir = util.TraceHull({
            filter = ply, 
            mask = MASK_PLAYERSOLID,
            start = ply:GetPos() + 1 * movedata.dir2,
            endpos = ply:GetPos() + movedata.dir * 20 + 1 * movedata.dir2,
            mins = bmins,
            maxs = bmaxs,
        })

        if hitrundir.Hit or hitrundir.StartSolid then
            return {type = 'hit', mv = mv}
        end
    end
end

function action:Clear(ply, _, endresult, breaker)
    if CLIENT then return end

    ply.wr_h_data = nil

    if breaker and not isbool(breaker) and string.StartWith(breaker.Name, 'DParkour-') then
        return
    end
    
    UltiPar.SetMoveControl(ply, false, false, 0, 0)
    
    if endresult then 
        if endresult.type == 'jump' then
            local jumpvel = self:JumpVel(ply, ply:GetVelocity())
            endresult.mv:SetVelocity(jumpvel) 
            endresult.mv = nil
        else
            endresult.mv = nil
        end
    end
end

hook.Add('OnPlayerHitGround', 'wallrun.reset', function(ply, key)
    ply.LastWallForward = nil
end)

if SERVER then
    hook.Add('KeyPress', 'hwallrun.trigger', function(ply, key)
        if key == IN_JUMP then UltiPar.Trigger(ply, action) end
    end)
end