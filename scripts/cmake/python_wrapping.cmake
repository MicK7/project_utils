set(SITE_PACKAGES_OUTPUT_DIRECTORY "${CMAKE_INSTALL_PREFIX}/lib/python${Python_VERSION_MAJOR}.${Python_VERSION_MINOR}/site-packages/")


function(compile_install_pybind_modules project_name)
  file(GLOB_RECURSE pybind_files CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${project_name}/*.pybind.cpp")
  foreach(pybind_file ${pybind_files})
    # Relative path
    get_filename_component(pybind_dir ${pybind_file} DIRECTORY)
    file(RELATIVE_PATH pybind_dir_rel ${CMAKE_CURRENT_SOURCE_DIR} ${pybind_dir})
     
    # Create target
    get_filename_component(mod_name ${pybind_file} NAME_WE) # If same name : problem
    pybind11_add_module(${mod_name} ${pybind_file})
    target_include_directories(${mod_name} PUBLIC ${Mpi4Py_INCLUDE_DIR})
    target_link_libraries(${mod_name} PUBLIC ${project_name}::${project_name})
    set_target_properties(${mod_name} PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${pybind_dir_rel}")

    # Install target
    install(TARGETS ${mod_name}
            LIBRARY DESTINATION ${SITE_PACKAGES_OUTPUT_DIRECTORY}/${pybind_dir_rel})
  endforeach()
endfunction()


function(compile_install_cython_modules project_name)
  include(UseCython)
  file(GLOB_RECURSE pyx_files CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${project_name}/*.pyx")
  foreach(pyx_file ${pyx_files})
    # Relative path
    get_filename_component(pyx_dir ${pyx_file} DIRECTORY )
    file(RELATIVE_PATH pyx_dir_rel ${CMAKE_CURRENT_SOURCE_DIR} ${pyx_dir})

    # Create target
    get_filename_component(mod_name ${pybind_file} NAME_WE) # If same name : problem
    cython_add_one_file_module(${mod_name} ${pyx_file})
    target_link_libraries(${mod_name} PUBLIC ${project_name}::${project_name})
    set_target_properties(${mod_name} PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${pyx_dir_rel}")
    set_source_files_properties(${pyx_file} PROPERTIES CYTHON_IS_CXX TRUE)

    # Install target
    install(TARGETS ${mod_name}
            LIBRARY DESTINATION ${SITE_PACKAGES_OUTPUT_DIRECTORY}/${pyx_dir_rel})
  endforeach()
endfunction()


function(compile_install_python_modules project_name)
  set(python_copied_modules_${project_name})

  file(GLOB_RECURSE py_files CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${project_name}/*.py")
  foreach (py_file ${py_files})
    file(RELATIVE_PATH py_file_rel  ${CMAKE_CURRENT_SOURCE_DIR} ${py_file})
    set(output_python_file "${CMAKE_CURRENT_BINARY_DIR}/${py_file_rel}")

    # When using build/ folder in development mode: tell CMake to copy py files to build/ if they changed
    # TODO: current limitation: if a file is moved in the CMAKE_CURRENT_SOURCE_DIR, its old location will stay in CMAKE_CURRENT_BINARY_DIR
    add_custom_command(OUTPUT  "${output_python_file}"
                       DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${py_file_rel}"
                       COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                       "${CMAKE_CURRENT_SOURCE_DIR}/${py_file_rel}"
                       "${output_python_file}"
                       COMMENT "Copying ${py_file_rel} to the binary directory")
    list(APPEND python_copied_modules_${project_name} "${output_python_file}")

    # Install
    get_filename_component(py_dir_rel "${py_file_rel}" DIRECTORY)
    install(FILES       "${py_file_rel}"
            DESTINATION "${SITE_PACKAGES_OUTPUT_DIRECTORY}/${py_dir_rel}"
            COMPONENT   "python")
  endforeach ()

  add_custom_target(project_python_copy_${project_name} ALL DEPENDS ${python_copied_modules_${project_name}})
endfunction()
