local core = require("core")
local dgram = require("dgram")
local openssl = require("openssl")

-- CREDENTIAL --

local Credential = core.Object:extend()

function Credential:initialize(isServer)
	if isServer then
		self.context = openssl.ssl.ctx_new("QUIC")
	else
		self.context = openssl.ssl.ctx_new("QUIC")
	end
end

-- this method creates a store once for each Credential
-- subsequent calls add more CA certs
-- TODO: remove? set? clear?
function Credential:addCA(certs)
	if not self.store then
		self.store = openssl.x509.store:new()
		self.context:cert_store(self.store)
	end
	for _, v in ipairs(certs) do
		local cert = openssl.x509.read(v)
		self.store:add(cert)
	end
end

function Credential:setKeyCert(key, cert)
	local key = openssl.pkey.read(key, true)
	local cert = openssl.x509.read(cert)
	self.context:use(key, cert)
end

-- DTLSSOCKET --

-- TODO: refactor into dtlssocket and dtlsconnection

local DTLSSocket = core.Emitter:extend()

local message_handler

local function setup_connection(self, family, ip, port)
	local conn = {
		family = family,
		ip = ip,
		port = port,
		connected = false,
	}
	local source = string.format("%s:[%s]:%d", family, ip, port)
	self.connections[source] = conn

	local key, cert, ca = self.options.key, self.options.cert, self.options.ca

	conn.ctx = Credential:new(self.server)
	if key and cert then
		conn.ctx:setKeyCert(key, cert)
	end
	if ca then
		conn.ctx:addCA(ca)
	end
	conn.inp = openssl.bio.mem(8192)
	conn.out = openssl.bio.mem(8192)
	conn.ssl = conn.ctx.context:ssl(conn.inp, conn.out, self.server)
	-- TODO: sni, session resumption

	return conn
end

local function do_handshake(self, conn)
	local ret, err = conn.ssl:handshake()
	if ret then
		conn.connected = true
		self.options.connection_handler(self, conn)
	else
		-- TODO: ???
		p("handshake", err)
	end
	self:flush(conn)
end

function DTLSSocket:initialize(options)
	self.options = options

	local role, family, connect_port, connect_host, bind_port, bind_host =
		self.options.role,
		self.options.family,
		self.options.connect_port,
		self.options.connect_host,
		self.options.bind_port,
		self.options.bind_host

	self.connections = {}

	local protocol, bind_addr_default
	if family == "inet" then
		protocol = "udp4"
		bind_addr_default = "0.0.0.0"
	elseif family == "inet6" then
		protocol = "udp6"
		bind_addr_default = "::"
	else
		error("family must be inet or inet6")
	end

	self.socket = dgram.createSocket(protocol, message_handler(self))

	-- bind understands these options:
	-- reuseaddr (boolean)
	-- ipv6only (boolean)
	if bind_host and bind_port then
		self.socket:bind(bind_port, bind_host, self.options)
	elseif bind_host then
		self.socket:bind(0, bind_host, self.options)
	else
		self.socket:bind(0, bind_addr_default, self.options)
	end

	if role == "server" then
		self.server = true
	elseif role == "client" then
		self.server = false
		-- TODO: resolve host into ip
		local connect_ip = connect_host
		local conn = setup_connection(self, family, connect_ip, connect_port)
		do_handshake(self, conn)
	else
		error("role should be client or server")
	end
end

function message_handler(self)
	return function(msg, rinfo, flags)
		-- TODO: flags???
		local source = string.format("%s:[%s]:%d", rinfo.family, rinfo.ip, rinfo.port)
		local conn = self.connections[source]
		if conn then
			conn.inp:write(msg)
			if conn.connected then
				local plainmsg = conn.ssl:read()
				self:emit("message", plainmsg)
			else
				do_handshake(self, conn)
			end
		else
			if self.server then
				local conn = setup_connection(self, rinfo.family, rinfo.ip, rinfo.port)
				conn.inp:write(msg)
				do_handshake(self, conn)
			else
				-- ignore
			end
		end
	end
end

function DTLSSocket:send(conn, msg)
	local ret, err = conn.ssl:write(msg)
	if not ret then
		-- TODO: ???
		p("ssl send", err)
	end
	self:flush(conn)
end

-- useful for sending handshakes etc without necessarily sending an application message
function DTLSSocket:flush(conn)
	while conn.out:pending() > 0 do
		local chunk = conn.out:read()
		self.socket:send(chunk, conn.port, conn.ip)
	end
end

-- TODO: socket/connection info (local/peer), close and cleanup

function DTLSSocket:version(conn)
	return conn.ssl:get("version")
end

function DTLSSocket:getPeerCertificate(conn)
	return conn.ssl:peer()
end

return {
	DTLSSocket = DTLSSocket,
}
