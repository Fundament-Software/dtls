local fs = require("fs")
local dtls = require("./common")

local cert = fs.readFileSync("cert1/cert.pem")
local privkey = fs.readFileSync("cert1/privkey.pem")
local peercert = fs.readFileSync("cert2/cert.pem")

local options = {
	role = "server",
	family = "inet6",
	bind_port = 8192,
	bind_host = "::1",
	reuseaddr = true,
	key = privkey,
	cert = cert,
	ca = { peercert },
}

function options.connection_handler(sock, conn)
	print("!!!!!!!!!! new peer")
	p(sock)
	--p(sock:address())
	--p(sock:getsockname())
	p(sock:version(conn))
	p(sock:getPeerCertificate(conn))
	p(conn)

	sock:on("message", function(msg)
		print("!!!!!!!!!! you've got mail")
		p(msg)
		if msg:find("goodbye") then
			sock:send(conn, "cya")
			--sock:destroy()
		end
	end)
end

dtls.DTLSSocket:new(options)
