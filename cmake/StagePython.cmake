# Deliberately do not deploy python.exe/pythonw.exe, pip, or development tools.
set(_runtime "${RECLIP_PYTHON_DESTINATION}/runtime/python")
file(MAKE_DIRECTORY "${_runtime}")
file(COPY "${RECLIP_PYTHON_ROOT}/Lib" "${RECLIP_PYTHON_ROOT}/DLLs"
    DESTINATION "${_runtime}"
    PATTERN "__pycache__" EXCLUDE
    PATTERN "*.pyc" EXCLUDE
    PATTERN "*.exe" EXCLUDE
    PATTERN "pip" EXCLUDE
    PATTERN "ensurepip" EXCLUDE
)
file(GLOB _runtime_dlls "${RECLIP_PYTHON_ROOT}/*.dll")
file(COPY ${_runtime_dlls} DESTINATION "${RECLIP_PYTHON_DESTINATION}")
file(COPY "${RECLIP_PYTHON_MANIFEST}" DESTINATION "${_runtime}")
if(EXISTS "${RECLIP_PYTHON_ROOT}/LICENSE.txt")
    file(COPY "${RECLIP_PYTHON_ROOT}/LICENSE.txt" DESTINATION "${_runtime}")
endif()
