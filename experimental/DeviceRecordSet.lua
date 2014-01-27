local ffi = require("ffi")
local bit = require("bit")
local bor = bit.bor;
local band = bit.band;

local errorhandling = require("core_errorhandling_l1_1_1");
local SetupApi = require("SetupApi")



local DeviceRecordSet = {}
setmetatable(DeviceRecordSet, {
	__call = function(self, ...)
		return self:create(...)
	end,
})

local DeviceRecordSet_mt = {
	__index = DeviceRecordSet,
}


function DeviceRecordSet.init(self, rawhandle)
	print("init: ", rawhandle)

	local obj = {
		Handle = rawhandle,
	}
	setmetatable(obj, DeviceRecordSet_mt)

	return obj;
end

function DeviceRecordSet.create(self, Flags)
	Flags = Flags or bor(ffi.C.DIGCF_PRESENT, ffi.C.DIGCF_ALLCLASSES)

	local rawhandle = SetupApi.SetupDiGetClassDevs(
		nil, 
        nil, 
        nil, 
        Flags);

	if rawhandle == nil then
		return nil, errorhandling.GetLastError();
	end

	return self:init(rawhandle)
end

function DeviceRecordSet.getNativeHandle(self)
	return self.Handle;
end

function DeviceRecordSet.getRegistryValue(self, key, idx)
	idx = idx or 0;

	did = ffi.new("SP_DEVINFO_DATA")
	did.cbSize = ffi.sizeof("SP_DEVINFO_DATA");

--print("HANDLE: ", self.Handle)
	local res = SetupApi.SetupDiEnumDeviceInfo(self.Handle,idx,did)

	if res == 0 then
		local err = errorhandling.GetLastError()
		print("after SetupDiEnumDeviceInfo, ERROR: ", err)
		return nil, err;
	end

	local regDataType = ffi.new("DWORD[1]")
	local pbuffersize = ffi.new("DWORD[1]",260);
	local buffer = ffi.new("char[260]")

	local res = SetupApi.SetupDiGetDeviceRegistryProperty(
            self:getNativeHandle(),
            did,
			key,
			regDataType,
            buffer,
            pbuffersize[0],
            pbuffersize);

	if res == 0 then
		local err = errorhandling.GetLastError();
		--print("after GetDeviceRegistryProperty, ERROR: ", err)
		return nil, err;
	end

	--print("TYPE: ", regDataType[0])

	return ffi.string(buffer, pbuffersize[0]-1)
end


function DeviceRecordSet.devices(self, fields)
	fields = fields or {
		ffi.C.SPDRP_DEVICEDESC,
	}

	local idx = 0;
	local function closure(fields, idx)
		local res = {}

		local count = 0;
		for _, key in ipairs(fields) do
			local value, err = self:getRegistryValue(key, idx)
			--print(value)
			if value then
				count = count + 1;
				res[tostring(key)] = value;
			end
		end

		idx = idx + 1
		if count == 0 then
			return nil;
		end

		return res;
	end

	return closure, fields, 0
end

return DeviceRecordSet