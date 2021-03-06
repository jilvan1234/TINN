-- MMDevice.lua
local ffi = require("ffi")

local MMDevice_ffi = require("MMDevice_ffi")
local ObjBase = require("ObjBase")
local core_string = require("core_string_l1_1_0");

local MMDevice = {}
local MMDevice_mt = {
	__index = MMDevice,
}

function MMDevice.init(self, immdevice)
	-- open property store
	local pProps = ffi.new("IPropertyStore * [1]");
	local hr = immdevice:OpenPropertyStore(ffi.C.STGM_READ, pProps);

	local cProps = ffi.new("DWORD[1]")
	hr = pProps[0].lpVtbl.GetCount(pProps[0],cProps);

	local obj = {
		Device = immdevice,
		PropertyStore = pProps[0],
		PropertyCount = cProps[0],
	}
	setmetatable(obj, MMDevice_mt)

	return obj;
end

function MMDevice.create(self, ...)
	return self:init(...);
end

--[[
	Device Class Methods
--]]
-- Retrieve the audio endpoints
-- use the kind to specify the flow (source, sink, filter)
function MMDevice.AudioEndpoints(self, dataFlow)
	dataFlow = dataFlow or ffi.C.eAll;

	-- Create an instance of the enumeration interface
	local pEnumerator = ffi.new("IMMDeviceEnumerator *[1]")

	local hr = ObjBase.CoCreateInstance(MMDevice_ffi.CLSID_MMDeviceEnumerator, 
		nil,
    	CLSCTX_INPROC_SERVER, 
    	MMDevice_ffi.IID_IMMDeviceEnumerator,
    	ffi.cast("void**",pEnumerator));

	-- get the collection of all devices
	local ppDevices = ffi.new("IMMDeviceCollection *[1]")
	hr = pEnumerator[0].EnumAudioEndpoints(pEnumerator[0], dataFlow, ffi.C.DEVICE_STATE_ACTIVE, ppDevices)

	-- Find out how many devices there are
	local pcDevices = ffi.new("UINT[1]")
	local deviceCollection = ppDevices[0]
	hr = deviceCollection:GetCount(pcDevices)
	local deviceCount = pcDevices[0]

	local idx = -1;

	local function closure()
		idx = idx + 1;
		if idx >= deviceCount then
			return nil;
		end

		-- Construct a MMDevice instance using
		-- the ID of the device
		local ppDevice = ffi.new("IMMDevice * [1]")
		local hr = deviceCollection:Item(idx, ppDevice)


		return MMDevice:init(ppDevice[0]);
	end

	return closure
end

--[[
	Device Instance Methods
--]]

function MMDevice.getID(self)

	if not self.ID then
		local ppstrId = ffi.new("PWSTR [1]")
		hr = self.Device:GetId(ppstrId)
		self.ID = core_string.toAnsi(ppstrId[0])
	end

	return self.ID
end

function MMDevice.getProperty(self, propKey)
	local propVar = ffi.new("PROPVARIANT");
	local hr = self.PropertyStore:GetValue(propKey, propVar);

	return propVar;
end

-- Enumerate all the properties of the device
function MMDevice.properties(self)
	local idx = -1;

	local function closure()
		idx = idx + 1;
		if idx >= self.PropertyCount then
			return nil;
		end

		local pkey = ffi.new("PROPERTYKEY")
		local hr = self.PropertyStore:GetAt(idx, pkey)

		return self:getProperty(pkey)
	end

	return closure
end




return MMDevice