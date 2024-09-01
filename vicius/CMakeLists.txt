cmake_minimum_required(VERSION 3.28..3.29.5 FATAL_ERROR)

set(UPSTREAM_VERSION 1.7.813)
set(VERSION_SUFFIX "+fredemmott1")

# Somewhat after v1.7.813; adds support for:
# - zip files
# - terminate-process-on-update
# - local-version
# - version-suffix
set(VICIUS_COMMIT 70400535bc0cf4f321f55700842eb61fff2e5224)
# v2.5.0
set(VPATCH_COMMIT dd9a1de155a395c4964787948103a480a724e676)

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
  CONFIGURE_COMMAND
  "${vpatch_SOURCE_DIR}/bin/net8.0/vpatch.exe"
  --stamp-version "${UPSTREAM_VERSION}.0"
  --stamp-version-string "${UPSTREAM_VERSION}${VERSION_SUFFIX}"
  --resource.file-version
  --resource.product-version
  --target-file "<SOURCE_DIR>/src/vīcĭus.rc"
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
