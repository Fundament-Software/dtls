local fs = require("fs")
local tls = require("tls")

local cert = fs.readFileSync("cert2/cert.pem")
local privkey = fs.readFileSync("cert2/privkey.pem")
local peercert = fs.readFileSync("cert1/cert.pem")

local options = {
	cert = cert,
	key = privkey,
	ca = { peercert },
	-- ::1 doesn't work because tls.connect strips
	-- colons and everything after them
	host = "localhost",
	port = 8192,
	rejectUnauthorized = true,
}

local function connection_handler(peer)
	print("!!!!!!!!!!!!!! connected secure")
	p(peer)
	p(peer:address())
	p(peer:getsockname())
	p(peer:version())
	p(peer:getPeerCertificate())

	peer:on("data", function(chunk)
		print("!!!!!!!!!! fresh data")
		p(chunk)
		peer:destroy()
	end)

	peer:write("hello!")
	peer:write("how are you?")
	peer:write("goodbye.")
end

tls.connect(options, connection_handler)
