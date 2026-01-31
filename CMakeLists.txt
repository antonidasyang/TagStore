cmake_minimum_required(VERSION 3.16)

# Read version from file
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "version.txt")
file(READ "version.txt" VER)
string(STRIP "${VER}" VER)

project(TagStore VERSION ${VER} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Find Qt6 packages
find_package(Qt6 REQUIRED COMPONENTS
    Core
    Quick
    Sql
    Network
    Concurrent
)

# Source files
set(SOURCES
    src/main.cpp
    src/core/DatabaseManager.cpp
    src/core/FileHasher.cpp
    src/core/LibraryConfig.cpp
    src/core/LLMClient.cpp
    src/core/ThemeManager.cpp
    src/core/LanguageManager.cpp
    src/models/LibraryModel.cpp
    src/viewmodels/FileIngestor.cpp
    src/workers/LLMProcessor.cpp
    src/workers/TextExtractor.cpp
)

set(HEADERS
    src/core/DatabaseManager.h
    src/core/FileHasher.h
    src/core/LibraryConfig.h
    src/core/LLMClient.h
    src/core/ThemeManager.h
    src/core/LanguageManager.h
    src/models/LibraryModel.h
    src/viewmodels/FileIngestor.h
    src/workers/LLMProcessor.h
    src/workers/TextExtractor.h
)

# QML files
set(QML_FILES
    qml/Main.qml
    qml/DropBalloon.qml
    qml/components/TagChip.qml
    qml/components/FileCard.qml
    qml/components/GlobalHeader.qml
    qml/components/TagFilterBar.qml
    qml/components/ResultsGrid.qml
    qml/components/TagManagerDialog.qml
    qml/components/ConflictContent.qml
    qml/components/FolderImportContent.qml
)

# Resources
set(RESOURCES
    assets/resources.qrc
)

# Windows icon and version resource
if(WIN32)
    # Ensure tweak version is set (default to 0 if missing)
    if(NOT DEFINED PROJECT_VERSION_TWEAK)
        set(PROJECT_VERSION_TWEAK 0)
    endif()
    
    # Prepare icon path with escaped backslashes for RC
    file(TO_NATIVE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/assets/icon.ico" ICON_NATIVE_PATH)
    string(REPLACE "\\" "\\\\" ICON_PATH "${ICON_NATIVE_PATH}")
    
    # Configure app.rc from template
    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/assets/app.rc.in
        ${CMAKE_CURRENT_BINARY_DIR}/app.rc
        @ONLY
    )
    set(WIN_ICON_RC ${CMAKE_CURRENT_BINARY_DIR}/app.rc)
endif()

# Pass version as a string literal (escaped quotes)
add_compile_definitions(APP_VERSION="${PROJECT_VERSION}")

qt_add_executable(${PROJECT_NAME}
    ${SOURCES}
    ${HEADERS}
    ${RESOURCES}
    ${WIN_ICON_RC}
)

if(CMAKE_BUILD_TYPE STREQUAL "Release")
    set(INSTALL_BIN_DIR "${CMAKE_SOURCE_DIR}/installer/bin")

    file(MAKE_DIRECTORY ${INSTALL_BIN_DIR})

    add_custom_command(
        TARGET TagStore
        POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            $<TARGET_FILE:TagStore>
            ${INSTALL_BIN_DIR}/$<TARGET_FILE_NAME:TagStore>
        COMMENT "Copying TagStore.exe to ${INSTALL_BIN_DIR}"
    )
endif()

# Suppress Qt policy QTP0004 warning
qt_policy(SET QTP0004 NEW)

qt_add_qml_module(${PROJECT_NAME}
    URI TagStore
    VERSION 1.0
    QML_FILES ${QML_FILES}
    RESOURCE_PREFIX /
)

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/core
    ${CMAKE_CURRENT_SOURCE_DIR}/src/models
    ${CMAKE_CURRENT_SOURCE_DIR}/src/viewmodels
    ${CMAKE_CURRENT_SOURCE_DIR}/src/workers
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::Sql
    Qt6::Network
    Qt6::Concurrent
)

# Platform-specific settings
if(WIN32)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        WIN32_EXECUTABLE TRUE
    )
elseif(APPLE)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        MACOSX_BUNDLE TRUE
    )
endif()
