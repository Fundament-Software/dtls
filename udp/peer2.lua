local dgram = require("dgram")

local sock

local function message_handler(msg, rinfo, flags)
	p("!!!!!!!!!! you've got mail")
	p(msg)
	p(rinfo)
	p(flags)

	sock:close()
end

sock = dgram.createSocket("udp6", message_handler)
-- sock:recvStart() doesn't work because libuv binds
-- the socket to 0.0.0.0 unless it's already bound
sock:bind(0, "::")

sock:send("hello!", 8192, "::1")
sock:send("how are you?", 8192, "::1")
sock:send("goodbye.", 8192, "::1")
