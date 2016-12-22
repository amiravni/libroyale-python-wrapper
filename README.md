Attempt to wrap libroyale with Python.

  - Attempt 1 SWIG    
    Turned out SWIG does not support `unique_ptr`

  - Attempt 2 ctype    
    Made it to run sample3. Turned out libroyale has C API. Will try with C API + SWIG

  - Attempt 3 SWIG + C API    
    Wrap C API with SWIG and build OO