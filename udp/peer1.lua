local dgram = require("dgram")

local options = {
	reuseaddr = true,
}

local sock

local function message_handler(msg, rinfo, flags)
	p("!!!!!!!!!! you've got mail")
	p(msg)
	p(rinfo)
	p(flags)

	if msg:find("goodbye") then
		sock:send("cya", rinfo.port, rinfo.ip)
	end
end

sock = dgram.createSocket("udp6", message_handler)
sock:bind(8192, "::1", options)
