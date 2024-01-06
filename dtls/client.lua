local fs = require("fs")
local dtls = require("./common")

local cert = fs.readFileSync("cert2/cert.pem")
local privkey = fs.readFileSync("cert2/privkey.pem")
local peercert = fs.readFileSync("cert1/cert.pem")

local options = {
	role = "client",
	family = "inet6",
	connect_port = 8192,
	connect_host = "::1",
	bind_host = "::1",
	key = privkey,
	cert = cert,
	ca = { peercert },
}

function options.connection_handler(sock, conn)
	print("!!!!!!!!!! connected secure")
	p(sock)
	--p(sock:address())
	--p(sock:getsockname())
	p(sock:version(conn))
	p(sock:getPeerCertificate(conn))
	p(conn)

	sock:on("message", function(msg)
		print("!!!!!!!!!! you've got mail")
		p(msg)
		--sock:destroy()
	end)

	sock:send(conn, "hello!")
	sock:send(conn, "how are you?")
	sock:send(conn, "goodbye.")
end

dtls.DTLSSocket:new(options)
