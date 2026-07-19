# Copyright (C) 2018-2019 Casper Meijn <casper@meijn.net>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

cmake_minimum_required(VERSION 3.7)

project(onvifviewer VERSION "0.13")

# Find the number of commits since the last release and use this as version patch number
find_package(Git)
if(GIT_FOUND)
   execute_process(
        COMMAND "${GIT_EXECUTABLE}" rev-list v${PROJECT_VERSION}...HEAD
        COMMAND wc -l
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        RESULT_VARIABLE result OUTPUT_VARIABLE output 
        ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(result EQUAL 0)
        message("Number of commits since last git tag: ${output}")
        project(${PROJECT_NAME} VERSION "${PROJECT_VERSION}.${output}")
    endif()
endif()

SET(CMAKE_CXX_STANDARD 17)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

include(FeatureSummary)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake")
find_package(Gettext 0.19 REQUIRED)
find_package(ECM 5.240.0 REQUIRED NO_MODULE)
set_package_properties(ECM PROPERTIES TYPE REQUIRED DESCRIPTION "Extra CMake Modules." URL "https://projects.kde.org/projects/kdesupport/extra-cmake-modules")
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${ECM_MODULE_PATH})
find_package(KDSoap-qt6 2.0.0 REQUIRED)
set_package_properties(KDSoap-qt6 PROPERTIES DESCRIPTION "A Qt-based client-side and server-side SOAP component" URL "http://www.kdab.com/products/kd-soap" TYPE REQUIRED PURPOSE "Support for SOAP client protocol")
find_package(KF6 6.0.0 REQUIRED CoreAddons I18n)
find_package(KF6Kirigami 6.0.0 REQUIRED)
find_package(Qt6 6.4.0 REQUIRED NO_MODULE COMPONENTS Core Svg Qml Quick QuickControls2 Xml)
set_package_properties(Qt6 PROPERTIES DESCRIPTION "The Qt6 framework" URL "http://www.qt.io" TYPE REQUIRED)
find_package(KDSoapWSDiscoveryClient 0.4)
set_package_properties(KDSoapWSDiscoveryClient PROPERTIES DESCRIPTION "KDSoap WS-Discovery client" URL "https://gitlab.com/caspermeijn/kdsoap-ws-discovery-client" TYPE OPTIONAL)

if(NOT ANDROID)
    find_package(KF6 6.0.0 REQUIRED XmlGui)
    add_definitions(-DWITH_KF5_XML_GUI)
endif()

include(ECMQMLModules)
include(ECMSetupVersion)
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

# The KF6 KDECompilerSettings enable stricter Qt definitions than KF5 did.
# This code base predates them (it uses signals/emit keywords and implicit
# string conversions), so disable the ones it does not comply with.
remove_definitions(
    -DQT_NO_KEYWORDS
    -DQT_NO_CAST_FROM_ASCII
    -DQT_NO_CAST_TO_ASCII
    -DQT_NO_CAST_FROM_BYTEARRAY
    -DQT_NO_URL_CAST_FROM_STRING
)

##TODO: figure out whye these qml module checks fail for gitlab-ci
#ecm_find_qmlmodule(org.kde.kirigami 2.5 REQUIRED)
#ecm_find_qmlmodule(QtMultimedia 5.9 REQUIRED)
#ecm_find_qmlmodule(QtQml.Models 2.1 REQUIRED)
#ecm_find_qmlmodule(QtQuick 2.9 REQUIRED)
#ecm_find_qmlmodule(QtQuick.Controls 1.4 REQUIRED)
##TODO: figure out why QtQuick.Controls 2.3 is not found
##ecm_find_qmlmodule(QtQuick.Controls 2.3 REQUIRED)
##ecm_find_qmlmodule(QtQuick.Controls.Material 2.3 REQUIRED)
#ecm_find_qmlmodule(QtQuick.Layouts 1.3 REQUIRED)

# Enable extra warnings
add_compile_options(-pedantic-errors -Wconversion -Wsign-conversion)

add_subdirectory(android)
add_subdirectory(libOnvifConnect)
add_subdirectory(src)
add_subdirectory(desktop)
add_subdirectory(fastlane)
add_subdirectory(po)
enable_testing()
add_subdirectory(autotests)

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)
