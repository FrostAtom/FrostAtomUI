local AddOnName,namespace = ...

local assert = assert
local select = select
local pairs = pairs
local tremove = tremove


--------------------------------------------------
-- functional
local function tWipe(tbl)
    for i = 1,#tbl do
        tbl[i] = nil
    end
    return tbl
end

local function tPush(tbl,item,...)
    if item then
        tbl[#tbl+1] = item
        return tPush(tbl,...)
    end
    return tbl
end

local tNew,tDel
do
    local cache = setmetatable({},{
        __mode = "k"
    })

    tNew = function(...)
        for t in pairs(cache) do
            cache[t] = nil
            return tPush(t,...)
        end
        return {...}
    end
    tDel = function(t)
        for k in pairs(t) do
            t[k] = nil
        end

        cache[t] = true
    end
end

local function tContains(tbl,item)
    for i = 1,#tbl do
        if tbl[i] == item then
            return i
        end
    end
end

local function tDeleteItem(tbl,item)
    local i = tContains(tbl,item)
    if i then
    	return tremove(tbl,i)
    end
end

local destroyObject
do
    local function inner(obj,...)
        if obj then
            obj:Hide()
            obj:SetScript("OnShow",obj.Hide)
            obj:UnregisterAllEvents()

            return inner(...)
        end
    end

    destroyObject = function(obj,deep)
        inner(obj,deep and obj:GetChildren())
    end
end

local function null() end

local printf
do
    local print = print

    local PREFIX = "|cff177cbf["..AddOnName.."]|r: "
    printf = function(format,...)
        print(PREFIX..format:format(...))
    end
end

namespace.tWipe = tWipe
namespace.tPush = tPush
namespace.tNew = tNew
namespace.tDel = tDel
namespace.tContains = tContains
namespace.tDeleteItem = tDeleteItem
namespace.destroyObject = destroyObject
namespace.null = null
namespace.printf = printf
namespace.AddOnName = AddOnName


--------------------------------------------------
-- modules
local modules = {}
local obj_MT = {__index = {}}
function namespace:New(moduleName)
    assert(moduleName)
    local obj = setmetatable(tNew(),obj_MT)
    modules[moduleName] = obj
    return obj
end

function namespace:Get(moduleName)
    assert(moduleName)
    return modules[moduleName]
end

function namespace:GetObjectPrototype(__index)
    if __index then
        return obj_MT
    else
        return obj_MT.__index
    end
end

function namespace:iterModules()
    return pairs(modules)
end

_G[AddOnName] = namespace
