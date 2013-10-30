----------------------------------------------------------------------------------------------------
-- Lua utilities -----------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- Returns the size of a table
function GetTableSize(t)
	local count = 0
	for _ in pairs(t) do count = count + 1 end
	return count
end

-- Returns the pair with the highest value in a table, requires <String, Double> table.
function GetHighestValuePairAndRemoveIt(t)
	local finkey = "none";
	local finvalue = 0;
	for key, value in pairs(t) do 
		if value > finvalue then
			finvalue = value;
			finkey = key;
		end
	end
	t[finkey] = nil;
	return finkey, finvalue;
end

-- Keeps the 3 highest value-pairs in a <String, Double> table. Returns how many entries are in the new tables as well as 2 new array-tables ordered.
function KeepXHighestValuePairs(t, x)
	local newkeys = {};
	local newvalues = {};
	local nrOf = x;
	if GetTableSize(t) < x then
		nrOf = GetTableSize(t);
	end
	for i = 1, nrOf do
		local key, value = GetHighestValuePairAndRemoveIt(t);
		table.insert(newkeys, key)
		table.insert(newvalues, value)
	end
	return nrOf, newkeys, newvalues;
end

