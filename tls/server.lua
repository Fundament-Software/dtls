local fs = require("fs")
local tls = require("tls")

local cert = fs.readFileSync("cert1/cert.pem")
local privkey = fs.readFileSync("cert1/privkey.pem")
local peercert = fs.readFileSync("cert2/cert.pem")

local options = {
	cert = cert,
	key = privkey,
	ca = { peercert },
	requestCert = true,
	rejectUnauthorized = true,
}

local function connection_handler(peer, err)
	print("!!!!!!!!!! new peer")
	p(peer)
	p(err)
	p(peer:address())
	p(peer:getsockname())
	p(peer:version())
	p(peer:getPeerCertificate())

	peer:on("data", function(chunk)
		print("!!!!!!!!!! fresh data")
		p(chunk)
		if chunk:find("goodbye") then
			peer:write("cya")
			peer:destroy()
		end
	end)
end

local server = tls.createServer(options, connection_handler)
server:listen(8192, "::1")
