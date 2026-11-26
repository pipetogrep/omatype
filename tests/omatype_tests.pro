QT += core gui qml quick quickcontrols2 dbus network testlib

CONFIG += c++17 release testcase
TARGET = omatype_tests
DEFINES += OMATYPE_VERSION=\\\"0.2.0-test\\\"
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += \
    ../src/backend.h \
    ../src/catalog.h \
    ../src/fontfile.h \
    ../src/library.h \
    ../src/cli.h \
    ../src/filepicker.h \
    ../src/theme.h

SOURCES += \
    omatype_tests.cpp \
    ../src/backend.cpp \
    ../src/backendstage.cpp \
    ../src/backendlibrary.cpp \
    ../src/backendexport.cpp \
    ../src/catalog.cpp \
    ../src/fontfile.cpp \
    ../src/library.cpp \
    ../src/cli.cpp \
    ../src/filepicker.cpp \
    ../src/theme.cpp

RESOURCES += ../src/resources.qrc
