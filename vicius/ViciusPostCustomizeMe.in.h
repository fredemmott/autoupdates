#pragma once

#undef NV_API_URL_TEMPLATE
#define NV_API_URL_TEMPLATE "https://autoupdates.fredemmott.com/{}.json"

// Allow hyphens in particular
#undef NV_FILENAME_REGEX
#define NV_FILENAME_REGEX R"((\\w+)_([a-zA-Z0-9-]+)_Updater)"

#undef NV_CUSTOM_VERSION_SUFFIX
#define NV_CUSTOM_VERSION_SUFFIX "@VERSION_SUFFIX@"
