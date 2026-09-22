#!/usr/bin/env bash
# scripts/gate.sh -- canonical gates + suite one-shot (R1.3).
#
# PIT-19 lesson, encoded structurally: ad-hoc retyped gate probes reported
# false FAILs. The C1-C6 blocks below are embedded VERBATIM from
# .agents/memorys/conventions.md (base64, decoded at run time -- zero
# quoting drift). Refresh ONLY via: python3 scripts/gate-gen.py
#
# Each block runs in an isolated bash -c child: canonical bodies may use
# exit 1 / cd without poisoning the runner (C1 exits on failure; C5 cds
# into .agents/skills).
set -uo pipefail
cd "$(dirname "$0")/.."
rc=0
runb64() {  # runb64 <label> <base64-of-script>
    local label="$1" b64="$2" script
    script="$(printf '%s' "$b64" | base64 -d)"
    echo "=== $label ==="
    if bash -c "$script"; then echo "[PASS] $label"; else
        echo "[FAIL] $label"; rc=1
    fi
}
run() {  # run <label> <cmd...>
    local label="$1"; shift
    echo "=== $label ==="
    if "$@"; then echo "[PASS] $label"; else
        echo "[FAIL] $label (rc=$?)"; rc=1
    fi
}

# ---- C1 (verbatim from conventions.md; do not edit here) ----
runb64 "C1" \
"IyBTY29wZSBpcyB0aGUgY29udGVudCBmaWxlczogZG9jcy8gYW5kIHRoZSByZXBvc2l0b3J5LXJv"\
"b3QgZG9jdW1lbnRzIChSRUFETUUubWQsCiMgU0tJTEwubWQpLCBwbHVzIHRoZSBmdXR1cmUgc291"\
"cmNlIHRyZWUuCiMgSW5zdHJ1Y3Rpb24gYW5kIHJ1bGUgZmlsZXMgKEFHRU5UUy5tZCwgLmFnZW50"\
"cy8pIGFyZSBOT1Qgc2Nhbm5lZDogdGhleSBsZWdpdGltYXRlbHkKIyBjb250YWluIHRoZSBmb3Ji"\
"aWRkZW4gbGl0ZXJhbHMgYXMgY291bnRlci1leGFtcGxlcyAoc2VlIFBJVC0xKS4KaWYgZ3JlcCAt"\
"cnFFICdQb2x5b3JjaHxwb2x5T3JjaHxQT0xZT1JDSChbXkEtWl9dfCQpJyBkb2NzLyBSRUFETUUu"\
"bWQgU0tJTEwubWQ7IHRoZW4KICBlY2hvICJGQUlMOiB3cm9uZyBicmFuZCBjYXNpbmciOyBleGl0"\
"IDEKZWxzZSBlY2hvICJQQVNTIjsgZmk="
# ---- END C1 ----

# ---- C2 (verbatim from conventions.md; do not edit here) ----
runb64 "C2" \
"Z3JlcCAtcUYgJ0Egc2NhbGFibGUgYnVpbGQgb3JjaGVzdHJhdG9yIGZvciBwb2x5Z2xvdCBtb25v"\
"cmVwb3MuJyBkb2NzL3doaXRlcGFwZXIubWQgfHwgeyBlY2hvICJGQUlMOiBtYWluIGRlc2NyaXB0"\
"aW9uIG1pc3NpbmciOyBleGl0IDE7IH0KZ3JlcCAtcUYgJ0FkYXB0ZXItYmFzZWQgaW50ZWdyYXRp"\
"b24gZm9yIGhldGVyb2dlbmVvdXMgYnVpbGQgc3lzdGVtcywgZW52aXJvbm1lbnRzLCBhbmQgcGFj"\
"a2FnZSBtYW5hZ2Vycy4nIGRvY3Mvd2hpdGVwYXBlci5tZCB8fCB7IGVjaG8gIkZBSUw6IHN1YnRp"\
"dGxlIG1pc3NpbmciOyBleGl0IDE7IH0KZ3JlcCAtcUYgJ+mdouWQkeWkmuivreiogCBtb25vcmVw"\
"byDnmoTlj6/mianlsZXmnoTlu7rnvJbmjpLlmajjgIInIGRvY3Mvd2hpdGVwYXBlci5tZCB8fCB7"\
"IGVjaG8gIkZBSUw6IENoaW5lc2UgbWFpbiBkZXNjcmlwdGlvbiBtaXNzaW5nIjsgZXhpdCAxOyB9"\
"CiMgVGhlIHJlY29yZCBtdXN0IGRlY2xhcmUgaXRzZWxmIGZyb3plbiwgb3IgdGhlIGF1dGhvcml0"\
"eSBtb2RlbCBzaWxlbnRseSByZXZlcnRzLgpncmVwIC1xRiAnRnJvemVuIHYxLjAgcmVjb3JkJyBk"\
"b2NzL3doaXRlcGFwZXIubWQgfHwgeyBlY2hvICJGQUlMOiB3aGl0ZXBhcGVyIGFyY2hpdmUgc3Rh"\
"dHVzIG1pc3NpbmciOyBleGl0IDE7IH0KIyBkb2NzLyBtYXkgaG9sZCBhdCBpdHMgcm9vdCBvbmx5"\
"IHRocmVlIGFuY2hvcnM6IHRoZSBodWIsIHRoZSBhdXRob3JpdGF0aXZlIHNvdXJjZSwgYW5kIHRo"\
"ZQojIGRlc2lnbiBiYXNlbGluZS4gRXZlcnl0aGluZyBlbHNlIGlzIGNsYXNzaWZpZWQgYnkgdGhl"\
"IHN1YmRpcmVjdG9yeSBpdCBsaXZlcyBpbjogZGVyaXZlZC8KIyAoYm91bmQgYnkgdGhpcyBjb252"\
"ZW50aW9uKSwgbW9kdWxlcy8gKGRlc2lnbiksIHJlZmVyZW5jZS8gKGV4dGVybmFsbHkgc291cmNl"\
"ZCkuCnB5dGhvbjMgLSA8PCdDSEVDSycKaW1wb3J0IHBhdGhsaWIsIHN5cwpET0NTID0gcGF0aGxp"\
"Yi5QYXRoKCJkb2NzIikKUk9PVF9BTExPV0VEID0geyJSRUFETUUubWQiLCAid2hpdGVwYXBlci5t"\
"ZCIsICJhcmNoaXRlY3R1cmUubWQifQpyb290X2FjdHVhbCA9IHtwLm5hbWUgZm9yIHAgaW4gRE9D"\
"Uy5nbG9iKCIqLm1kIil9CnN0cmF5ID0gc29ydGVkKHJvb3RfYWN0dWFsIC0gUk9PVF9BTExPV0VE"\
"KQpkZXJpdmVkID0gc29ydGVkKHAubmFtZSBmb3IgcCBpbiAoRE9DUyAvICJkZXJpdmVkIikuZ2xv"\
"YigiKi5tZCIpKSBpZiAoRE9DUyAvICJkZXJpdmVkIikuaXNfZGlyKCkgZWxzZSBbXQptb2RzID0g"\
"c29ydGVkKHAubmFtZSBmb3IgcCBpbiAoRE9DUyAvICJtb2R1bGVzIikuZ2xvYigiKi5tZCIpKSBp"\
"ZiAoRE9DUyAvICJtb2R1bGVzIikuaXNfZGlyKCkgZWxzZSBbXQpwcmludCgiZG9jcy8gcm9vdDoi"\
"LCBzb3J0ZWQocm9vdF9hY3R1YWwpKQpwcmludCgic3RyYXkgYXQgcm9vdDoiLCBzdHJheSBvciAi"\
"bm9uZSIpCnByaW50KCJkZXJpdmVkOiIsIGRlcml2ZWQpCnByaW50KCJtb2R1bGVzOiIsIG1vZHMp"\
"Cm9rID0gbm90IHN0cmF5IGFuZCBkZXJpdmVkIGFuZCAiMDAtb3ZlcnZpZXcubWQiIGluIG1vZHMK"\
"c3lzLmV4aXQoMCBpZiBvayBlbHNlIDEpCkNIRUNLCmVjaG8gIlBBU1Mi"
# ---- END C2 ----

# ---- C3 (verbatim from conventions.md; do not edit here) ----
runb64 "C3" \
"cHl0aG9uMyAtIDw8J1BZJwppbXBvcnQgcmUsIHBhdGhsaWIsIHN5cwpiYWQgPSBbXQpmb3IgbWQg"\
"aW4gcGF0aGxpYi5QYXRoKCJkb2NzIikucmdsb2IoIioubWQiKToKICAgIGZvciBsaW5rIGluIHJl"\
"LmZpbmRhbGwociJcXVwoKFwuL1teKV0rXC5tZClcKSIsIG1kLnJlYWRfdGV4dCgpKToKICAgICAg"\
"ICBpZiBub3QgKG1kLnBhcmVudCAvIGxpbmspLnJlc29sdmUoKS5leGlzdHMoKToKICAgICAgICAg"\
"ICAgYmFkLmFwcGVuZChmInttZH06IHtsaW5rfSIpCnByaW50KCJCUk9LRU46IiwgYmFkIG9yICJu"\
"b25lIikKc3lzLmV4aXQoMSBpZiBiYWQgZWxzZSAwKQpQWQ=="
# ---- END C3 ----

# ---- C4 (verbatim from conventions.md; do not edit here) ----
runb64 "C4" \
"IyBPbmx5IHRoZSBjYW5vbmljYWwgQ2hpbmVzZSBicmFuZCBzdHJpbmcgbWF5IHJlbWFpbiBpbiBh"\
"cnRpZmFjdHMuCiMgLm9tby8gaXMgc2tpcHBlZCBlbnRpcmVseTogaXQgaXMgdGhlIENoaW5lc2Ut"\
"cGVybWl0dGVkIHpvbmUgKHBsYW5zICsgc2Vzc2lvbiBzdGF0ZSkuCiMgYm9vay10by1za2lsbCBp"\
"cyBza2lwcGVkOiB2ZW5kb3JlZCB0aGlyZC1wYXJ0eSBjb2RlIHdob3NlIENoaW5lc2Ugc3RyaW5n"\
"cyBhcmUgRlVOQ1RJT05BTAojIERBVEEgKENKSyBjaGFwdGVyLWhlYWRpbmcgcGF0dGVybnMgdGhl"\
"IHBhcnNlciBtYXRjaGVzKSwgbm90IHByb3NlLiBUcmFuc2xhdGluZyB0aGVtIGJyZWFrcwojIHRo"\
"ZSBwYXJzZXIuIFNhbWUgcmF0aW9uYWxlIGFzIGV4Y2x1ZGluZyBub2RlX21vZHVsZXMuCnB5dGhv"\
"bjMgLSA8PCdQWScKaW1wb3J0IHJlLCBwYXRobGliLCBzeXMKQ0pLID0gcmUuY29tcGlsZShyIltc"\
"dTRlMDAtXHU5ZmZmXSIpCkFMTE9XRUQgPSAi6Z2i5ZCR5aSa6K+t6KiAIG1vbm9yZXBvIOeahOWP"\
"r+aJqeWxleaehOW7uue8luaOkuWZqOOAgiIKRVhUUyA9IHsiLm1kIiwgIi5tanMiLCAiLmpzIiwg"\
"Ii5qc29uIiwgIi5qc29uYyIsICIudG9tbCIsICIuc2giLCAiLnR4dCIsICIucHkiLCAiLnlhbWwi"\
"LCAiLnltbCJ9ClNLSVAgPSB7Ii5naXQiLCAibm9kZV9tb2R1bGVzIiwgIi5vbW8iLCAidGFyZ2V0"\
"IiwgIi5waXhpIiwgImJvb2stdG8tc2tpbGwifQojIEEgc2luZ2xlIG5hbWVkIGZpbGUsIG5vdCBh"\
"IHBhdHRlcm46IHRoZSBDaGluZXNlIG1pcnJvciBvZiB0aGUgZnJvbnQgZG9vciAoc2VlIHJ1bGUg"\
"MyBhYm92ZSkuCkFMTE9XX0ZJTEVTID0geyJSRUFETUVfemgubWQifQpza2lwX2ZpbGVzID0geyJw"\
"YWNrYWdlLWxvY2suanNvbiJ9IHwgQUxMT1dfRklMRVMKYmFkID0gW10KZm9yIHAgaW4gcGF0aGxp"\
"Yi5QYXRoKCIuIikucmdsb2IoIioiKToKICAgIGlmIG5vdCBwLmlzX2ZpbGUoKSBvciBwLnN1ZmZp"\
"eCBub3QgaW4gRVhUUyBvciBwLm5hbWUgaW4gc2tpcF9maWxlczoKICAgICAgICBjb250aW51ZQog"\
"ICAgaWYgYW55KHBhcnQgaW4gU0tJUCBmb3IgcGFydCBpbiBwLnBhcnRzKToKICAgICAgICBjb250"\
"aW51ZQogICAgZm9yIGksIGxpbmUgaW4gZW51bWVyYXRlKHAucmVhZF90ZXh0KGVycm9ycz0iaWdu"\
"b3JlIikuc3BsaXRsaW5lcygpLCAxKToKICAgICAgICBpZiBDSksuc2VhcmNoKGxpbmUpIGFuZCBB"\
"TExPV0VEIG5vdCBpbiBsaW5lOgogICAgICAgICAgICBiYWQuYXBwZW5kKGYie3B9OntpfSIpCnBy"\
"aW50KCJDSksgb3V0c2lkZSBhbGxvd2VkIHpvbmVzOiIsIGJhZCBvciAibm9uZSIpCnN5cy5leGl0"\
"KDEgaWYgYmFkIGVsc2UgMCkKUFk="
# ---- END C4 ----

# ---- C5 (verbatim from conventions.md; do not edit here) ----
runb64 "C5" \
"IyBSdW4gZnJvbSB0aGUgcmVwb3NpdG9yeSByb290LiBPZmZsaW5lOyA1OCBlbnRyaWVzIGV4cGVj"\
"dGVkLgpjZCAuYWdlbnRzL3NraWxscyAmJiBweXRob24zIC0gPDwnQ0hLJwppbXBvcnQgaGFzaGxp"\
"YiwgcGF0aGxpYiwgc3lzCmJhZCA9IFtdCmZvciBsaW5lIGluIHBhdGhsaWIuUGF0aCgiWE1BS0Ut"\
"TUFOSUZFU1Quc2hhMjU2IikucmVhZF90ZXh0KCkuc3BsaXRsaW5lcygpOgogICAgZGlnZXN0LCBy"\
"ZWwgPSBsaW5lLnNwbGl0KCIgICIsIDEpCiAgICBwID0gcGF0aGxpYi5QYXRoKHJlbCkKICAgIGlm"\
"IG5vdCBwLmlzX2ZpbGUoKTogYmFkLmFwcGVuZCgiTUlTU0lORyAiICsgcmVsKQogICAgZWxpZiBo"\
"YXNobGliLnNoYTI1NihwLnJlYWRfYnl0ZXMoKSkuaGV4ZGlnZXN0KCkgIT0gZGlnZXN0OiBiYWQu"\
"YXBwZW5kKCJNT0RJRklFRCAiICsgcmVsKQpwcmludCgidmVuZG9yZWQgZHJpZnQ6IiwgYmFkIG9y"\
"ICJub25lIikKc3lzLmV4aXQoMSBpZiBiYWQgZWxzZSAwKQpDSEs="
# ---- END C5 ----

# ---- C6 (verbatim from conventions.md; do not edit here) ----
runb64 "C6" \
"IyBUaGUgcGF0dGVybiBpcyBicmFja2V0ZWQgc28gdGhpcyBmaWxlIGRvZXMgbm90IHNlbGYtbWF0"\
"Y2ggKFBJVC0xKS4KIyBTY29wZSA9IHZlcnNpb24tY29udHJvbGxlZCBmb3JtYWwgZG9jdW1lbnRz"\
"IE9OTFkuIE5ldmVyIHdpZGVuIHRoZSBzY2FuIHRvIC90bXAKIyBzY3JhdGNoLCBidWlsZCB0cmVl"\
"cywgb3IgZ2l0LWlnbm9yZWQgbG9jYWwgY29ycG9yYSAoLnJlZmluZm8vIGFuYWx5c2lzIGNoZWNr"\
"b3V0cywKIyBpbnN0YWxsZWQgLnBpeGkgc3RvcmVzKTogYWJzb2x1dGUgcGF0aHMgdGhlcmUgbGVn"\
"aXRpbWF0ZWx5IGVtYmVkIHRoZSBob3N0IG5hbWUsCiMgYW5kIHByb2JpbmcgdGhlbSBmcm9tIGlu"\
"c2lkZSB0aGUgcmVwbyBwcm9kdWNlZCB0aHJlZSBmYWxzZSBGQUlMcyBvbiAyMDI2LTA5LTIxLgpp"\
"ZiBncmVwIC1yaWxFICdbVnZdaXNpYVtFXW5naW5lJyBkb2NzLyAuYWdlbnRzLyBBR0VOVFMubWQg"\
"UkVBRE1FLm1kIFJFQURNRV96aC5tZCBTS0lMTC5tZDsgdGhlbgogIGVjaG8gIkZBSUw6IGNyb3Nz"\
"LXByb2plY3QgbmFtZSBsZWFrZWQgaW50byBhIGZvcm1hbCBkb2N1bWVudCI7IGV4aXQgMQplbHNl"\
"IGVjaG8gIlBBU1MiOyBmaQ=="
# ---- END C6 ----


# ---- suites (three-tier discipline + standalone ctest dual path) ----
run "suite: offline run.sh"     bash tests/run.sh
if [ "${GATE_E2E:-1}" = "1" ]; then
    run "suite: e2e run.sh"     env POLYORCH_TEST_E2E=1 bash tests/run.sh
fi
run "suite: matrix.sh"          bash tests/matrix.sh
if [ "${GATE_CTEST:-1}" = "1" ]; then
    run "suite: ctest standalone"   bash scripts/ctest.sh
    if [ "${GATE_E2E:-1}" = "1" ]; then
        run "suite: ctest e2e"      env POLYORCH_TEST_E2E=ON bash scripts/ctest.sh
    fi
fi

echo "================================"
if [ "$rc" -eq 0 ]; then echo "GATE: ALL GREEN"; else echo "GATE: FAILURES PRESENT (rc=$rc)"; fi
exit $rc
