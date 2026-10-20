import os
import sys
import time
import traceback

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(BASE, "pylibs"))
import frida  # noqa: E402

HAL_JS = r"""
function hex(bytes, n) {
    var out = [];
    for (var i = 0; i < n; i++) {
        var h = bytes[i].toString(16);
        out.push(h.length < 2 ? "0" + h : h);
    }
    return out.join(" ");
}
var mod = Process.getModuleByName("nfc_nci.nqx.default.hw.v1.so");
var writeFn = mod.getExportByName("_Z17phNxpNciHal_writetPKh");
Interceptor.attach(writeFn, {
    onEnter: function (args) {
        var len = args[0].toInt32() & 0xffff;
        var p = args[1];
        var b = new Uint8Array(p.readByteArray(len));
        if (len >= 5 && b[0] === 0x21 && b[1] === 0x03) {
            var num = b[3];
            var patched = false;
            for (var i = 0; i < num; i++) {
                var o = 4 + i * 2;
                if (o + 1 < len && b[o] === 0x00 && b[o + 1] === 0x01) {
                    b[o] = 0x71;
                    patched = true;
                }
            }
            if (patched) {
                p.writeByteArray(Array.prototype.slice.call(b));
                send("HAL TX-PATCH " + hex(b, Math.min(len, 32)));
            }
        }
    }
});
send("HAL hooks ready");
"""

NFA_JS = r"""
function hex(bytes, n) {
    var out = [];
    for (var i = 0; i < n; i++) {
        var h = bytes[i].toString(16);
        out.push(h.length < 2 ? "0" + h : h);
    }
    return out.join(" ");
}
var mod = Process.getModuleByName("libsn100nfc-nci.so");

function patch(p, len, tag) {
    if (len < 8) return;
    var b = new Uint8Array(p.readByteArray(Math.min(len, 16)));
    var idx = -1;
    for (var i = 0; i < Math.min(b.length, 8); i++) {
        if (b[i] === 0x71) { idx = i; break; }
    }
    if (idx >= 0) {
        b[idx] = 0x00;
        p.writeByteArray(Array.prototype.slice.call(b));
        send("NFA-PATCH " + tag + " " + hex(b, b.length));
    }
}

function hook(name, tag) {
    var fn = null;
    try { fn = mod.getExportByName(name); } catch (e) { }
    if (!fn) { try { fn = mod.findExportByName(name); } catch (e) { } }
    if (!fn) { send("missing " + name); return; }
    Interceptor.attach(fn, {
        onEnter: function (args) {
            try { patch(args[0], args[1].toInt32(), tag); } catch (e) { }
        }
    });
}
hook("_Z26nfc_ncif_proc_discover_ntfPht", "discover");
hook("_Z22nfc_ncif_proc_activatePhh", "activate");
send("NFA hooks ready");
"""

TARGETS = ["vendor.nxp.hardware.nfc@2.0-service", "com.android.nfc"]


def on_message(msg, data):
    if msg.get("type") == "send":
        print("[hook]", msg["payload"], flush=True)


def attach(dev, target, js):
    session = dev.attach(target)
    script = session.create_script(js)
    script.on("message", on_message)
    script.load()
    return session


def main():
    dev = frida.get_device_manager().add_remote_device("127.0.0.1:27042")
    sessions = {}
    print("watching:", ", ".join(TARGETS), flush=True)
    while True:
        try:
            procs = {p.name: p.pid for p in dev.enumerate_processes()}
            for target, js in ((TARGETS[0], HAL_JS), (TARGETS[1], NFA_JS)):
                pid = procs.get(target)
                if pid is None:
                    continue
                old = sessions.get(target)
                if old is not None and old[0] == pid:
                    continue
                if old is not None:
                    try:
                        old[1].detach()
                    except Exception:
                        pass
                try:
                    session = attach(dev, target, js)
                    sessions[target] = (pid, session)
                    print("attached %s (pid %d)" % (target, pid), flush=True)
                except Exception as e:
                    print("attach failed %s: %s" % (target, e), flush=True)
            time.sleep(2)
        except KeyboardInterrupt:
            break
        except Exception:
            time.sleep(2)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("bye", flush=True)
