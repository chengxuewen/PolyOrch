"""Pure-stdlib DAP client proving a debugpy breakpoint really hits (D32 T5).

No pip packages: the wire protocol is Content-Length framed JSON over TCP
and can be driven with `socket` alone. The debuggee is launched THROUGH
debugpy's listen adapter (--wait-for-client), the client connects, sets one
breakpoint on the marker line parsed from target.py's own source, resumes,
and verifies: a `stopped` event with reason == "breakpoint", whose top
stack frame is that very line. Prints POLYORCH_DAP_OK on success; exits
nonzero with a short cause on any failure.

argv: <python-exe> <port> <target.py abs path>
"""
import json
import re
import socket
import subprocess
import sys
import time

TIMEOUT = 25.0


def fail(msg):
    print("FAIL: " + msg)
    sys.exit(1)


class Client:
    def __init__(self, sock):
        self.s = sock
        self.buf = b""
        self.seq = 0

    def request(self, cmd, **args):
        self.seq += 1
        msg = dict(seq=self.seq, type="request", command=cmd)
        if args:
            msg["arguments"] = args
        body = json.dumps(msg).encode()
        self.s.sendall(b"Content-Length: %d\r\n\r\n" % len(body) + body)
        return self.seq

    def _read(self):
        while b"\r\n\r\n" not in self.buf:
            chunk = self.s.recv(4096)
            if not chunk:
                fail("adapter closed mid-header")
            self.buf += chunk
        head, self.buf = self.buf.split(b"\r\n\r\n", 1)
        m = re.search(rb"Content-Length: (\d+)", head)
        n = int(m.group(1))
        while len(self.buf) < n:
            chunk = self.s.recv(4096)
            if not chunk:
                fail("adapter closed mid-body")
            self.buf += chunk
        body, self.buf = self.buf[:n], self.buf[n:]
        return json.loads(body)

    def expect(self, want_seq=None, event=None):
        """Read frames until a response to want_seq or an `event` arrives."""
        while True:
            msg = self._read()
            if event is not None:
                if msg.get("type") == "event" and msg.get("event") == event:
                    return msg
                if msg.get("type") == "event":
                    continue
                if msg.get("type") == "response":
                    # responses for earlier seqs are fine to skip while
                    # waiting for an event (the event loop is interleaved)
                    continue
            else:
                if msg.get("type") == "response" and msg.get("request_seq") == want_seq:
                    return msg

    def ok(self, msg):
        if msg.get("type") != "response" or not msg.get("success"):
            fail("DAP failure: " + json.dumps(msg))
        return msg


def main():
    pyexe, port, target = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    src = open(target).read().splitlines()
    line = None
    for i, l in enumerate(src, 1):
        if "marker = 42" in l:
            line = i
            break
    if line is None:
        fail("breakpoint marker line not found in target.py")

    proc = subprocess.Popen(
        [pyexe, "-m", "debugpy", "--listen", "127.0.0.1:%d" % port,
         "--wait-for-client", target],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        sock = None
        deadline = time.time() + TIMEOUT
        while time.time() < deadline and sock is None:
            if proc.poll() is not None:
                fail("adapter exited before client connected (rc=%s)" % proc.returncode)
            try:
                sock = socket.create_connection(("127.0.0.1", port), timeout=1.0)
            except OSError:
                time.sleep(0.1)
        if sock is None:
            fail("no connection to debugpy adapter on port %d" % port)
        sock.settimeout(TIMEOUT)
        c = Client(sock)

        c.ok(c.expect(c.request("initialize", adapterID="debugpy", pathFormat="das")))
        c.expect(event="initialized")
        c.ok(c.expect(c.request("setBreakpoints",
                                source={"path": target},
                                breakpoints=[{"line": line}],
                                sourceModified=False)))
        c.ok(c.expect(c.request("configurationDone")))

        stop = c.expect(event="stopped")
        if stop["body"].get("reason") != "breakpoint":
            fail("stopped for reason=%r, not breakpoint" % stop["body"].get("reason"))
        tid = stop["body"].get("threadId", 1)
        st = c.ok(c.expect(c.request("stackTrace", threadId=tid)))
        top = st["body"]["stackFrames"][0]
        if top.get("line") != line:
            fail("top frame at line %s, expected %s" % (top.get("line"), line))
        if not top.get("source", {}).get("path", "").endswith("target.py"):
            fail("top frame source is not target.py: %r" % top.get("source"))
        c.ok(c.expect(c.request("continue", threadId=tid)))
        c.expect(event="terminated")
        try:
            c.request("disconnect")
        except OSError:
            pass
        print("POLYORCH_DAP_OK")
    finally:
        if proc.poll() is None:
            proc.kill()
        proc.wait(timeout=10)


if __name__ == "__main__":
    main()
