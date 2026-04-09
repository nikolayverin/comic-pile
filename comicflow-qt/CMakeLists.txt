cmake_minimum_required(VERSION 3.21)

project(ComicPileQt VERSION 0.14.4 LANGUAGES CXX)

option(COMICPILE_FAST_DEV_BUILD "Speed up iterative local builds by disabling QML cachegen/AOT stats." ON)
if(COMICPILE_FAST_DEV_BUILD)
    # Dev-speed defaults:
    # - disable QML cache C++ generation and AOT stats to keep iterative UI builds fast.
    # - runtime remains unchanged for development workflow.
    set(QT_QML_NO_CACHEGEN ON)
    set(QT_QML_GENERATE_AOTSTATS OFF)
endif()

set(_comicpile_qml_module_extra_args)
if(COMICPILE_FAST_DEV_BUILD)
    list(APPEND _comicpile_qml_module_extra_args NO_CACHEGEN)
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOMOC_COMPILER_PREDEFINES OFF)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Sql Widgets Concurrent Svg Network Pdf)

qt_standard_project_setup(REQUIRES 6.5)

if(Qt6_VERSION VERSION_GREATER_EQUAL "6.8.0")
    qt_policy(SET QTP0004 NEW)
endif()

set(_comicpile_core_sources
    src/common/singleinstanceguard.cpp
    src/common/singleinstanceguard.h
    src/common/startuplaunchbootstrap.cpp
    src/common/startuplaunchbootstrap.h
    src/storage/archivepacking.cpp
    src/storage/archivepacking.h
    src/storage/archiveprocessutils.cpp
    src/storage/archiveprocessutils.h
    src/storage/archivesupportutils.cpp
    src/storage/archivesupportutils.h
    src/storage/comicinfoarchive.cpp
    src/storage/comicinfoarchive.h
    src/storage/comicinfoops.cpp
    src/storage/comicinfoops.h
    src/storage/comicsmodelutils.cpp
    src/storage/comicsmodelutils.h
    src/storage/comicslistmodel.cpp
    src/storage/comicslistmodel_delete.cpp
    src/storage/comicslistmodel_hero.cpp
    src/storage/comicslistmodel_import.cpp
    src/storage/comicslistmodel.h
    src/storage/comicslistmodel_metadata.cpp
    src/storage/comicslistmodel_reader.cpp
    src/storage/comicslistmodel_startup.cpp
    src/storage/datarootrelocationops.cpp
    src/storage/datarootrelocationops.h
    src/storage/datarootsettingsutils.cpp
    src/storage/datarootsettingsutils.h
    src/storage/datarootrelocationbootstrap.cpp
    src/storage/datarootrelocationbootstrap.h
    src/storage/deletestagingops.cpp
    src/storage/deletestagingops.h
    src/storage/duplicaterestoreresolver.cpp
    src/storage/duplicaterestoreresolver.h
    src/storage/importduplicateclassifier.cpp
    src/storage/importduplicateclassifier.h
    src/storage/importmatching.cpp
    src/storage/importmatching.h
    src/storage/importruntimeutils.cpp
    src/storage/importruntimeutils.h
    src/storage/importworkflowutils.cpp
    src/storage/importworkflowutils.h
    src/storage/imagepreparationops.cpp
    src/storage/imagepreparationops.h
    src/storage/issuefileops.cpp
    src/storage/issuefileops.h
    src/storage/librarylayoututils.cpp
    src/storage/librarylayoututils.h
    src/storage/librarydatarepairops.cpp
    src/storage/librarydatarepairops.h
    src/storage/librarymutationops.cpp
    src/storage/librarymutationops.h
    src/storage/librarystoragemigrationops.cpp
    src/storage/librarystoragemigrationops.h
    src/storage/librarystoragemigrationstate.cpp
    src/storage/librarystoragemigrationstate.h
    src/storage/libraryqueryops.cpp
    src/storage/libraryqueryops.h
    src/storage/libraryschemamanager.cpp
    src/storage/libraryschemamanager.h
    src/storage/readercacheutils.cpp
    src/storage/readercacheutils.h
    src/storage/readerpayloadutils.cpp
    src/storage/readerpayloadutils.h
    src/storage/readerrequestutils.cpp
    src/storage/readerrequestutils.h
    src/storage/readerruntimeutils.cpp
    src/storage/readerruntimeutils.h
    src/storage/readersessionops.cpp
    src/storage/readersessionops.h
    src/storage/sqliteconnectionutils.cpp
    src/storage/sqliteconnectionutils.h
    src/storage/storedpathutils.cpp
    src/storage/storedpathutils.h
    src/storage/startupinventoryops.cpp
    src/storage/startupinventoryops.h
    src/storage/startupruntimeutils.cpp
    src/storage/startupruntimeutils.h
)

qt_add_executable(comic_pile_qt
    src/main.cpp
    ${_comicpile_core_sources}
)

target_compile_definitions(comic_pile_qt PRIVATE
    COMICPILE_APP_VERSION="${PROJECT_VERSION}"
)

set(_comicpile_build_meta_dir "${CMAKE_CURRENT_BINARY_DIR}/generated/build_meta")
set(_comicpile_build_iteration_state_file "${_comicpile_build_meta_dir}/build_iteration_state.txt")
set(_comicpile_build_iteration_header "${_comicpile_build_meta_dir}/comicpile_build_iteration.h")

add_custom_target(comic_pile_qt_build_iteration
    COMMAND ${CMAKE_COMMAND}
        -DCOUNTER_STATE_FILE=${_comicpile_build_iteration_state_file}
        -DHEADER_FILE=${_comicpile_build_iteration_header}
        -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/UpdateBuildIteration.cmake"
    BYPRODUCTS
        "${_comicpile_build_iteration_state_file}"
        "${_comicpile_build_iteration_header}"
    COMMENT "Updating Comic Pile build iteration"
    VERBATIM
)

add_dependencies(comic_pile_qt comic_pile_qt_build_iteration)

if(WIN32)
    target_sources(comic_pile_qt PRIVATE app_icon.rc)
endif()

add_executable(comic_pile_smoke
    src/tools/comic_pile_smoke.cpp
    ${_comicpile_core_sources}
)

target_compile_definitions(comic_pile_smoke PRIVATE
    COMICPILE_APP_VERSION="${PROJECT_VERSION}"
)

add_executable(comic_pile_regression
    src/tools/comic_pile_regression.cpp
    ${_comicpile_core_sources}
)

target_compile_definitions(comic_pile_regression PRIVATE
    COMICPILE_APP_VERSION="${PROJECT_VERSION}"
)

qt_add_qml_module(comic_pile_qt
    URI ComicPile
    VERSION 1.0
    ${_comicpile_qml_module_extra_args}
    QML_FILES
        qml/Main.qml
        qml/DatabaseMigrationWindow.qml
        qml/controllers/StartupController.qml
        qml/controllers/StartupTelemetryController.qml
        qml/controllers/StartupSnapshotController.qml
        qml/controllers/WindowDisplayController.qml
        qml/controllers/AppSettingsController.qml
        qml/controllers/ReaderCoverController.qml
        qml/controllers/ReaderDisplayModeController.qml
        qml/controllers/ReaderSessionController.qml
        qml/controllers/ReaderPopupStateController.qml
        qml/controllers/ReadingContinuationController.qml
        qml/controllers/NavigationSurfaceController.qml
        qml/controllers/LibraryBrowseController.qml
        qml/controllers/SeriesSelectionController.qml
        qml/controllers/MetadataDialogController.qml
        qml/controllers/ReaderSpreadLayout.js
        qml/controllers/ImportController.qml
        qml/controllers/ImportSessionController.qml
        qml/controllers/DeleteController.qml
        qml/controllers/PopupController.qml
        qml/controllers/SeriesHeaderController.qml
        qml/controllers/HeroSeriesController.qml
        qml/components/TopBarMenu.qml
        qml/components/SidebarQuickFilterItem.qml
        qml/components/SidebarSeriesItem.qml
        qml/components/MainSidebar.qml
        qml/components/MainLibraryPane.qml
        qml/components/MainDialogHost.qml
        qml/components/MainStartupLayer.qml
        qml/components/MainStartupState.qml
        qml/components/IssueCard.qml
        qml/components/FocusEdgeLine.qml
        qml/components/Typography.qml
        qml/components/UiTokens.qml
        qml/components/ThemeColors.qml
        qml/components/PopupStyle.qml
        qml/components/PopupMenuStyle.qml
        qml/components/PopupMenuSurface.qml
        qml/components/PopupMenuListView.qml
        qml/components/VerticalScrollThumb.qml
        qml/components/PopupSurface.qml
        qml/components/InsetEdgeSurface.qml
        qml/components/PopupFieldBackground.qml
        qml/components/PopupTextField.qml
        qml/components/PopupTextArea.qml
        qml/components/PopupActionButton.qml
        qml/components/PopupStatusActionButton.qml
        qml/components/NavigationHelperButton.qml
        qml/components/BottomBarHelperButton.qml
        qml/components/BottomBarGridDensityControl.qml
        qml/components/PopupFooterRow.qml
        qml/components/PopupCloseButton.qml
        qml/components/PopupCloseBehavior.qml
        qml/components/PopupDialogShell.qml
        qml/components/PopupDialogWindow.qml
        qml/components/PopupModalOverlay.qml
        qml/components/PopupBodyColumn.qml
        qml/components/PopupErrorText.qml
        qml/components/PopupInlineErrorMessage.qml
        qml/components/PopupSystemErrorLayout.qml
        qml/components/PopupInfoBlock.qml
        qml/components/PopupGhostBlock.qml
        qml/components/PopupProgressBlock.qml
        qml/components/PopupConfirmDialog.qml
        qml/components/PopupCopyButton.qml
        qml/components/PopupContentGeometry.qml
        qml/components/MetadataDropdownField.qml
        qml/components/MetadataTextUtils.js
        qml/components/AppMessagePayload.js
        qml/components/ReadingTarget.js
        qml/components/SeriesContext.js
        qml/components/AppText.js
        qml/components/AppErrorMapper.js
        qml/components/SettingsCatalog.js
        qml/components/ContextMenuPopup.qml
        qml/components/HoverActionButton.qml
        qml/components/HoverActionBar.qml
        qml/components/ImportProgressOverlay.qml
        qml/components/ImportConflictDialog.qml
        qml/components/IssueMetadataDialog.qml
        qml/components/ActionResultDialog.qml
        qml/components/SeriesDeleteConfirmDialog.qml
        qml/components/FailedImportsDialog.qml
        qml/components/SeriesMetadataDialog.qml
        qml/components/SettingsBackgroundChoiceButton.qml
        qml/components/SettingsCheckbox.qml
        qml/components/SettingsChoiceDropdown.qml
        qml/components/SettingsAppearanceSection.qml
        qml/components/AboutDialog.qml
        qml/components/HelpDialog.qml
        qml/components/SettingsDialog.qml
        qml/components/SettingsRadioGroup.qml
        qml/components/SettingsSegmentedChoice.qml
        qml/components/SettingsSwitch.qml
        qml/components/SeriesHeaderDialog.qml
        qml/components/ShuffleBusySpinner.qml
        qml/components/DeleteConfirmDialog.qml
        qml/components/DeleteErrorDialog.qml
        qml/components/ReaderPopup.qml
        qml/components/HeroEditIconButton.qml
        qml/components/WindowResizeHandles.qml
        qml/components/PublisherCatalog.js
    RESOURCES
        assets/fonts/Inter-VariableFont_opsz,wght.ttf
        assets/fonts/Inter-Italic-VariableFont_opsz,wght.ttf
        assets/icons/3_dots.svg
        assets/icons/search-icon.svg
        assets/icons/drop-icon.svg
        assets/icons/drop-icon-white.svg
        assets/icons/icon-appearance.svg
        assets/icons/icon-alert-triangle.svg
        assets/icons/icon-book-open-text.svg
        assets/icons/icon-download.svg
        assets/icons/icon-library-big.svg
        assets/icons/icon-pencil-ruler.svg
        assets/icons/icon-settings.svg
        assets/icons/icon-shield-check.svg
        assets/icons/win-min.svg
        assets/icons/win-max.svg
        assets/icons/win-restore.svg
        assets/icons/win-close.svg
        assets/icons/app-title-16.png
        assets/icons/icon-folder.png
        assets/icons/icon-folder-hover.png
        assets/icons/icon-folder-opened.png
        assets/icons/icon-boormarks-hover.png
        assets/icons/icon-boormarks-idle.png
        assets/icons/copy.svg
        assets/icons/icon-favorits-hover.png
        assets/icons/icon-favorits-idle.png
        assets/icons/icon-title-bookmark.png
        assets/icons/icon-title-favorit.png
        assets/icons/icon-title-last-import.png
        assets/icons/icon-popup-info.svg
        assets/icons/icon-last-import-hover.png
        assets/icons/icon-last-import-idle.png
        assets/icons/icon-reader-bookmark.svg
        assets/icons/icon-reader-delete.svg
        assets/icons/icon-reader-settings.svg
        assets/icons/icon-reader-favorits.svg
        assets/icons/icon-reader-copy.svg
        assets/icons/icon-reader-magnifier-shadow.svg
        assets/icons/icon-reader-manga.svg
        assets/icons/icon-reader-one-page.svg
        assets/icons/icon-reader-two-page.svg
        assets/icons/icon-reader-full-screen.svg
        assets/icons/icon-reader-moon.svg
        assets/icons/icon-reader-sun.svg
        assets/icons/pencil-line-gray.svg
        assets/icons/pencil-line-white.svg
        assets/ui/search.png
        assets/ui/drop-zone-border.svg
        assets/ui/hero-9-slice.png
        assets/ui/notch.png
        assets/ui/cover-shading.png
        assets/ui/cover-hover-glow.png
        assets/ui/cover-hover.png
        assets/ui/cover-default.png
        assets/ui/cover-bookmark.png
        assets/ui/cover-read.png
        assets/ui/cover-read-cancel.png
        assets/ui/about-app-icon-256.png
        assets/ui/onboarding/back.png
        assets/ui/onboarding/close.png
        assets/ui/onboarding/next.png
        assets/ui/onboarding/slash.png
        assets/ui/onboarding/step-1.png
        assets/ui/onboarding/step-2.png
        assets/ui/onboarding/step-3.png
        assets/ui/onboarding/step-4.png
        assets/ui/onboarding/step-5-1.png
        assets/ui/onboarding/step-5-2.png
        assets/ui/grid-backgrounds/4-grid-tile-blueprint-256px.png
        assets/ui/grid-backgrounds/5-grid-tile-linen-512px.png
        assets/ui/grid-backgrounds/6-grid-tile-felt-512px.png
        assets/ui/grid-backgrounds/7-grid-tile-cartographer-1-512px.png
        assets/ui/grid-backgrounds/8-grid-tile-cradt-2-512px.png
        assets/ui/grid-backgrounds/9-grid-tile-cradt-1-512px.png
        assets/ui/grid-backgrounds/10-grid-tile-cork-1-512px.png
        assets/ui/grid-backgrounds/11-grid-tile-cork-2-512px.png
        assets/ui/grid-backgrounds/12-grid-tile-ccardbosrd-512px.png
        assets/ui/grid-backgrounds/13-grid-tile-crosslines-512px.png
        assets/ui/grid-backgrounds/14-grid-tile-fabtic-512px.png
        assets/ui/grid-backgrounds/15-grid-tile-strains-512px.png
        assets/ui/logo-after-shock-round.png
        assets/ui/logo-archie-comics-wide.png
        assets/ui/logo-aspen-comics-tall.png
        assets/ui/logo-awa-wide.png
        assets/ui/logo-boom-studio-wide.png
        assets/ui/logo-casterman-wide.png
        assets/ui/logo-dargaud-wide.png
        assets/ui/logo-dark-horse-studio-tall.png
        assets/ui/logo-dc-comics-round.png
        assets/ui/logo-delcourt-wide.png
        assets/ui/logo-dupuis-wide.png
        assets/ui/logo-dynamite-wide.png
        assets/ui/logo-glenat-wide.png
        assets/ui/logo-hakesensha-wide.png
        assets/ui/logo-humanoids-standard.png
        assets/ui/logo-idw-publishing-round.png
        assets/ui/logo-image-comics-tall.png
        assets/ui/logo-kadokawa-corporation-standard.png
        assets/ui/logo-kodansha-tall.png
        assets/ui/logo-marvel-comics-wide.png
        assets/ui/logo-oni-press-wide.png
        assets/ui/logo-panini-comics-wide.png
        assets/ui/logo-rebellion-wide.png
        assets/ui/logo-shogakui-wide.png
        assets/ui/logo-shueisha-standard.png
        assets/ui/logo-square-enix-wide.png
        assets/ui/logo-titan-comics-tall.png
        assets/ui/logo-top-cow-productions-standard.png
        assets/ui/logo-udon-entertainment-tall.png
        assets/ui/logo-valiant-comics-tall.png
        assets/ui/logo-viz-media-wide.png
        assets/ui/icon-reader-page-arrow.svg
        assets/ui/icon-reader-issue-arrow.svg
        assets/ui/reader-boornark.svg
        assets/ui/grid-corner-bl.png
        assets/ui/grid-corner-br.png
        assets/ui/grid-edge-left.png
        assets/ui/grid-edge-right.png
        assets/ui/grid-edge-bottom.png
        assets/ui/grid-tile.png
        assets/ui/background-preview-inner-shadow.png
        assets/textures/sidebar_dither_noise.png
)

target_link_libraries(comic_pile_qt
    PRIVATE
        Qt6::Quick
        Qt6::Sql
        Qt6::Widgets
        Qt6::Concurrent
        Qt6::Svg
        Qt6::Network
        Qt6::Pdf
)

target_include_directories(comic_pile_qt
    PRIVATE
        src
        "${_comicpile_build_meta_dir}"
)

target_link_libraries(comic_pile_smoke
    PRIVATE
        Qt6::Core
        Qt6::Quick
        Qt6::Sql
        Qt6::Widgets
        Qt6::Concurrent
        Qt6::Network
        Qt6::Pdf
)

target_link_libraries(comic_pile_regression
    PRIVATE
        Qt6::Core
        Qt6::Quick
        Qt6::Sql
        Qt6::Widgets
        Qt6::Concurrent
        Qt6::Network
        Qt6::Pdf
)

target_include_directories(comic_pile_smoke
    PRIVATE
        src
)

target_include_directories(comic_pile_regression
    PRIVATE
        src
)

set_target_properties(comic_pile_qt PROPERTIES
    OUTPUT_NAME "Comic Pile"
    WIN32_EXECUTABLE TRUE
)

add_custom_command(TARGET comic_pile_qt POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_RUNTIME_DLLS:comic_pile_qt>
        $<TARGET_FILE_DIR:comic_pile_qt>
    COMMAND_EXPAND_LISTS
)

if(MINGW)
    get_filename_component(_mingw_bin_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
    foreach(_mingw_rt_dll libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll)
        if(EXISTS "${_mingw_bin_dir}/${_mingw_rt_dll}")
            add_custom_command(TARGET comic_pile_qt POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${_mingw_bin_dir}/${_mingw_rt_dll}"
                    "$<TARGET_FILE_DIR:comic_pile_qt>"
            )
        endif()
    endforeach()
endif()

set(_comicpile_bundled_7zip_dir "${CMAKE_CURRENT_SOURCE_DIR}/../tools/7zip")
foreach(_comicpile_7zip_bin 7z.exe 7z.dll)
    if(EXISTS "${_comicpile_bundled_7zip_dir}/${_comicpile_7zip_bin}")
        add_custom_command(TARGET comic_pile_qt POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${_comicpile_bundled_7zip_dir}/${_comicpile_7zip_bin}"
                "$<TARGET_FILE_DIR:comic_pile_qt>"
        )
    endif()
endforeach()

set(_comicpile_qt_imageformats_dir "${CMAKE_CURRENT_SOURCE_DIR}/../tools/qt-imageformats/6.10.2/mingw_64/plugins/imageformats")
foreach(_comicpile_imageformat_dll qwebp.dll)
    if(EXISTS "${_comicpile_qt_imageformats_dir}/${_comicpile_imageformat_dll}")
        add_custom_command(TARGET comic_pile_qt POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory
                "$<TARGET_FILE_DIR:comic_pile_qt>/imageformats"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${_comicpile_qt_imageformats_dir}/${_comicpile_imageformat_dll}"
                "$<TARGET_FILE_DIR:comic_pile_qt>/imageformats/${_comicpile_imageformat_dll}"
        )
    endif()
endforeach()

set(_comicpile_bundled_djvu_runtime_dir "${CMAKE_CURRENT_SOURCE_DIR}/../tools/djvulibre/runtime")
foreach(_comicpile_djvu_runtime_file ddjvu.exe djvudump.exe djvused.exe libdjvulibre.dll libjpeg.dll libtiff.dll libz.dll COPYING.txt)
    if(EXISTS "${_comicpile_bundled_djvu_runtime_dir}/${_comicpile_djvu_runtime_file}")
        add_custom_command(TARGET comic_pile_qt POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory
                "$<TARGET_FILE_DIR:comic_pile_qt>/tools/djvulibre"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${_comicpile_bundled_djvu_runtime_dir}/${_comicpile_djvu_runtime_file}"
                "$<TARGET_FILE_DIR:comic_pile_qt>/tools/djvulibre/${_comicpile_djvu_runtime_file}"
        )
    endif()
endforeach()

set(_comicpile_bundled_djvu_notice "${CMAKE_CURRENT_SOURCE_DIR}/../tools/djvulibre/NOTICE.txt")
if(EXISTS "${_comicpile_bundled_djvu_notice}")
    add_custom_command(TARGET comic_pile_qt POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory
            "$<TARGET_FILE_DIR:comic_pile_qt>/tools/djvulibre"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${_comicpile_bundled_djvu_notice}"
            "$<TARGET_FILE_DIR:comic_pile_qt>/tools/djvulibre/NOTICE.txt"
    )
endif()

set(_comicpile_bundled_djvu_source_archive "${CMAKE_CURRENT_SOURCE_DIR}/../tools/djvulibre/djvulibre-3.5.29.real.tar.gz")
if(EXISTS "${_comicpile_bundled_djvu_source_archive}")
    add_custom_command(TARGET comic_pile_qt POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory
            "$<TARGET_FILE_DIR:comic_pile_qt>/tools/djvulibre"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${_comicpile_bundled_djvu_source_archive}"
            "$<TARGET_FILE_DIR:comic_pile_qt>/tools/djvulibre/djvulibre-3.5.29.tar.gz"
    )
endif()

install(TARGETS comic_pile_qt
    RUNTIME DESTINATION bin
)


