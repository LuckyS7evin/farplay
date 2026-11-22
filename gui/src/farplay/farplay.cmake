# Farplay — sources et réglages de build propres au fork.
# Inclus depuis gui/CMakeLists.txt après la création de la cible `chiaki`.

target_sources(chiaki PRIVATE
	include/farplay/farplaystats.h
	src/farplay/farplaystats.cpp
	include/farplay/farplayimage.h
	src/farplay/farplayimage.cpp
	res/farplay/farplay.qrc
)

if(NOT FARPLAY_GIT_HASH)
	find_package(Git QUIET)
	if(GIT_FOUND)
		execute_process(COMMAND ${GIT_EXECUTABLE} rev-parse --short=8 HEAD
			WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
			OUTPUT_VARIABLE FARPLAY_GIT_HASH
			OUTPUT_STRIP_TRAILING_WHITESPACE
			ERROR_QUIET)
	endif()
	if(NOT FARPLAY_GIT_HASH)
		set(FARPLAY_GIT_HASH "dev")
	endif()
endif()
message(STATUS "Farplay build: ${FARPLAY_GIT_HASH}")
target_compile_definitions(chiaki PRIVATE FARPLAY_GIT_HASH="${FARPLAY_GIT_HASH}")

if(WIN32)
	set_target_properties(chiaki PROPERTIES OUTPUT_NAME farplay)
endif()
