# Install script for directory: D:/Item/AnimeHUBX/windows

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "D:/Item/AnimeHUBX/windows/out/install/x64-Debug")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Debug")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("D:/Item/AnimeHUBX/windows/out/build/x64-Debug/flutter/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("D:/Item/AnimeHUBX/windows/out/build/x64-Debug/runner/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/bitsdojo_window_windows/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/flutter_inappwebview_windows/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/media_kit_libs_windows_video/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/media_kit_video/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/screen_retriever/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/url_launcher_windows/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/volume_controller/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/window_manager/cmake_install.cmake")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Runtime" OR NOT CMAKE_INSTALL_COMPONENT)
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "D:/Item/AnimeHUBX/windows/out/install/x64-Debug/DimenX.exe")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "D:/Item/AnimeHUBX/windows/out/install/x64-Debug" TYPE EXECUTABLE FILES "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/runner/DimenX.exe")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Runtime" OR NOT CMAKE_INSTALL_COMPONENT)
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "D:/Item/AnimeHUBX/windows/out/install/x64-Debug/data/icudtl.dat")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "D:/Item/AnimeHUBX/windows/out/install/x64-Debug/data" TYPE FILE FILES "D:/Item/AnimeHUBX/windows/flutter/ephemeral/icudtl.dat")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Runtime" OR NOT CMAKE_INSTALL_COMPONENT)
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "D:/Item/AnimeHUBX/windows/out/install/x64-Debug/flutter_windows.dll")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "D:/Item/AnimeHUBX/windows/out/install/x64-Debug" TYPE FILE FILES "D:/Item/AnimeHUBX/windows/flutter/ephemeral/flutter_windows.dll")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Runtime" OR NOT CMAKE_INSTALL_COMPONENT)
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "D:/Item/AnimeHUBX/windows/out/install/x64-Debug/bitsdojo_window_windows_plugin.lib;D:/Item/AnimeHUBX/windows/out/install/x64-Debug/flutter_inappwebview_windows_plugin.dll;D:/Item/AnimeHUBX/windows/out/install/x64-Debug/media_kit_libs_windows_video_plugin.dll;D:/Item/AnimeHUBX/windows/out/install/x64-Debug/libmpv-2.dll;D:/Item/AnimeHUBX/windows/out/install/x64-Debug/d3dcompiler_47.dll;D:/Item/AnimeHUBX/windows/out/install/x64-Debug/libEGL.dll;D:/Item/AnimeHUBX/windows/out/install/x64-Debug/libGLESv2.dll;D:/Item/AnimeHUBX/windows/out/install/x64-Debug/vk_swiftshader.dll;D:/Item/AnimeHUBX/windows/out/install/x64-Debug/vulkan-1.dll;D:/Item/AnimeHUBX/windows/out/install/x64-Debug/zlib.dll;D:/Item/AnimeHUBX/windows/out/install/x64-Debug/media_kit_video_plugin.dll;D:/Item/AnimeHUBX/windows/out/install/x64-Debug/screen_retriever_plugin.dll;D:/Item/AnimeHUBX/windows/out/install/x64-Debug/url_launcher_windows_plugin.dll;D:/Item/AnimeHUBX/windows/out/install/x64-Debug/volume_controller_plugin.dll;D:/Item/AnimeHUBX/windows/out/install/x64-Debug/window_manager_plugin.dll")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "D:/Item/AnimeHUBX/windows/out/install/x64-Debug" TYPE FILE FILES
    "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/bitsdojo_window_windows/bitsdojo_window_windows_plugin.lib"
    "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/flutter_inappwebview_windows/flutter_inappwebview_windows_plugin.dll"
    "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/media_kit_libs_windows_video/media_kit_libs_windows_video_plugin.dll"
    "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/libmpv/libmpv-2.dll"
    "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/ANGLE/d3dcompiler_47.dll"
    "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/ANGLE/libEGL.dll"
    "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/ANGLE/libGLESv2.dll"
    "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/ANGLE/vk_swiftshader.dll"
    "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/ANGLE/vulkan-1.dll"
    "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/ANGLE/zlib.dll"
    "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/media_kit_video/media_kit_video_plugin.dll"
    "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/screen_retriever/screen_retriever_plugin.dll"
    "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/url_launcher_windows/url_launcher_windows_plugin.dll"
    "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/volume_controller/volume_controller_plugin.dll"
    "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/plugins/window_manager/window_manager_plugin.dll"
    )
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Runtime" OR NOT CMAKE_INSTALL_COMPONENT)
  
  file(REMOVE_RECURSE "D:/Item/AnimeHUBX/windows/out/install/x64-Debug/data/flutter_assets")
  
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Runtime" OR NOT CMAKE_INSTALL_COMPONENT)
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "D:/Item/AnimeHUBX/windows/out/install/x64-Debug/data/flutter_assets")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "D:/Item/AnimeHUBX/windows/out/install/x64-Debug/data" TYPE DIRECTORY FILES "D:/Item/AnimeHUBX/build//flutter_assets")
endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
if(CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/install_local_manifest.txt"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
if(CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_COMPONENT MATCHES "^[a-zA-Z0-9_.+-]+$")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")
  else()
    string(MD5 CMAKE_INST_COMP_HASH "${CMAKE_INSTALL_COMPONENT}")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INST_COMP_HASH}.txt")
    unset(CMAKE_INST_COMP_HASH)
  endif()
else()
  set(CMAKE_INSTALL_MANIFEST "install_manifest.txt")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "D:/Item/AnimeHUBX/windows/out/build/x64-Debug/${CMAKE_INSTALL_MANIFEST}"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
