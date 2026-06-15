#include <libssh2.h>

LIBSSH2_SESSION *
libssh2_session_init_wrapped() {
  return libssh2_session_init();
}

LIBSSH2_CHANNEL *
libssh2_channel_open_session_wrapped(LIBSSH2_SESSION *session) {
  return libssh2_channel_open_session(session);
}

int
libssh2_channel_exec_wrapped(LIBSSH2_CHANNEL *channel, const char *command) {
  return libssh2_channel_exec(channel, command);
}
