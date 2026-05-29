if SERVER then
    AddCSLuaFile("watchlist/cl_watchlist.lua")
    AddCSLuaFile("watchlist/sh_watchlist.lua")
    include("watchlist/sh_watchlist.lua")
    include("watchlist/sv_watchlist.lua")
end

if CLIENT then
    include( "watchlist/sh_watchlist.lua" )
    include( "watchlist/cl_watchlist.lua" )
end
