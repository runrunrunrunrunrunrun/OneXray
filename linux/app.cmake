set(APP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/app")

install(PROGRAMS
        "${APP_DIR}/OneXrayCore"
        DESTINATION "${CMAKE_INSTALL_PREFIX}"
        COMPONENT Runtime)
