local actionName = 'VWallRun'

local function effectstart_default(self, ply, isright)
	-- WOS动画
	if self.WOSAnim and self.WOSAnim ~= '' then
		if SERVER then
			ply:SetNWString('UP_WOS', self.WOSAnim)
		elseif CLIENT then
			local seq = ply:LookupSequence(self.WOSAnim)
			if seq and seq > 0 then
				ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_JUMP, seq, 0, true)
				ply:SetPlaybackRate(1)
			end
		end
	end

	-- ViewPunch
	if SERVER and self.punch then
		ply:ViewPunch(self.punch_ang)
	end

	-- upunch
	if CLIENT and self.upunch then
        UltiPar.SetVecPunchVel(self.upunch_vec)
	end

	-- VManip手部动画、音效
	if CLIENT and self.VManipAnim and self.VManipAnim ~= '' then
		VManip:PlayAnim(self.VManipAnim)
        if VManip:GetCurrentAnim() == 'verticalwallrun' and IsValid(VManip:GetVMGesture()) then
            -- 这个动作是给全身设计的，所以原点在脚上，必须特殊处理
            VManip:GetVMGesture().RenderOverride = function(self)
                self:SetPos(EyePos() - ply:EyeAngles():Up() * 64)
                self:SetAngles(ply:EyeAngles())
            end    
        end
	end

	-- VManip腿部动画
	if CLIENT and self.VMLegsAnim and self.VMLegsAnim ~= '' then
		VMLegs:PlayAnim(self.VMLegsAnim)
	end

	-- 音效
	if SERVER and self.sound and self.sound ~= '' then
        ply:EmitSound(self.sound)
        timer.Create('wallrunhfoot_' .. ply:EntIndex(), 0.205, 30, function() ply:EmitSound(self.sound) end)
	end
end


local function effectclear_default(self, ply, endtype)
    -- 通用清理WOS和VManip
	if SERVER then
		ply:SetNWString('UP_WOS', '')
	elseif CLIENT then
		local currentAnim = VManip:GetCurrentAnim()
		if currentAnim and currentAnim == self.VManipAnim then
			VManip:QuitHolding(currentAnim)
		end
	end

    -- 强制结束时
    if CLIENT and not endtype and VManip:GetCurrentAnim() == self.VManipAnim and IsValid(VManip:GetVMGesture()) then
        VManip:Remove()
    end

	-- ViewPunch
	if SERVER and self.punch and endtype == 'jump' then
		ply:ViewPunch(self.punch_ang_jump)
	end

    -- upunch
    if CLIENT and self.upunch and endtype == 'jump' then 
        UltiPar.SetVecPunchVel(self.upunch_vec_jump)
    end

    -- 音效清理
    if SERVER then
        timer.Remove('wallrunhfoot_' .. ply:EntIndex())
    end

    -- 跳跃结束时播放音效
    if SERVER and endtype == 'jump' then 
        ply:EmitSound(self.sound_clean)
    end
end

UltiPar.RegisterEffect(
    actionName, 
    'default',
    {
        VManipAnim = 'verticalwallrun',
        VMLegsAnim = '',
        WOSAnim = '',

        sound = 'wallrun.footstep.cuda',
        sound_clean = 'wallrun.cleanfootstep.cuda',
        
        upunch = true,
        upunch_vec = Vector(0, 0, 25),
        upunch_vec_jump = Vector(50, 0, 25),

		start = effectstart_default,
        clear = effectclear_default,
    }
)