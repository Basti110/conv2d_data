cmake_minimum_required(VERSION 3.8)
project(Conv_2D)

set(CMAKE_CXX_STANDARD 11)

SET(NATIVE_LIB_SRCS $ENV{PROJDIR}/lib/isg/tmicro_chess_opns.c $ENV{PROJDIR}/lib/isg/tmicro_chess_types.c $ENV{PROJDIR}/lib/tmicro_native.c)
SET_SOURCE_FILES_PROPERTIES( ${NATIVE_LIB_SRCS} PROPERTIES LANGUAGE CXX )
add_library(TMICRO_NATIVE ${NATIVE_LIB_SRCS})

set(SOURCE_FILES ../benchmark_conv2d.c)
SET_SOURCE_FILES_PROPERTIES( ${SOURCE_FILES} PROPERTIES LANGUAGE CXX )
include_directories("../" "$ENV{PROJDIR}/lib" "$ENV{PROJDIR}/core_libs" "$ENV{CHESSDIR}")
# Note: Add -DPDB_DEBUG to enable debug-output for nML primitives as follows:
add_definitions(-include tmicro_native.h -D__tct_release__=1603 -DPDG_DEBUG -DVERIFICATION_MODE_ON -DFNAME_DATA="../data/conv2d.dat" -include data/conv2d_config.h)
#add_definitions(-include tmicro_native.h -D__tct_release__=1603)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
add_executable(Conv_2D ${SOURCE_FILES})
target_link_libraries(Conv_2D TMICRO_NATIVE)