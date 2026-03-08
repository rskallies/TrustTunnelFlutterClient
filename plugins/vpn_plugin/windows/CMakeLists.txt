cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "vpn_plugin")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "vpn_plugin_plugin")

list(APPEND PLUGIN_SOURCES
  "vpn_plugin.cpp"
  "vpn_plugin.h"
  "runner/platform_api.g.cpp"
  "runner/platform_api.g.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/vpn_plugin/vpn_plugin_c_api.h"
  "vpn_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/runner")

# ── vpn_easy.dll ──────────────────────────────────────────────────────────────
#
# VPN engine built from TrustTunnelClient (platform/windows).
# Expected layout next to this plugin:
#
#   plugins/vpn_plugin/windows/vpn_easy/
#     include/vpn_easy.h        (vpn_easy.h + vpn/platform.h)
#     lib/vpn_easy.lib           (import library for the DLL)
#
# The DLL itself (vpn_easy.dll) must be placed in the Flutter app's build
# output directory so Windows can find it at runtime. CMake copies it there
# via the bundled_libraries mechanism below.
#
set(VPN_EASY_DIR "${CMAKE_CURRENT_SOURCE_DIR}/vpn_easy")

target_include_directories(${PLUGIN_NAME} PRIVATE
  "${VPN_EASY_DIR}/include"
)

target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  "${VPN_EASY_DIR}/lib/vpn_easy.lib"
)

# Copy the DLLs into the Flutter app bundle so they are found at runtime.
set(vpn_plugin_bundled_libraries
  "${VPN_EASY_DIR}/bin/vpn_easy.dll"
  "${VPN_EASY_DIR}/bin/wintun.dll"
  PARENT_SCOPE
)

# === Tests ===
if (${include_${PROJECT_NAME}_tests})
  set(TEST_RUNNER "${PROJECT_NAME}_test")
  enable_testing()

  include(FetchContent)
  FetchContent_Declare(
    googletest
    URL https://github.com/google/googletest/archive/release-1.11.0.zip
  )
  set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
  FetchContent_MakeAvailable(googletest)

  add_executable(${TEST_RUNNER}
    test/vpn_plugin_test.cpp
    ${PLUGIN_SOURCES}
  )
  apply_standard_settings(${TEST_RUNNER})
  target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin)
  target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
  add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
  )

  include(GoogleTest)
  gtest_discover_tests(${TEST_RUNNER})
endif()
