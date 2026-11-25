# Farplay — sources et réglages de build propres au fork.
# Inclus depuis gui/CMakeLists.txt après la création de la cible `chiaki`.

target_sources(chiaki PRIVATE
	include/farplay/farplaystats.h
	src/farplay/farplaystats.cpp
	include/farplay/farplayimage.h
	src/farplay/farplayimage.cpp
	include/farplay/fgengine.h
	src/farplay/fgengine.cpp
	include/farplay/farplayframegen.h
	src/farplay/farplayframegen.cpp
	include/farplay/fsrframegen.h
	src/farplay/fsrframegen.cpp
	res/farplay/farplay.qrc
	res/farplay/assets.qrc
)

# En-têtes (MIT) du FidelityFX SDK 2.4 d'AMD : frame gen FSR chargée à l'exécution.
target_include_directories(chiaki PRIVATE
	${CMAKE_CURRENT_SOURCE_DIR}/../third-party/fidelityfx-sdk/Kits/FidelityFX/api/include
	${CMAKE_CURRENT_SOURCE_DIR}/../third-party/fidelityfx-sdk/Kits/FidelityFX/framegeneration/include)

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
