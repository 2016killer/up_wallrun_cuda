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

	{
		name = 'wr_v_dietime',
		default = '1',
		widget = 'NumSlider',
		min = 1,
		max = 5,
        decimals = 0,
        help = true
	},

	{
		name = 'wr_v_diespeed',
		default = '600',
		widget = 'NumSlider',
		min = 10,
		max = 1000,
        decimals = 0,
        help = true
	},

    {
		name = 'wr_v_gravity',
		default = '420',
		widget = 'NumSlider',
		min = 10,
		max = 1000,
        decimals = 0,
        help = true
	},
}

UltiPar.CreateConVars(convars)
local wr_v_lifetime = GetConVar('wr_v_lifetime')
local wr_v_gravity = GetConVar('wr_v_gravity')
local wr_v_dietime = GetConVar('wr_v_dietime')
local wr_v_diespeed = GetConVar('wr_v_diespeed')

local actionName = 'VWallRun'
local action, _ = UltiPar.Register(actionName)

if CLIENT then
	action.icon = 'wallrun/icon.jpg'

	action.CreateOptionMenu = function(panel)
		UltiPar.CreateConVarMenu(panel, convars)
	end
else
	convars = nil
end
----------------------------------动作逻辑
function action:JumpVel(ply)
    return UltiPar.XYNormal(ply:EyeAngles():Forward()) * (ply:GetWalkSpeed() + ply:GetRunSpeed()) * 0.5 +
    ply:GetJumpPower() * Vector(0, 0, 1)
end

function action:GetDieTime(ply)
    return wr_v_dietime:GetFloat()
end

function action:GetSpeed(ply)
    return ply:GetJumpPower() + ply:GetWalkSpeed(), -50
end

function action:Gravity(ply)
    return -wr_v_gravity:GetFloat()
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
    
    if ply:GetVelocity()[3] < -math.abs(wr_v_diespeed:GetFloat()) then
        return
    end

    local traceground = util.QuickTrace(
        ply:GetPos(), 
        Vector(0, 0, -20), 
        ply
    )
    
    if traceground.Hit then 
        ply.LastWallForward2 = nil 
        ply.VWallDieTime = 0
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

    if ply.LastWallForward2 and ply.LastWallForward2:Dot(wallForward) > 0.64 then
        ply.VWallDieTime = (ply.VWallDieTime or 0) + 1

        if ply.VWallDieTime >= wr_v_dietime:GetInt() then
            return
        end
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

    ply.LastWallForward2 = wallForward
    ply.LastWallForward = wallForward
    local duration, lifetime = self:Duration(ply)

    if duration < 0 or duration == math.huge or duration == -math.huge then
        return
    end


    return ply:GetPos(),
        wallUp,
        duration,
        lifetime,
        wallForward,
        CurTime()
end

function action:Start(ply)
    if CLIENT then return end
    UltiPar.WriteMoveControl(ply, true, true, IN_DUCK, 0)
end

function action:Play(ply, mv, cmd,
        startpos,
        dir,
        duration,
        lifetime,
        dir2,
        starttime
    )

    mv:SetVelocity(Vector())

    local startspeed, endspeed = self:GetSpeed(ply)
    local acc = self:Gravity(ply)
    local dt = FrameTime()

    ply.wr_v_timer = (ply.wr_v_timer or 0) + dt
    local target = ply.wr_v_target or 0
    local speed = ply.wr_v_speed or startspeed

    if ply.wr_v_timer < duration + lifetime then 
        if (acc < 0 and speed < endspeed) or (acc > 0 and speed > endspeed) then
            target = target + endspeed * dt
        else
            target = target + speed * dt
        end

        mv:SetOrigin(
            LerpVector(
                math.Clamp(ply.wr_v_timer / 0.1, 0, 1), 
                ply:GetPos(), 
                startpos + target * dir
            )
        ) 
        
        ply.wr_v_target = target
        ply.wr_v_speed = dt * acc + speed
    else
        return 'normal'
    end


    local curtime = CurTime()
    
    -- 检测跳跃键
    local keydown_injump = ply:KeyDown(IN_JUMP)
    if curtime - starttime > 0.3 and ply.wr_v_keydown_injump == false and keydown_injump then
        return 'jump'
    end
    ply.wr_v_keydown_injump = keydown_injump

    if curtime - (ply.wr_v_lasttime or 0) > 0.1 then
        if math.abs(ply.wr_v_speed) < 150 then
            timer.Remove('wallrunhfoot_' .. ply:EntIndex())
        end

        ply.wr_v_lasttime = curtime
        local bmins, bmaxs = ply:GetHull()

        local hitforward = util.QuickTrace(ply:EyePos(), -dir2 * bmaxs[1] * 2, ply)
        if not hitforward.Hit then
            return 'hit'
        end

        local hitup = util.TraceHull({
            filter = ply, 
            mask = MASK_PLAYERSOLID,
            start = ply:GetPos() + 1 * dir2,
            endpos = ply:GetPos() + dir * 20 + 1 * dir2,
            mins = bmins,
            maxs = bmaxs,
        })

        if hitup.Hit or hitup.StartSolid then
            return 'hit'
        end
    end
end

action.Interrupts['DParkour-LowClimb'] = true
action.Interrupts['DParkour-HighClimb'] = true

action.InterruptsFunc['DParkour-LowClimb'] = function(ply, self, ...)
    self:Clear(ply)
    local effect = UltiPar.GetPlayerCurrentEffect(ply, self)
    if effect then effect:clear(ply) end

    return true
end

action.InterruptsFunc['DParkour-HighClimb'] = function(ply, self, ...)
    self:Clear(ply)
    local effect = UltiPar.GetPlayerCurrentEffect(ply, self)
    if effect then effect:clear(ply) end

    return true
end

function action:Clear(ply, mv, cmd, endtype)
    if CLIENT then return end

    ply.wr_v_timer = nil
    ply.wr_v_target = nil
    ply.wr_v_speed = nil
    ply.wr_v_keydown_injump = nil
    ply.wr_v_lasttime = nil

    if not mv then return end

    if endtype == 'jump' then
        mv:SetVelocity(self:JumpVel(ply)) 
    elseif endtype then
        mv:SetVelocity(UltiPar.unitzvec) 
    end
end

hook.Add('OnPlayerHitGround', 'vwallrun.reset', function(ply, key)
    ply.LastWallForward2 = nil
    ply.VWallDieTime = 0
end)

if SERVER then
    hook.Add('KeyPress', 'vwallrun.trigger', function(ply, key)
        if key == IN_JUMP then UltiPar.Trigger(ply, action) end
    end)
end