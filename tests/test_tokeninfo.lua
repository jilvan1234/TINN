-- test_tokeninfo.lua
--

local ffi = require("ffi");
local errorhandling = require("core_errorhandling_l1_1_1");
local core_string = require("core_string_l1_1_0");

local Token = require("Token");
local SID = require("SID");


local printTable = function(tbl)
	for k,v in pairs(tbl) do
		print(k,v)
	end
end


local printToken = function(token)
	print("TOKEN TYPE")
	print("=================")
	print(token:getTokenType());
	print();

print("PRIVILEGES");
print("==========")
privs = token:getPrivileges();
printTable(privs);

print();

print("SOURCE");
print("=================")
print(token:getSource());
print();

print("USER");
print("=================");
local user = token:getUser();
print(user);
--print(user:getAccountName());
print();

print("GROUPS");
print("=================");
--local groups = token:getGroups();
--for k,v in pairs(groups) do
--	print(v.Sid);
--end
end

local token, err = Token:getProcessToken();

if not token then
	return false, err;
end

printToken(token);

-- enable shutdown privilege 
print("EnablePrivilege: ", token:enablePrivilege(Token.Privileges.SE_SHUTDOWN_NAME));

print("After Enable Shutdown")
printToken(token);