# libgeoip & GeoLiteCityv6.dat: GeoIP locations
list(APPEND LIBGEOIP_CONFIGURE_CMD env)
if(ENABLE_TEST_DEPENDENCIES)
  list(APPEND LIBGEOIP_CONFIGURE_CMD LDFLAGS=-Wl,-rpath,${STAGE_EMBEDDED_DIR}/lib:${INSTALL_PREFIX_EMBEDDED}/lib)
else()
  list(APPEND LIBGEOIP_CONFIGURE_CMD LDFLAGS=-Wl,-rpath,${INSTALL_PREFIX_EMBEDDED}/lib)
endif()
list(APPEND LIBGEOIP_CONFIGURE_CMD <SOURCE_DIR>/configure)
list(APPEND LIBGEOIP_CONFIGURE_CMD --prefix=${INSTALL_PREFIX_EMBEDDED})

ExternalProject_Add(
  libgeoip
  URL https://github.com/maxmind/geoip-api-c/releases/download/v${LIBGEOIP_VERSION}/GeoIP-${LIBGEOIP_VERSION}.tar.gz
  URL_HASH MD5=${LIBGEOIP_HASH}
  CONFIGURE_COMMAND ${LIBGEOIP_CONFIGURE_CMD}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

ExternalProject_Add(
  # Make the project name dynamic based on the current date. This forces a
  # re-download once per day. This helps ensure development and CI environments
  # are using fresh GeoIP data files without downloading on each run.
  geolitecity-${RELEASE_DATE}
  URL https://geolite.maxmind.com/download/geoip/database/GeoLiteCityv6-beta/GeoLiteCityv6.dat.gz
  DOWNLOAD_NO_EXTRACT 1
  # Since we re-download every day as a separate project name, this cleans up
  # any old downloads in the work directory.
  CONFIGURE_COMMAND find ${CMAKE_BINARY_DIR}/${EP_BASE} -maxdepth 2 -name geolitecity* -not -name geolitecity-${RELEASE_DATE}* -print -exec rm -rf {} $<SEMICOLON>
  BUILD_COMMAND gunzip -c <DOWNLOADED_FILE> > <BINARY_DIR>/GeoLiteCityv6.dat
  INSTALL_COMMAND install -D -m 644 <BINARY_DIR>/GeoLiteCityv6.dat ${STAGE_EMBEDDED_DIR}/var/db/geoip/city-v6.dat
)
