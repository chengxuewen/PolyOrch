# expect-log THIRD-PARTY-FP-OK
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")

set(_a "1111111111111111111111111111111111111111111111111111111111111111")
set(_b "2222222222222222222222222222222222222222222222222222222222222222")

# 1) identical inputs -> identical key
polyorch_thirdparty_fingerprint(k1 ARCHIVE_SHA256 "${_a}" BUILD_TYPE Debug)
polyorch_thirdparty_fingerprint(k2 ARCHIVE_SHA256 "${_a}" BUILD_TYPE Debug)
ck(k1 STREQUAL k2)

# 2) OPTIONS whitespace/order cannot produce a false-distinct key (F4=A)
polyorch_thirdparty_fingerprint(k3 ARCHIVE_SHA256 "${_a}" BUILD_TYPE Debug OPTIONS "B=2" " A=1 ")
polyorch_thirdparty_fingerprint(k4 ARCHIVE_SHA256 "${_a}" BUILD_TYPE Debug OPTIONS "A=1" "B=2")
ck(k3 STREQUAL k4)
ck(NOT k1 STREQUAL k3)

# 3) O-3: a different effective config is a different key
polyorch_thirdparty_fingerprint(k5 ARCHIVE_SHA256 "${_a}" BUILD_TYPE Release)
ck(NOT k1 STREQUAL k5)

# 4) a different artifact is a different key
polyorch_thirdparty_fingerprint(k6 ARCHIVE_SHA256 "${_b}" BUILD_TYPE Debug)
ck(NOT k1 STREQUAL k6)

# 5) short12 is the key prefix; the dossier carries the M1 fields
string(LENGTH "${k1_SHORT12}" _n12)
ck(_n12 EQUAL 12)
ck(k1 MATCHES "^${k1_SHORT12}")
ck(k1_DOSSIER MATCHES "recipe_sha256=")
ck(k1_DOSSIER MATCHES "schema_version=")
ck(k1_DOSSIER MATCHES "helper_version=")

# 6) M1: the recipe itself participates -- same artifacts, new recipe, new key
polyorch_thirdparty_fingerprint(k7 ARCHIVE_SHA256 "${_a}" BUILD_TYPE Debug RECIPE_SHA256 deadbeef)
ck(NOT k1 STREQUAL k7)

message(STATUS "THIRD-PARTY-FP-OK")
