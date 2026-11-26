# Marketing screenshot capture; see bin/screenshots. Not part of the test run.
QT += core gui qml quick quickcontrols2 dbus network testlib

CONFIG += c++17 release
TARGET = omatype_screenshots
DEFINES += OMATYPE_VERSION=\\\"0.2.0\\\"
TEMPLATE = app

INCLUDEPATH += ../../src

HEADERS += \
    ../../src/backend.h \
    ../../src/catalog.h \
    ../../src/fontfile.h \
    ../../src/library.h \
    ../../src/cli.h \
    ../../src/filepicker.h \
    ../../src/theme.h

SOURCES += \
    screenshots.cpp \
    ../../src/backend.cpp \
    ../../src/backendstage.cpp \
    ../../src/backendlibrary.cpp \
    ../../src/backendexport.cpp \
    ../../src/catalog.cpp \
    ../../src/fontfile.cpp \
    ../../src/library.cpp \
    ../../src/cli.cpp \
    ../../src/filepicker.cpp \
    ../../src/theme.cpp

RESOURCES += ../../src/resources.qrc
