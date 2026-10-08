local _, ns = ...

local Demand = {}
ns.Demand = Demand

function Demand:Acquire(owner)
	local owners = self.demandOwners
	if not owners then
		owners = {}
		self.demandOwners = owners
	end
	if owners[owner] then
		return
	end
	local first = next(owners) == nil
	owners[owner] = true
	if first and self.OnDemandStart then
		self:OnDemandStart()
	end
end

function Demand:Release(owner)
	local owners = self.demandOwners
	if not owners or not owners[owner] then
		return
	end
	owners[owner] = nil
	if next(owners) == nil and self.OnDemandStop then
		self:OnDemandStop()
	end
end

function Demand:SetDemand(owner, wanted)
	if wanted then
		self:Acquire(owner)
	else
		self:Release(owner)
	end
end

function Demand:IsActive()
	return self.demandOwners ~= nil and next(self.demandOwners) ~= nil
end
