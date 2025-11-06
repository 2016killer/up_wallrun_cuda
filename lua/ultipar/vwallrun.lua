--------------------------------菜单
local UltiPar = UltiPar
local convars = {
	{
		name = 'wr_v_lifetime',
		default = '0.5',
		widget = 'NumSlider',
		min = 0,
		max = 2
	},
}

UltiPar.CreateConVars(convars)
local wr_v_lifetime = GetConVar('wr_v_lifetime')
local sv_gravity = GetConVar('sv_gravity')

local actionName = 'VWallRun'
local action, _ = UltiPar.Register(actionName)

if CLIENT then
	action.label = '#wr.vwallrun'
	action.icon = 'wallrun/icon.jpg'

	action.CreateOptionMenu = function(panel)
		UltiPar.CreateConVarMenu(panel, convars)
	end
else
	convars = nil
end
----------------------------------动作逻辑
action.Interrupts['DParkour-LowClimb'] = true
action.Interrupts['DParkour-HighClimb'] = true


function action:JumpVel(ply)
    return UltiPar.XYNormal(ply:EyeAngles():Forward()) * (ply:GetWalkSpeed() + ply:GetRunSpeed()) * 0.5 +
    ply:GetJumpPower() * Vector(0, 0, 1)
end

function action:GetSpeed(ply)
    return ply:GetJumpPower() + ply:GetWalkSpeed(), -50
end

function action:Gravity(ply)
    return -sv_gravity:GetFloat() * 0.7
end

function action:RunDistance(ply)
    return 150
end

function action:Duration(ply)
    local startspeed, endspeed = self:GetSpeed(ply)
    return (endspeed - startspeed) / self:Gravity(ply), wr_v_lifetime:GetFloat()
end

function action:Check(ply)
    if ply:GetMoveType() ~= MOVETYPE_WALK and not ply:KeyDown(IN_FORWARD) then
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
    local rundis = self.RunDistance(ply)

    local traceforward0 = util.QuickTrace(
        ply:GetPos() + Vector(0, 0, rundis * 0.6), 
        bmaxs[1] * 4 * UltiPar.XYNormal(ply:EyeAngles():Forward()), 
        ply
    )

    local traceforward = util.QuickTrace(
        ply:EyePos(), 
        bmaxs[1] * 2 * UltiPar.XYNormal(ply:EyeAngles():Forward()), 
        ply
    )


    -- 太矮的不触发
    if traceforward.StartSolid or traceforward0.StartSolid or not traceforward0.Hit or not traceforward.Hit then
        return
    end

    -- 检测是否最后一次蔷跑与当前墙壁方向相似和对准墙壁和墙壁倾斜
    -- cos(50°) = 0.64
    -- cos(45°) = 0.707
    -- sin(15°) = 0.26
    local wallForward = traceforward.HitNormal

    if ply.LastWallForward and ply.LastWallForward:Dot(wallForward) > 0.64 then
        return
    end

    if wallForward[3] > 0.26 or wallForward[3] < -0.26 or 
        UltiPar.XYNormal(ply:EyeAngles():Forward()):Dot(UltiPar.XYNormal(Vector(-wallForward))) < 0.707 then
        return
    end

    local wallUp = -wallForward[3] * wallForward + Vector(0, 0, math.sqrt(1 - wallForward[3] ^ 2))
     

    -- 检测一下能跑多高
    local pos = ply:GetPos() + UltiPar.unitzvec
    
    local traceup = util.TraceHull({
        filter = ply, 
        mask = MASK_PLAYERSOLID,
        start = pos,
        endpos = pos + wallUp * rundis,
        mins = bmins,
        maxs = bmaxs,
    })


    if traceup.StartSolid then
        return
    end

    rundis = traceup.Fraction * rundis

    ply.LastWallForward = wallForward
    
    local duration, lifetime = self:Duration(ply)

    if duration < 0 or duration == math.huge or duration == -math.huge then
        return
    end

    return {
        traceup.HitPos, 
        rundis, 
        wallForward, 
        wallUp,
        duration,
        lifetime
    }
end

function action:Start(ply, data)
    if CLIENT then return end
    local startpos, rundis, wallForward, wallUp, duration, lifetime = unpack(data)
    local startspeed, endspeed = self:GetSpeed(ply)
    local acc = self:Gravity(ply)

    UltiPar.SetMoveControl(ply, true, true, IN_DUCK, 0)

    ply.wr_v_data = {
        startpos = ply:GetPos(),
        speed = startspeed,
        endspeed = endspeed,
        acc = acc,
        dir = wallUp,
        duration = duration,
        lifetime = lifetime,
        dir2 = wallForward,
    }

    return {duration, lifetime}
end

function action:Play(ply, mv, cmd, _, starttime)
    if CLIENT then return end
    if not ply.wr_v_data then 
        return 
    end
    mv:SetVelocity(Vector())

    local movedata = ply.wr_v_data
    local dt = FrameTime()

    movedata.timer = (movedata.timer or 0) + dt
    local target = movedata.target or 0

    if movedata.timer < movedata.duration + movedata.lifetime then 
        if (movedata.acc < 0 and movedata.speed < movedata.endspeed) or (movedata.acc > 0 and movedata.speed > movedata.endspeed) then
            target = target + movedata.endspeed * dt
        else
            target = target + movedata.speed * dt
        end

        mv:SetOrigin(
            LerpVector(
                math.Clamp(movedata.timer / 0.1, 0, 1), 
                ply:GetPos(), 
                movedata.startpos + target * movedata.dir
            )
        ) 
        
        movedata.target = target
        movedata.speed = dt * movedata.acc + movedata.speed
    else
        return {type = 'normal', mv = mv}
    end


    local curtime = CurTime()
    
    -- 检测跳跃键
    local keydown_injump = ply:KeyDown(IN_JUMP)
    if curtime - starttime > 0.3 and movedata.keydown_injump == false and keydown_injump then
        return {type = 'jump', mv = mv}
    end
    movedata.keydown_injump = keydown_injump

    if curtime - (movedata.lasttime or 0) > 0.1 then
        if math.abs(movedata.speed) < 150 then
            timer.Remove('wallrunhfoot')
        end

        movedata.lasttime = curtime
        local bmins, bmaxs = ply:GetHull()

        local hitforward = util.QuickTrace(ply:EyePos(), -movedata.dir2 * bmaxs[1] * 2, ply)
        if not hitforward.Hit then
            return {type = 'hit', mv = mv}
        end

        local hitup = util.TraceHull({
            filter = ply, 
            mask = MASK_PLAYERSOLID,
            start = ply:GetPos() + 1 * movedata.dir2,
            endpos = ply:GetPos() + movedata.dir * 20 + 1 * movedata.dir2,
            mins = bmins,
            maxs = bmaxs,
        })

        if hitup.Hit or hitup.StartSolid then
            return {type = 'hit', mv = mv}
        end
    end
end

function action:Clear(ply, _, endresult, breaker)
    if CLIENT then return end

    ply.wr_v_data = nil

    if breaker and not isbool(breaker) and string.StartWith(breaker.Name, 'DParkour-') then
        return
    end
    
    UltiPar.SetMoveControl(ply, false, false, 0, 0)
    
    if endresult then 
        if endresult.type == 'jump' then
            endresult.mv:SetVelocity(self:JumpVel(ply)) 
            endresult.mv = nil
        else
            endresult.mv:SetVelocity(UltiPar.unitzvec) 
            endresult.mv = nil
        end
    end
end

hook.Add('OnPlayerHitGround', 'wallrun.reset', function(ply, key)
    ply.LastWallForward = nil
end)

if SERVER then
    hook.Add('KeyPress', 'wallrun.trigger', function(ply, key)
        if key == IN_JUMP then UltiPar.Trigger(ply, action) end
    end)
end