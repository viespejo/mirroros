#!/usr/bin/bash
# A synthetic Notify service checks the actual wire values on a fresh session bus.
set -Eeuo pipefail

if [[ ${1:-} != --private ]]; then
  exec dbus-run-session -- "$0" --private
fi
for tool in busctl cc pkg-config; do
  command -v "$tool" >/dev/null || { printf 'BLOCKED missing tool: %s\n' "$tool"; exit 2; }
done
pkg-config --exists gio-2.0 || { printf 'BLOCKED missing gio-2.0 development files\n'; exit 2; }

tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
sender="$tests_dir/../../../../capabilities/desktop/shell/notifications/mirroros-notification-send"
[[ $(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications) == 'b false' ]] || {
  printf 'BLOCKED Notifications already owned\n'; exit 2;
}
tmp=$(mktemp -d)
pid=
cleanup() {
  if [[ -n $pid ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
  rm -rf -- "$tmp"
}
trap cleanup EXIT

# Compile only the test double; the product sender needs no GLib development files.
cc -x c -o "$tmp/receiver" - $(pkg-config --cflags --libs gio-2.0) <<'C'
#include <gio/gio.h>
#include <stdio.h>

static void notify(GDBusConnection *bus, const gchar *sender, const gchar *path,
                   const gchar *iface, const gchar *method, GVariant *args,
                   GDBusMethodInvocation *call, gpointer data) {
  static guint id = 40;
  gchar *text = g_variant_print(args, TRUE);
  puts(text);
  fflush(stdout);
  g_free(text);
  g_dbus_method_invocation_return_value(call, g_variant_new("(u)", ++id));
}

int main(void) {
  const gchar *xml = "<node><interface name='org.freedesktop.Notifications'><method name='Notify'>"
    "<arg type='s'/><arg type='u'/><arg type='s'/><arg type='s'/><arg type='s'/>"
    "<arg type='as'/><arg type='a{sv}'/><arg type='i'/><arg type='u' direction='out'/>"
    "</method></interface></node>";
  const GDBusInterfaceVTable handlers = { .method_call = notify };
  GDBusConnection *bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, NULL);
  if (!bus) return 1;
  GDBusNodeInfo *info = g_dbus_node_info_new_for_xml(xml, NULL);
  if (!info || !g_dbus_connection_register_object(bus, "/org/freedesktop/Notifications",
      info->interfaces[0], &handlers, NULL, NULL, NULL)) return 1;
  g_bus_own_name_on_connection(bus, "org.freedesktop.Notifications", G_BUS_NAME_OWNER_FLAGS_NONE,
                              NULL, NULL, NULL, NULL);
  g_main_loop_run(g_main_loop_new(NULL, FALSE));
  return 0;
}
C
"$tmp/receiver" > "$tmp/calls" &
pid=$!
for ((i=0; i<100; i++)); do
  if [[ $(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications) == 'b true' ]]; then break; fi
  kill -0 "$pid"
  sleep 0.05
done
[[ $(busctl --user status org.freedesktop.Notifications | grep -x "PID=$pid") == "PID=$pid" ]]

[[ $("$sender" -p -r 17 -i battery-caution -g '󱐋' -u normal -t 30000 --transient --image=/synthetic/icon.png -- '--exec' '--action=as-text') == 41 ]]
[[ $("$sender" --print-id --app-name='Named sender' -- '-headline' '-50% off') == 42 ]]
for option in --exec --action --with --exec=ignored --action=ignored --with=ignored; do
  for position in first body last; do
    case $position in
      first) args=("$option") ;;
      body) args=('Headline' "$option") ;;
      last) args=('Headline' 'Body' "$option") ;;
    esac
    if "$sender" "${args[@]}" > "$tmp/reject" 2>&1; then
      printf 'FAIL accepted %s in %s position\n' "$option" "$position"; exit 1
    fi
    grep -qxF 'Executable actions are not supported.' "$tmp/reject"
  done
done

diff -u - "$tmp/calls" <<'EXPECTED'
('mirroros-action', uint32 17, 'battery-caution', '--exec', '--action=as-text', @as [], {'urgency': <byte 0x01>, 'mirroros-glyph': <'󱐋'>, 'image-path': <'/synthetic/icon.png'>, 'transient': <true>}, 30000)
('Named sender', uint32 0, '', '-headline', '-50% off', @as [], {'urgency': <byte 0x00>}, -1)
EXPECTED
printf 'PASS typed Notify on the caller bus, both delivery identities, literal text and rejected executable options\n'
