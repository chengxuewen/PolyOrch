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
"IGZvdXIgYW5jaG9yczogdGhlIGh1YiwgdGhlIGF1dGhvcml0YXRpdmUgc291cmNlLCB0aGUKIyBk"\
"ZXNpZ24gYmFzZWxpbmUsIGFuZCB0aGUgbGVhcm5pbmcgcGF0aCAodHV0b3JpYWxzLm1kLCBhZGRl"\
"ZCAyMDI2LTA5LTMwOyB0aGUgYXVkaXQgdGhhdAojIHByb21vdGVkIGl0IGlzIHRoZSAyMDI2LTEw"\
"LTA4IGRvYy1hdWRpdCkuIEV2ZXJ5dGhpbmcgZWxzZSBpcyBjbGFzc2lmaWVkIGJ5IHRoZSBzdWJk"\
"aXJlY3RvcnkKIyBpdCBsaXZlcyBpbjogZGVyaXZlZC8gKGJvdW5kIGJ5IHRoaXMgY29udmVudGlv"\
"biksIG1vZHVsZXMvIChkZXNpZ24pLCByZWZlcmVuY2UvCiMgKGV4dGVybmFsbHkgc291cmNlZCku"\
"CnB5dGhvbjMgLSA8PCdDSEVDSycKaW1wb3J0IHBhdGhsaWIsIHN5cwpET0NTID0gcGF0aGxpYi5Q"\
"YXRoKCJkb2NzIikKUk9PVF9BTExPV0VEID0geyJSRUFETUUubWQiLCAid2hpdGVwYXBlci5tZCIs"\
"ICJhcmNoaXRlY3R1cmUubWQiLCAidHV0b3JpYWxzLm1kIn0Kcm9vdF9hY3R1YWwgPSB7cC5uYW1l"\
"IGZvciBwIGluIERPQ1MuZ2xvYigiKi5tZCIpfQpzdHJheSA9IHNvcnRlZChyb290X2FjdHVhbCAt"\
"IFJPT1RfQUxMT1dFRCkKZGVyaXZlZCA9IHNvcnRlZChwLm5hbWUgZm9yIHAgaW4gKERPQ1MgLyAi"\
"ZGVyaXZlZCIpLmdsb2IoIioubWQiKSkgaWYgKERPQ1MgLyAiZGVyaXZlZCIpLmlzX2RpcigpIGVs"\
"c2UgW10KbW9kcyA9IHNvcnRlZChwLm5hbWUgZm9yIHAgaW4gKERPQ1MgLyAibW9kdWxlcyIpLmds"\
"b2IoIioubWQiKSkgaWYgKERPQ1MgLyAibW9kdWxlcyIpLmlzX2RpcigpIGVsc2UgW10KcHJpbnQo"\
"ImRvY3MvIHJvb3Q6Iiwgc29ydGVkKHJvb3RfYWN0dWFsKSkKcHJpbnQoInN0cmF5IGF0IHJvb3Q6"\
"Iiwgc3RyYXkgb3IgIm5vbmUiKQpwcmludCgiZGVyaXZlZDoiLCBkZXJpdmVkKQpwcmludCgibW9k"\
"dWxlczoiLCBtb2RzKQpvayA9IG5vdCBzdHJheSBhbmQgZGVyaXZlZCBhbmQgIjAwLW92ZXJ2aWV3"\
"Lm1kIiBpbiBtb2RzCnN5cy5leGl0KDAgaWYgb2sgZWxzZSAxKQpDSEVDSwpyYz0kPwpbICRyYyAt"\
"ZXEgMCBdICYmIGVjaG8gIlBBU1MiCmV4aXQgJHJj"
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
"ZSBwYXJzZXIuIFNhbWUgcmF0aW9uYWxlIGFzIGV4Y2x1ZGluZyBub2RlX21vZHVsZXMuCiMgU2tp"\
"bGwgVFJJR0dFUiBQSFJBU0VTIGFyZSB0aGUgc2FtZSBjbGFzcyBvZiBmdW5jdGlvbmFsIGRhdGEg"\
"KDIwMjYtMDktMzApOiB0aGUgQ2hpbmVzZQojIHBocmFzZXMgaW4gYSBza2lsbCdzIGRlc2NyaXB0"\
"aW9uL3RyaWdnZXIgc2VjdGlvbiBtdXN0IG1hdGNoIHRoZSB1c2VyJ3Mgb3duIHdvcmRpbmcgb3Ig"\
"dGhlCiMgc2tpbGwgbmV2ZXIgYWN0aXZhdGVzLiBUaGV5IGFyZSBhY3RpdmF0aW9uIHN1cmZhY2Us"\
"IG5vdCBwcm9zZSAtLSBsaW5lcyBpbnNpZGUKIyAuYWdlbnRzL3NraWxscy8qL1NLSUxMLm1kIHRo"\
"YXQgc2l0IGluc2lkZSB0aGUgZGVzY3JpcHRpb24vdHJpZ2dlci1waHJhc2UgY29udGV4dCBhcmUK"\
"IyBhbGxvd2VkOyBldmVyeXRoaW5nIGVsc2UgaW4gYSBza2lsbCBmaWxlIHN0YXlzIEVuZ2xpc2gu"\
"CnB5dGhvbjMgLSA8PCdQWScKaW1wb3J0IHJlLCBwYXRobGliLCBzeXMKQ0pLID0gcmUuY29tcGls"\
"ZShyIltcdTRlMDAtXHU5ZmZmXSIpCkFMTE9XRUQgPSAi6Z2i5ZCR5aSa6K+t6KiAIG1vbm9yZXBv"\
"IOeahOWPr+aJqeWxleaehOW7uue8luaOkuWZqOOAgiIKRVhUUyA9IHsiLm1kIiwgIi5tanMiLCAi"\
"LmpzIiwgIi5qc29uIiwgIi5qc29uYyIsICIudG9tbCIsICIuc2giLCAiLnR4dCIsICIucHkiLCAi"\
"LnlhbWwiLCAiLnltbCJ9ClNLSVAgPSB7Ii5naXQiLCAibm9kZV9tb2R1bGVzIiwgIi5vbW8iLCAi"\
"dGFyZ2V0IiwgIi5waXhpIiwgImJvb2stdG8tc2tpbGwifQojIHRyaWdnZXItcGhyYXNlIGFsbG93"\
"YW5jZTogYSBsaW5lIHdob3NlIENKSyBpcyBpbnNpZGUgZG91YmxlIHF1b3RlcyAocGhyYXNlIGxp"\
"c3RzKSBjb3VudHMKIyBhcyBmdW5jdGlvbmFsIGRhdGEKZGVmIHRyaWdnZXJzX29ubHkobGluZSk6"\
"CiAgICBzdHJpcHBlZCA9IHJlLnN1YihyJyJbXiJdKiInLCAnJywgbGluZSkKICAgIHJldHVybiBu"\
"b3QgQ0pLLnNlYXJjaChzdHJpcHBlZCkKIyBBIHNpbmdsZSBuYW1lZCBmaWxlLCBub3QgYSBwYXR0"\
"ZXJuOiB0aGUgQ2hpbmVzZSBtaXJyb3Igb2YgdGhlIGZyb250IGRvb3IgKHNlZSBydWxlIDMgYWJv"\
"dmUpLgpBTExPV19GSUxFUyA9IHsiUkVBRE1FX3poLm1kIn0Kc2tpcF9maWxlcyA9IHsicGFja2Fn"\
"ZS1sb2NrLmpzb24ifSB8IEFMTE9XX0ZJTEVTCmJhZCA9IFtdCmZvciBwIGluIHBhdGhsaWIuUGF0"\
"aCgiLiIpLnJnbG9iKCIqIik6CiAgICBpZiBub3QgcC5pc19maWxlKCkgb3IgcC5zdWZmaXggbm90"\
"IGluIEVYVFMgb3IgcC5uYW1lIGluIHNraXBfZmlsZXM6CiAgICAgICAgY29udGludWUKICAgIGlm"\
"IGFueShwYXJ0IGluIFNLSVAgZm9yIHBhcnQgaW4gcC5wYXJ0cyk6CiAgICAgICAgY29udGludWUK"\
"ICAgIGZvciBpLCBsaW5lIGluIGVudW1lcmF0ZShwLnJlYWRfdGV4dChlcnJvcnM9Imlnbm9yZSIp"\
"LnNwbGl0bGluZXMoKSwgMSk6CiAgICAgICAgaWYgQ0pLLnNlYXJjaChsaW5lKSBhbmQgQUxMT1dF"\
"RCBub3QgaW4gbGluZToKICAgICAgICAgICAgaWYgcC5wYXJ0cyBhbmQgIi5hZ2VudHMiIGluIHAu"\
"cGFydHMgYW5kICJza2lsbHMiIGluIHAucGFydHMgYW5kIHRyaWdnZXJzX29ubHkobGluZSk6CiAg"\
"ICAgICAgICAgICAgICBjb250aW51ZQogICAgICAgICAgICBiYWQuYXBwZW5kKGYie3B9OntpfSIp"\
"CnByaW50KCJDSksgb3V0c2lkZSBhbGxvd2VkIHpvbmVzOiIsIGJhZCBvciAibm9uZSIpCnN5cy5l"\
"eGl0KDEgaWYgYmFkIGVsc2UgMCkKUFk="
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
