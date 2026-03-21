if(NOT DEFINED COUNTER_STATE_FILE OR COUNTER_STATE_FILE STREQUAL "")
    message(FATAL_ERROR "COUNTER_STATE_FILE is required")
endif()

if(NOT DEFINED HEADER_FILE OR HEADER_FILE STREQUAL "")
    message(FATAL_ERROR "HEADER_FILE is required")
endif()

get_filename_component(_counter_dir "${COUNTER_STATE_FILE}" DIRECTORY)
get_filename_component(_header_dir "${HEADER_FILE}" DIRECTORY)
file(MAKE_DIRECTORY "${_counter_dir}")
file(MAKE_DIRECTORY "${_header_dir}")

set(_current_iteration 0)
if(EXISTS "${COUNTER_STATE_FILE}")
    file(READ "${COUNTER_STATE_FILE}" _stored_iteration_raw)
    string(STRIP "${_stored_iteration_raw}" _stored_iteration_raw)
    if(_stored_iteration_raw MATCHES "^[0-9]+$")
        math(EXPR _current_iteration "${_stored_iteration_raw}")
    endif()
endif()

math(EXPR _next_iteration "${_current_iteration} + 1")
set(_next_iteration_text "${_next_iteration}")
string(LENGTH "${_next_iteration_text}" _next_iteration_length)
while(_next_iteration_length LESS 4)
    set(_next_iteration_text "0${_next_iteration_text}")
    string(LENGTH "${_next_iteration_text}" _next_iteration_length)
endwhile()

file(WRITE "${COUNTER_STATE_FILE}" "${_next_iteration}\n")
file(WRITE "${HEADER_FILE}" "#pragma once\n\nnamespace ComicPileBuildIteration {\ninline constexpr int kValue = ${_next_iteration};\ninline constexpr char kText[] = \"${_next_iteration_text}\";\n}\n")

message(STATUS "Comic Pile build iteration ${_next_iteration_text}")
