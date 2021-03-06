-- Application.lua
if Application_Included then
	return appInstance
end

Application_Included = true;


local Scheduler = require("Scheduler")
local Stopwatch = require("StopWatch")
local Task = require("Task")
local Functor = require("Functor")

-- scheduler plug-ins
local fwaitForCondition = require("waitForCondition")
local fwaitForSignal = require("waitForSignal")
local fwaitForTime = require("waitForTime")
local fwaitForIO = require("waitForIO")

--waitForIO.MessageQuanta = 0;

-- The main application object
local Application = {}
setmetatable(Application, {
	__call = function(self, ...)
		return self:create(...);
	end,
})
local Application_mt = {
	__index = Application,
}

function Application.init(self, ...)
	local sched = Scheduler();

	fwaitForIO.MessageQuanta = 0;

	local obj = {
		Clock = Stopwatch();
		Scheduler = sched;
		TaskID = 0;
		wfc = fwaitForCondition(sched);
		wfs = fwaitForSignal(sched);
		wft = fwaitForTime(sched);
		wfio = fwaitForIO(sched);
	}
	setmetatable(obj, Application_mt)

	-- Create a task for each add-on
	obj:coop(obj.wfc.start, obj.wfc)
	obj:coop(obj.wft.start, obj.wft)
	obj:coop(obj.wfio.start, obj.wfio)

	return obj;
end

function Application.create(self, makeGlobal)
	local app = self:init()

	if makeGlobal then
		app:exportGlobals();
	end

	return app;
end


-- Add in scheduler plug-ins
--  Predicates
--  Timer
--  IOEvents
--  Events

-- Time related functions
function Application.sleep(self, millis)
	self.wft:yield(millis)
end

function Application.delay(self, func, millis)
	millis = millis or 1000

	local function closure()
		self:sleep(millis)
		func();
	end

	return self:coop(closure)
end

function Application.periodic(self, func, millis)
	millis = millis or 1000

	local function closure()
		while true do
			self:sleep(millis)
			func();
		end
	end

	return self:coop(closure)
end

-- IO Functions
function Application.getNextOperationId(self)
	return self.wfio:getNextOperationId();
end

function Application.setMessageQuanta(self, millis)
	return self.wfio:setMessageQuanta(millis);
end

function Application.waitForIO(self, socket, pOverlapped)
	return self.wfio:yield(socket, pOverlapped);
end

function Application.watchForIO(self, handle, param)
	return self.wfio:watchForIOEvents(handle, param)
end


-- Conditional functions
function Application.waitFor(self, pred)
	--print("Application.waitFor: ", pred)
	self.wfc:yield(pred)
end

-- taskIsFinished
-- A function that can be used as a predicate
function Application.taskIsFinished(task)
	local function closure()
		return task:getStatus() == "dead"
	end

	return closure
end

function Application.when(self, pred, func)

	local function watchit()
		--print("watchit - BEGIN")
		self:waitFor(pred)
		func()
	end

	self:coop(watchit)
end

function Application.whenever(self, pred, func)

	local function watchit()
		while true do
			self:waitFor(pred)
			func()
		end
	end

	self:coop(watchit)
end

-- Event Related Functions
function Application.signalOne(self, eventName)
	return self.wfs:signalOne(eventName)
end

function Application.signalAll(self, eventName)
	return self.wfs:signalAll(eventName)
end

function Application.waitForSignal(self, eventName)
	return self.wfs:yield(eventName)
end

function Application.onSignal(self, func, eventName)
	local function closure()
		self:waitForSignal(eventName)
		func();
	end

	return self:coop(closure)
end



-- Put core scheduler routines in global namespace
function Application.onStepped(self)
	--print("Application.onStepped, IN MAIN: ", self.Scheduler:inMainFiber())

	if not self.wfc:tasksArePending() then
		--print("No Conditionals Pending")
		if (self.wft:tasksPending() < 1) then
			--print("No Timers Pending")
			if not self.wfio:tasksArePending() then
				if not (self.Scheduler:tasksPending() > 3) then
					--print("No Tasks Pending: ", self.Scheduler:tasksPending())
					return self.Scheduler:stop();
				end
			end
		end
	end
end

function Application.getNewTaskID(self)
	self.TaskID = self.TaskID + 1;
	return self.TaskID;
end

function Application.coop(self, func, ...)
	local task = Task(func, ...)
	task.TaskID = self:getNewTaskID();
	self.Scheduler:scheduleTask(task, {...});

--print("Application.coop: ", ...)

	return task;
end


function Application.stop(self)
	self.Scheduler:stop();
end


function Application.yield(self, ...)
	return self.Scheduler.yield(...)
end


function Application.start(self)
	self.Scheduler:start()
end

function Application.run(self, func, ...)
	self.Scheduler.OnStepped = Functor(self.onStepped, self)

	if func ~= nil then
		self:coop(func, ...)
	end

	return self:start();
end

function Application.exportGlobals(self)
	_G.coop = Functor(self.coop, self);
	_G.delay = Functor(self.delay, self);
	_G.onSignal = Functor(self.onSignal, self);
	_G.periodic = Functor(self.periodic, self);
	_G.run = Functor(self.run, self);
	_G.signalAll = Functor(self.signalAll, self);
	_G.signalOne = Functor(self.signalOne, self);
	_G.sleep = Functor(self.sleep, self);
	_G.spawn = Functor(self.coop, self);
	_G.stop = Functor(self.stop, self);
	_G.taskIsFinished = Application.taskIsFinished;
	_G.waitSignal = Functor(self.waitForSignal, self);
	_G.waitFor = Functor(self.waitFor, self);
	_G.waitForIO = Functor(self.waitForIO, self);
	_G.watchForIO = Functor(self.watchForIO, self);
	_G.when = Functor(self.when, self);
	_G.whenever = Functor(self.whenever, self);
	_G.yield = Functor(self.yield, self);

	return self;
end

local appInstance = Application(true)

return appInstance;
