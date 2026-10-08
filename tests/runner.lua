local R = { tests = {}, passed = 0, failed = 0, xfailed = 0 }

local function describe(v)
	return type(v) == "string" and ("%q"):format(v) or tostring(v)
end

function R.deepDiff(a, b, path)
	path = path or "$"
	if type(a) ~= type(b) then
		return path .. ": type " .. type(a) .. " ~= " .. type(b)
	end
	if type(a) ~= "table" then
		if a ~= b and not (a ~= a and b ~= b) then
			return path .. ": " .. describe(a) .. " ~= " .. describe(b)
		end
		return nil
	end
	for k, v in pairs(a) do
		local d = R.deepDiff(v, b[k], path .. "." .. tostring(k))
		if d then
			return d
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return path .. "." .. tostring(k) .. ": missing on the left"
		end
	end
end

R.expect = {
	eq = function(a, b, msg)
		if a ~= b then
			error((msg or "eq") .. ": " .. describe(a) .. " ~= " .. describe(b), 2)
		end
	end,
	deepEq = function(a, b, msg)
		local d = R.deepDiff(a, b)
		if d then
			error((msg or "deepEq") .. ": " .. d, 2)
		end
	end,
	truthy = function(v, msg)
		if not v then
			error((msg or "truthy") .. ": got " .. describe(v), 2)
		end
	end,
}

function R.test(name, fn)
	R.tests[#R.tests + 1] = { name = name, fn = fn }
end

function R.xfail(name, fn)
	R.tests[#R.tests + 1] = { name = name, fn = fn, xfail = true }
end

function R.run(before)
	for _, t in ipairs(R.tests) do
		if before then
			before()
		end
		local ok, err = pcall(t.fn)
		if t.xfail then
			if ok then
				R.failed = R.failed + 1
				print("XPASS " .. t.name)
			else
				R.xfailed = R.xfailed + 1
				print("xfail " .. t.name .. "\n      " .. tostring(err))
			end
		elseif ok then
			R.passed = R.passed + 1
			print("ok    " .. t.name)
		else
			R.failed = R.failed + 1
			print("FAIL  " .. t.name .. "\n      " .. tostring(err))
		end
	end
	print(("\n%d passed, %d failed, %d expected failures"):format(R.passed, R.failed, R.xfailed))
	return R.failed == 0
end

return R
