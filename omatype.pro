QT += core gui qml quick quickcontrols2 dbus network

CONFIG += c++17 release
TARGET = omatype
# Keep in step with pkgver in pkgbuild/PKGBUILD.
VERSION = 0.2.0
DEFINES += OMATYPE_VERSION=\\\"$$VERSION\\\"
TEMPLATE = app

INCLUDEPATH += src

HEADERS += \
    src/backend.h \
    src/catalog.h \
    src/fontfile.h \
    src/library.h \
    src/cli.h \
    src/filepicker.h \
    src/theme.h

SOURCES += \
    src/main.cpp \
    src/backend.cpp \
    src/backendstage.cpp \
    src/backendlibrary.cpp \
    src/backendexport.cpp \
    src/catalog.cpp \
    src/fontfile.cpp \
    src/library.cpp \
    src/cli.cpp \
    src/filepicker.cpp \
    src/theme.cpp

RESOURCES += src/resources.qrc

