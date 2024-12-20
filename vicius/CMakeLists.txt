cmake_minimum_required(VERSION 3.28..3.29.5 FATAL_ERROR)

set(UPSTREAM_VERSION 1.8.876)
set(VERSION_SUFFIX "+fredemmott.1")

# Shortly after v1.8.876
# - updater will now terminate if the installer attempts to close it
# - fixed semver parsing of VERSIONINFO resources
# - version-suffix
set(VICIUS_COMMIT 317da9cc752b5b289f47104b02b05c31e13fccae)
# v2.6.0
set(VPATCH_COMMIT 52467a3135dc446b5071ba7f272e0af9c8c3d6d6)

project(
  "fredemmott_vicius"
  VERSION ${UPSTREAM_VERSION}
  LANGUAGES NONE
)

set(TWEAK_INCLUDE_DIR "${CMAKE_BINARY_DIR}/include")

configure_file(
  "${CMAKE_SOURCE_DIR}/ViciusPostCustomizeMe.in.h"
  "${TWEAK_INCLUDE_DIR}/ViciusPostCustomizeMe.h"
  @ONLY
)

find_program(DOTNET dotnet REQUIRED)
find_program(MSBUILD msbuild REQUIRED)
find_program(PWSH pwsh REQUIRED)

include(ExternalProject)

ExternalProject_Add(
  vpatch
  GIT_REPOSITORY https://github.com/nefarius/vpatch
  GIT_TAG ${VPATCH_COMMIT}
  BUILD_IN_SOURCE ON
  EXCLUDE_FROM_ALL ON
  BUILD_COMMAND
  "${DOTNET}" build -c "$<CONFIG>" vpatch.sln
  CONFIGURE_COMMAND ""
  INSTALL_COMMAND ""
)

ExternalProject_Get_Property(vpatch SOURCE_DIR)
set(vpatch_SOURCE_DIR "${SOURCE_DIR}")

ExternalProject_Add(
  vicius
  GIT_REPOSITORY https://github.com/nefarius/vicius
  GIT_TAG ${VICIUS_COMMIT}
  DEPENDS vpatch
  BUILD_IN_SOURCE ON
  EXCLUDE_FROM_ALL ON
  PATCH_COMMAND
  "${PWSH}" -ExecutionPolicy Bypass "${CMAKE_CURRENT_LIST_DIR}/isolated-vcpkg.ps1"
  &&
  cd "${vpatch_SOURCE_DIR}/src" &&
  dotnet run --
  --stamp-version "${UPSTREAM_VERSION}.0"
  --stamp-version-string "${UPSTREAM_VERSION}${VERSION_SUFFIX}"
  --resource.file-version
  --resource.product-version
  --target-file "<SOURCE_DIR>/src/vīcĭus.rc"
  CONFIGURE_COMMAND ""
  BUILD_COMMAND
  "${MSBUILD}" "vīcĭus.sln" "/p:Configuration=$<CONFIG>" "/p:Platform=x64" "/p:IncludePath=${TWEAK_INCLUDE_DIR}"
  INSTALL_COMMAND ""
)

ExternalProject_Get_Property(vicius SOURCE_DIR)
set(vicius_SOURCE_DIR "${SOURCE_DIR}")


add_custom_target(
  copy-vicius
  ALL
  COMMAND
  "${CMAKE_COMMAND}" -E copy_if_different
  "${vicius_SOURCE_DIR}/$<IF:$<CONFIG:Debug>,x64/$<CONFIG>,bin/x64>/Updater.exe"
  "${CMAKE_BINARY_DIR}/Updater-$<CONFIG>.exe"
  VERBATIM
  DEPENDS vicius
)
