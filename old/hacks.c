#include <stddef.h>
#include <lua.h>
#include <lauxlib.h>
#include <uv.h>

static int hacks_get_udp_fd(lua_State *L) {
	void *udata;
	uv_udp_t *handle;
	double fd;

	udata = lua_touserdata(L, -1);
	if (udata == NULL) {
		return luaL_error(L, "invalid userdata");
	}
	handle = udata;

#ifdef _WIN32
	fd = handle->socket;
#else
	fd = handle->io_watcher.fd;
#endif

	lua_pushnumber(fd);
	return 1;
}

static const luaL_Reg hacks_lib[] = {
#define F(name) {#name, hacks_##name},
	F(get_udp_fd)
#undef F
	{NULL, NULL}
};

int openlib(lua_State *L) {
	luaL_setfuncs(L, hacks_lib, 0);
	return 1;
}
