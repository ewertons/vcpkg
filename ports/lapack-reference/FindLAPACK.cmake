# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

#[=======================================================================[.rst:
FindLAPACK
----------

Find Linear Algebra PACKage (LAPACK) library

This module finds an installed Fortran library that implements the
LAPACK linear-algebra interface (see http://www.netlib.org/lapack/).

The approach follows that taken for the ``autoconf`` macro file,
``acx_lapack.m4`` (distributed at
http://ac-archive.sourceforge.net/ac-archive/acx_lapack.html).

Input Variables
^^^^^^^^^^^^^^^

The following variables may be set to influence this module's behavior:

``BLA_STATIC``
  if ``ON`` use static linkage

``BLA_VENDOR``
  If set, checks only the specified vendor, if not set checks all the
  possibilities.  List of vendors valid in this module:

  * ``OpenBLAS``
  * ``FLAME``
  * ``Intel10_32`` (intel mkl v10 32 bit)
  * ``Intel10_64lp`` (intel mkl v10+ 64 bit, threaded code, lp64 model)
  * ``Intel10_64lp_seq`` (intel mkl v10+ 64 bit, sequential code, lp64 model)
  * ``Intel10_64ilp`` (intel mkl v10+ 64 bit, threaded code, ilp64 model)
  * ``Intel10_64ilp_seq`` (intel mkl v10+ 64 bit, sequential code, ilp64 model)
  * ``Intel10_64_dyn`` (intel mkl v10+ 64 bit, single dynamic library)
  * ``Intel`` (obsolete versions of mkl 32 and 64 bit)
  * ``ACML``
  * ``Apple``
  * ``NAS``
  * ``Arm``
  * ``Arm_mp``
  * ``Arm_ilp64``
  * ``Arm_ilp64_mp``
  * ``Generic``

``BLA_F95``
  if ``ON`` tries to find the BLAS95/LAPACK95 interfaces

Imported targets
^^^^^^^^^^^^^^^^

This module defines the following :prop_tgt:`IMPORTED` target:

``LAPACK::LAPACK``
  The libraries to use for LAPACK, if found.

Result Variables
^^^^^^^^^^^^^^^^

This module defines the following variables:

``LAPACK_FOUND``
  library implementing the LAPACK interface is found
``LAPACK_LINKER_FLAGS``
  uncached list of required linker flags (excluding ``-l`` and ``-L``).
``LAPACK_LIBRARIES``
  uncached list of libraries (using full path name) to link against
  to use LAPACK
``LAPACK95_LIBRARIES``
  uncached list of libraries (using full path name) to link against
  to use LAPACK95
``LAPACK95_FOUND``
  library implementing the LAPACK95 interface is found

.. note::

  C, CXX or Fortran must be enabled to detect a BLAS/LAPACK library.
  C or CXX must be enabled to use Intel Math Kernel Library (MKL).

  For example, to use Intel MKL libraries and/or Intel compiler:

  .. code-block:: cmake

    set(BLA_VENDOR Intel10_64lp)
    find_package(LAPACK)
#]=======================================================================]

enable_language(C)
# Check the language being used
if(NOT (CMAKE_C_COMPILER_LOADED OR CMAKE_CXX_COMPILER_LOADED OR CMAKE_Fortran_COMPILER_LOADED))
  if(LAPACK_FIND_REQUIRED)
    message(FATAL_ERROR "FindLAPACK requires Fortran, C, or C++ to be enabled.")
  else()
    message(STATUS "Looking for LAPACK... - NOT found (Unsupported languages)")
    return()
  endif()
endif()

if(CMAKE_Fortran_COMPILER_LOADED)
  include(${CMAKE_ROOT}/Modules/CheckFortranFunctionExists.cmake)
else()
  include(${CMAKE_ROOT}/Modules/CheckFunctionExists.cmake)
endif()
include(${CMAKE_ROOT}/Modules/CMakePushCheckState.cmake)

cmake_push_check_state()
set(CMAKE_REQUIRED_QUIET ${LAPACK_FIND_QUIETLY})

set(LAPACK_FOUND FALSE)
set(LAPACK95_FOUND FALSE)

# store original values for CMAKE_FIND_LIBRARY_SUFFIXES
set(_lapack_ORIG_CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES})
if (CMAKE_SYSTEM_NAME STREQUAL "Linux")
    list(APPEND CMAKE_FIND_LIBRARY_SUFFIXES .so.3gfs .so.3 .so.4 .so.5)
endif()

# TODO: move this stuff to a separate module

macro(CHECK_LAPACK_LIBRARIES LIBRARIES _prefix _name _flags _list _threadlibs _addlibdir _subdirs _blas)
  # This macro checks for the existence of the combination of fortran libraries
  # given by _list.  If the combination is found, this macro checks (using the
  # Check_Fortran_Function_Exists macro) whether can link against that library
  # combination using the name of a routine given by _name using the linker
  # flags given by _flags.  If the combination of libraries is found and passes
  # the link test, LIBRARIES is set to the list of complete library paths that
  # have been found.  Otherwise, LIBRARIES is set to FALSE.

  # N.B. _prefix is the prefix applied to the names of all cached variables that
  # are generated internally and marked advanced by this macro.
  # _addlibdir is a list of additional search paths. _subdirs is a list of path
  # suffixes to be used by find_library().

  set(_libraries_work TRUE)
  set(${LIBRARIES})
  set(_combined_name)

  set(_extaddlibdir "${_addlibdir}")
  if(WIN32)
    list(APPEND _extaddlibdir ENV LIB)
  elseif(APPLE)
    list(APPEND _extaddlibdir ENV DYLD_LIBRARY_PATH)
  else()
    list(APPEND _extaddlibdir ENV LD_LIBRARY_PATH)
  endif()
  list(APPEND _extaddlibdir "${CMAKE_C_IMPLICIT_LINK_DIRECTORIES}")

  foreach(_library ${_list})
    if(_library MATCHES "^-Wl,--(start|end)-group$")
      # Respect linker flags like --start/end-group (required by MKL)
      set(${LIBRARIES} ${${LIBRARIES}} "${_library}")
    else()
      set(_combined_name ${_combined_name}_${_library})
      if(_libraries_work)
        find_library(${_prefix}_${_library}_LIBRARY
          NAMES ${_library}
          PATHS ${_extaddlibdir}
          PATH_SUFFIXES ${_subdirs}
        )
        #message("DEBUG: find_library(${_library}) got ${${_prefix}_${_library}_LIBRARY}")
        mark_as_advanced(${_prefix}_${_library}_LIBRARY)
        set(${LIBRARIES} ${${LIBRARIES}} ${${_prefix}_${_library}_LIBRARY})
        set(_libraries_work ${${_prefix}_${_library}_LIBRARY})
      endif()
    endif()
  endforeach()

  if(_libraries_work)
    # Test this combination of libraries.
    set(CMAKE_REQUIRED_LIBRARIES ${_flags} ${${LIBRARIES}} ${_blas} ${_threadlibs})
    #message("DEBUG: CMAKE_REQUIRED_LIBRARIES = ${CMAKE_REQUIRED_LIBRARIES}")
    if(CMAKE_Fortran_COMPILER_LOADED)
      check_fortran_function_exists("${_name}" ${_prefix}${_combined_name}_WORKS)
    else()
      check_function_exists("${_name}_" ${_prefix}${_combined_name}_WORKS)
    endif()
    set(CMAKE_REQUIRED_LIBRARIES)
    set(_libraries_work ${${_prefix}${_combined_name}_WORKS})
  endif()

  if(_libraries_work)
    if("${_list}${_blas}" STREQUAL "")
      set(${LIBRARIES} "${LIBRARIES}-PLACEHOLDER-FOR-EMPTY-LIBRARIES")
    else()
      set(${LIBRARIES} ${${LIBRARIES}} ${_blas} ${_threadlibs})
    endif()
  else()
    set(${LIBRARIES} FALSE)
  endif()
  #message("DEBUG: ${LIBRARIES} = ${${LIBRARIES}}")
endmacro()

set(LAPACK_LINKER_FLAGS)
set(LAPACK_LIBRARIES)
set(LAPACK95_LIBRARIES)

include(CMakeFindDependencyMacro)
find_dependency(BLAS)

if(BLAS_FOUND)
  set(LAPACK_LINKER_FLAGS ${BLAS_LINKER_FLAGS})
  if(NOT $ENV{BLA_VENDOR} STREQUAL "")
    set(BLA_VENDOR $ENV{BLA_VENDOR})
  else()
    if(NOT BLA_VENDOR)
      set(BLA_VENDOR "All")
    endif()
  endif()

  # LAPACK in the Intel MKL 10+ library?
  if(BLA_VENDOR MATCHES "Intel" OR BLA_VENDOR STREQUAL "All")
    if(NOT LAPACK_LIBRARIES)
      if(CMAKE_C_COMPILER_LOADED OR CMAKE_CXX_COMPILER_LOADED)
        # System-specific settings
        if(NOT WIN32)
          set(LAPACK_mkl_LM "-lm")
          set(LAPACK_mkl_LDL "-ldl")
        endif()

        if(LAPACK_FIND_QUIETLY OR NOT LAPACK_FIND_REQUIRED)
          find_package(Threads)
        else()
          find_package(Threads REQUIRED)
        endif()

        if(BLA_VENDOR MATCHES "_64ilp")
          set(LAPACK_mkl_ILP_MODE "ilp64")
        else()
          set(LAPACK_mkl_ILP_MODE "lp64")
        endif()

        set(LAPACK_SEARCH_LIBS "")

        if(BLA_F95)
          set(LAPACK_mkl_SEARCH_SYMBOL "cheev_f95")
          set(_LIBRARIES LAPACK95_LIBRARIES)
          set(_BLAS_LIBRARIES ${BLAS95_LIBRARIES})

          # old
          list(APPEND LAPACK_SEARCH_LIBS
            "mkl_lapack95")
          # new >= 10.3
          list(APPEND LAPACK_SEARCH_LIBS
            "mkl_intel_c")
          list(APPEND LAPACK_SEARCH_LIBS
            "mkl_lapack95_${LAPACK_mkl_ILP_MODE}")
        else()
          set(LAPACK_mkl_SEARCH_SYMBOL "cheev")
          set(_LIBRARIES LAPACK_LIBRARIES)
          set(_BLAS_LIBRARIES ${BLAS_LIBRARIES})

          # old and new >= 10.3
          list(APPEND LAPACK_SEARCH_LIBS
            "mkl_lapack")
        endif()

        # MKL uses a multitude of partially platform-specific subdirectories:
        if(BLA_VENDOR STREQUAL "Intel10_32")
          set(LAPACK_mkl_ARCH_NAME "ia32")
        else()
          set(LAPACK_mkl_ARCH_NAME "intel64")
        endif()
        if(WIN32)
          set(LAPACK_mkl_OS_NAME "win")
        elseif(APPLE)
          set(LAPACK_mkl_OS_NAME "mac")
        else()
          set(LAPACK_mkl_OS_NAME "lin")
        endif()
        if(DEFINED ENV{MKLROOT})
          file(TO_CMAKE_PATH "$ENV{MKLROOT}" LAPACK_mkl_MKLROOT)
          # If MKLROOT points to the subdirectory 'mkl', use the parent directory instead
          # so we can better detect other relevant libraries in 'compiler' or 'tbb':
          get_filename_component(LAPACK_mkl_MKLROOT_LAST_DIR "${LAPACK_mkl_MKLROOT}" NAME)
          if(LAPACK_mkl_MKLROOT_LAST_DIR STREQUAL "mkl")
              get_filename_component(LAPACK_mkl_MKLROOT "${LAPACK_mkl_MKLROOT}" DIRECTORY)
          endif()
        endif()
        set(LAPACK_mkl_LIB_PATH_SUFFIXES
            "compiler/lib" "compiler/lib/${LAPACK_mkl_ARCH_NAME}_${LAPACK_mkl_OS_NAME}"
            "mkl/lib" "mkl/lib/${LAPACK_mkl_ARCH_NAME}_${LAPACK_mkl_OS_NAME}"
            "lib/${LAPACK_mkl_ARCH_NAME}_${LAPACK_mkl_OS_NAME}")

        # First try empty lapack libs
        if(NOT ${_LIBRARIES})
          check_lapack_libraries(
            ${_LIBRARIES}
            LAPACK
            ${LAPACK_mkl_SEARCH_SYMBOL}
            ""
            ""
            "${CMAKE_THREAD_LIBS_INIT};${LAPACK_mkl_LM};${LAPACK_mkl_LDL}"
            "${LAPACK_mkl_MKLROOT}"
            "${LAPACK_mkl_LIB_PATH_SUFFIXES}"
            "${_BLAS_LIBRARIES}"
          )
        endif()

        # Then try the search libs
        foreach(IT ${LAPACK_SEARCH_LIBS})
          string(REPLACE " " ";" SEARCH_LIBS ${IT})
          if(NOT ${_LIBRARIES})
            check_lapack_libraries(
              ${_LIBRARIES}
              LAPACK
              ${LAPACK_mkl_SEARCH_SYMBOL}
              ""
              "${SEARCH_LIBS}"
              "${CMAKE_THREAD_LIBS_INIT};${LAPACK_mkl_LM};${LAPACK_mkl_LDL}"
              "${LAPACK_mkl_MKLROOT}"
              "${LAPACK_mkl_LIB_PATH_SUFFIXES}"
              "${_BLAS_LIBRARIES}"
            )
          endif()
        endforeach()

        unset(LAPACK_mkl_ILP_MODE)
        unset(LAPACK_mkl_SEARCH_SYMBOL)
        unset(LAPACK_mkl_LM)
        unset(LAPACK_mkl_LDL)
        unset(LAPACK_mkl_MKLROOT)
        unset(LAPACK_mkl_ARCH_NAME)
        unset(LAPACK_mkl_OS_NAME)
        unset(LAPACK_mkl_LIB_PATH_SUFFIXES)
      endif()
    endif()
  endif()

  # gotoblas? (http://www.tacc.utexas.edu/tacc-projects/gotoblas2)
  if(BLA_VENDOR STREQUAL "Goto" OR BLA_VENDOR STREQUAL "All")
    if(NOT LAPACK_LIBRARIES)
      check_lapack_libraries(
        LAPACK_LIBRARIES
        LAPACK
        cheev
        ""
        "goto2"
        ""
        ""
        ""
        "${BLAS_LIBRARIES}"
      )
    endif()
  endif()

  # OpenBLAS? (http://www.openblas.net)
  if(BLA_VENDOR STREQUAL "OpenBLAS" OR BLA_VENDOR STREQUAL "All")
    if(NOT LAPACK_LIBRARIES)
      check_lapack_libraries(
        LAPACK_LIBRARIES
        LAPACK
        cheev
        ""
        "openblas"
        ""
        ""
        ""
        "${BLAS_LIBRARIES}"
      )
    endif()
  endif()

  # ArmPL? (https://developer.arm.com/tools-and-software/server-and-hpc/compile/arm-compiler-for-linux/arm-performance-libraries)
  if(BLA_VENDOR MATCHES "Arm" OR BLA_VENDOR STREQUAL "All")

    # Check for 64bit Integer support
    if(BLA_VENDOR MATCHES "_ilp64")
      set(LAPACK_armpl_LIB "armpl_ilp64")
    else()
      set(LAPACK_armpl_LIB "armpl_lp64")
    endif()

    # Check for OpenMP support, VIA BLA_VENDOR of Arm_mp or Arm_ipl64_mp
    if(BLA_VENDOR MATCHES "_mp")
     set(LAPACK_armpl_LIB "${LAPACK_armpl_LIB}_mp")
    endif()

    if(NOT LAPACK_LIBRARIES)
      check_lapack_libraries(
        LAPACK_LIBRARIES
        LAPACK
        cheev
        ""
        "${LAPACK_armpl_LIB}"
        ""
        ""
        ""
        "${BLAS_LIBRARIES}"
      )
    endif()
  endif()

  # FLAME's blis library? (https://github.com/flame/blis)
  if(BLA_VENDOR STREQUAL "FLAME" OR BLA_VENDOR STREQUAL "All")
    if(NOT LAPACK_LIBRARIES)
      check_lapack_libraries(
        LAPACK_LIBRARIES
        LAPACK
        cheev
        ""
        "flame"
        ""
        ""
        ""
        "${BLAS_LIBRARIES}"
      )
    endif()
  endif()

  # BLAS in acml library?
  if(BLA_VENDOR MATCHES "ACML" OR BLA_VENDOR STREQUAL "All")
    if(BLAS_LIBRARIES MATCHES ".+acml.+")
      set(LAPACK_LIBRARIES ${BLAS_LIBRARIES})
    endif()
  endif()

  # Apple LAPACK library?
  if(BLA_VENDOR STREQUAL "Apple" OR BLA_VENDOR STREQUAL "All")
    if(NOT LAPACK_LIBRARIES)
      check_lapack_libraries(
        LAPACK_LIBRARIES
        LAPACK
        cheev
        ""
        "Accelerate"
        ""
        ""
        ""
        "${BLAS_LIBRARIES}"
      )
    endif()
  endif()

  # Apple NAS (vecLib) library?
  if(BLA_VENDOR STREQUAL "NAS" OR BLA_VENDOR STREQUAL "All")
    if(NOT LAPACK_LIBRARIES)
      check_lapack_libraries(
        LAPACK_LIBRARIES
        LAPACK
        cheev
        ""
        "vecLib"
        ""
        ""
        ""
        "${BLAS_LIBRARIES}"
      )
    endif()
  endif()

  # Generic LAPACK library?
  if(BLA_VENDOR STREQUAL "Generic" OR
      BLA_VENDOR STREQUAL "ATLAS" OR
      BLA_VENDOR STREQUAL "All")
    if(NOT LAPACK_LIBRARIES)
      check_lapack_libraries(
        LAPACK_LIBRARIES
        LAPACK
        cheev
        ""
        "lapack"
        ""
        ""
        ""
        "${BLAS_LIBRARIES}"
      )
    endif()
    if(NOT LAPACK_LIBRARIES)
      check_lapack_libraries(
        LAPACK_LIBRARIES
        LAPACK
        cheev
        ""
        "lapack;m;gfortran"
        ""
        ""
        ""
        "${BLAS_LIBRARIES}"
      )
    endif()
    if(NOT LAPACK_LIBRARIES)
      check_lapack_libraries(
        LAPACK_LIBRARIES
        LAPACK
        cheev
        ""
        "lapack;m;gfortran;quadmath"
        ""
        ""
        ""
        "${BLAS_LIBRARIES}"
      )
    endif()
  endif()
else()
  message(STATUS "LAPACK requires BLAS")
endif()

if(BLA_F95)
  if(LAPACK95_LIBRARIES)
    set(LAPACK95_FOUND TRUE)
  else()
    set(LAPACK95_FOUND FALSE)
  endif()
  if(NOT LAPACK_FIND_QUIETLY)
    if(LAPACK95_FOUND)
      message(STATUS "A library with LAPACK95 API found.")
    else()
      if(LAPACK_FIND_REQUIRED)
        message(FATAL_ERROR
          "A required library with LAPACK95 API not found. Please specify library location."
        )
      else()
        message(STATUS
          "A library with LAPACK95 API not found. Please specify library location."
        )
      endif()
    endif()
  endif()
  set(LAPACK_FOUND "${LAPACK95_FOUND}")
  set(LAPACK_LIBRARIES "${LAPACK95_LIBRARIES}")
else()
  if(LAPACK_LIBRARIES)
    set(LAPACK_FOUND TRUE)
  else()
    set(LAPACK_FOUND FALSE)
  endif()

  if(NOT LAPACK_FIND_QUIETLY)
    if(LAPACK_FOUND)
      message(STATUS "A library with LAPACK API found.")
    else()
      if(LAPACK_FIND_REQUIRED)
        message(FATAL_ERROR
          "A required library with LAPACK API not found. Please specify library location."
        )
      else()
        message(STATUS
          "A library with LAPACK API not found. Please specify library location."
        )
      endif()
    endif()
  endif()
endif()

# On compilers that implicitly link LAPACK (such as ftn, cc, and CC on Cray HPC machines)
# we used a placeholder for empty LAPACK_LIBRARIES to get through our logic above.
if(LAPACK_LIBRARIES STREQUAL "LAPACK_LIBRARIES-PLACEHOLDER-FOR-EMPTY-LIBRARIES")
  set(LAPACK_LIBRARIES "")
endif()

if(NOT TARGET LAPACK::LAPACK)
  add_library(LAPACK::LAPACK INTERFACE IMPORTED)
  set(_lapack_libs "${LAPACK_LIBRARIES}")
  if(_lapack_libs AND TARGET BLAS::BLAS)
    # remove the ${BLAS_LIBRARIES} from the interface and replace it
    # with the BLAS::BLAS target
    list(REMOVE_ITEM _lapack_libs "${BLAS_LIBRARIES}")
  endif()

  if(_lapack_libs)
    set_target_properties(LAPACK::LAPACK PROPERTIES
      INTERFACE_LINK_LIBRARIES "${_lapack_libs}"
    )
  endif()
  unset(_lapack_libs)
endif()

cmake_pop_check_state()
# restore original values for CMAKE_FIND_LIBRARY_SUFFIXES
set(CMAKE_FIND_LIBRARY_SUFFIXES ${_lapack_ORIG_CMAKE_FIND_LIBRARY_SUFFIXES})
