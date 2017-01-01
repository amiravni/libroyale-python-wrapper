%{
#define SWIG_FILE_WITH_INIT
%}

%module custom_api
%include typemaps.i
%include numpy.i

%init %{
if (!PyEval_ThreadsInitialized()) {
  PyEval_InitThreads();
}

import_array();
%}

%{
#define ROYALE_NEW_API_2_2_0
#define ROYALE_FINAL_API_2_2_0

#include<CameraDeviceCAPI.h>
#include<CameraManagerCAPI.h>
%}

/// Helper functions for converting Python <-> C
%{
/// Convert a array of string into Python list of string
PyObject *to_list_of_strings(char **strings, uint32_t n_items) {
  PyObject* ret = PyList_New(n_items);
  for (size_t i = 0; i < n_items; i++) {
    PyList_SetItem(ret, i, PyString_FromString(strings[i]));
  }
  return ret;
};
/// Convert royale_pair_string_string into Python dict
PyObject *to_dict(royale_pair_string_string *pairs, uint32_t n_pairs) {
  PyObject *ret = PyDict_New();
  for(uint32_t i = 0; i < n_pairs; i++) {
    PyDict_SetItemString(ret, pairs[i].first, PyString_FromString(pairs[i].second));
  }
  return ret;
};
/// Set Python error message from royale error status
void set_error_message(const royale_camera_status status, const char *message, PyObject *error_type=PyExc_BaseException) {
  char *error_string = royale_status_get_error_string(status);
  PyErr_Format(error_type, "%s; %s", message, error_string);
  royale_free_string (error_string);
};
%}

%inline %{
class CameraManager {
  royale_cam_manager_hnd handle_;
public:
  CameraManager()
    : handle_(ROYALE_NO_INSTANCE_CREATED)
  {};
  ~CameraManager() {
    if (handle_ != ROYALE_NO_INSTANCE_CREATED) {
      royale_camera_manager_destroy(handle_);
    }
  };
  PyObject *initialize() {
    handle_ = royale_camera_manager_create();
    if (handle_ == ROYALE_NO_INSTANCE_CREATED) {
	PyErr_Format(PyExc_RuntimeError, "Failed to create camera manager.");
	return NULL;
    } else {
      Py_RETURN_NONE;
    }
  };
  PyObject *get_connected_cameras() const {
    uint32_t nr_cameras;
    char ** cameras = royale_camera_manager_get_connected_cameras(handle_, &nr_cameras);

    PyObject* ret = to_list_of_strings(cameras, nr_cameras);
    royale_free_string_array(cameras, nr_cameras);
    return ret;
  };
  PyObject *create_camera_device(PyObject *device_id) {
    if (!PyString_Check(device_id)) {
      PyErr_SetString(PyExc_TypeError, "Expecting a string value.");
      return NULL;
    }
    royale_camera_handle cam_handle = royale_camera_manager_create_camera(handle_, PyString_AsString(device_id));
    if (cam_handle == ROYALE_NO_INSTANCE_CREATED) {
      PyErr_SetString(PyExc_RuntimeError, "Failed to create camera object.");
      return NULL;
    } else {
      printf("Created camera handle: %llu\n", cam_handle);
      return PyLong_FromUnsignedLongLong(cam_handle);
    }
  };
};
////////////////////////////////////////////////////////////////////////////////
template <typename T>
struct ImageBuffer {
  T *data;
  uint16_t width;
  uint16_t height;

  ImageBuffer()
    : data(NULL)
    , width(0)
    , height(0)
  {};
  ~ImageBuffer() {
    if (data) {
      deallocate();
    }
  };
  void deallocate() {
    printf("Deallocating memory.\n");
    delete[] data;
    data = NULL;
    width = height = 0;
  };
  void allocate(const uint16_t width, const uint16_t height) {
    uint32_t n_pixels = width * height;
    printf("Allocating %d pixels (W:%d, H:%d).\n", n_pixels, width, height);
    data = new T[n_pixels];
    this->width = width; this->height = height;
  };
};
////////////////////////////////////////////////////////////////////////////////
// Callbacks
PyObject *G_PYTHON_DATA_CALLBACK = NULL;
ImageBuffer<float> G_DEPTH_IMAGE_BUFFER;
ImageBuffer<uint16_t> G_GRAY_IMAGE_BUFFER;

template<typename T>
PyObject *convert_buffer_to_numpy_array(const ImageBuffer<T> &image, const NPY_TYPES type) {
  npy_intp dims[2] = {image.height, image.width};
  return PyArray_SimpleNewFromData(2, dims, type, image.data);
}

void call_python_callback(PyObject *depth_array, PyObject *gray_array, PyObject *callback) {
  PyObject *args = PyTuple_Pack(2, depth_array, gray_array);
  PyObject *ret = PyObject_Call(callback, args, NULL);
  Py_DECREF(ret);
  Py_DECREF(args);
}

void parse_images(royale_depth_data *info) {
  for (uint32_t i=0; i < info->nr_points; ++i) {
    G_DEPTH_IMAGE_BUFFER.data[i] = info->points[i].z;
    G_GRAY_IMAGE_BUFFER.data[i] = info->points[i].gray_value;
  }
  if (G_PYTHON_DATA_CALLBACK) {
    PyGILState_STATE lock = PyGILState_Ensure();
    PyObject *depth = convert_buffer_to_numpy_array(G_DEPTH_IMAGE_BUFFER, NPY_FLOAT);
    PyObject *gray = convert_buffer_to_numpy_array(G_GRAY_IMAGE_BUFFER, NPY_UINT16);
    call_python_callback(depth, gray, G_PYTHON_DATA_CALLBACK);
    PyGILState_Release(lock);
  }
};
////////////////////////////////////////////////////////////////////////////////
class CameraDevice {
  royale_camera_handle handle_;
public:
  CameraDevice(PyObject *handle)
    :handle_(PyLong_AsUnsignedLongLong(handle))
  {};
  ~CameraDevice() {
    if (handle_) {
      destroy();
    }
  };
  PyObject *initialize() const {
    printf("Initializing camera device: %llu.\n", handle_);
    royale_camera_status status = royale_camera_device_initialize(handle_);
    if (ROYALE_STATUS_SUCCESS == status) {
      Py_RETURN_NONE;
    } else {
      set_error_message(status, "Failed to initialize camera device", PyExc_RuntimeError);
      return NULL;
    }
  };
  PyObject *destroy() {
    printf("Destroying camera device: %llu.\n", handle_);
    royale_camera_device_destroy(handle_);
    handle_ = 0;
    Py_RETURN_NONE;
  }
  PyObject *getId() const {
    printf("Fetching camera device ID: %llu.\n", handle_);
    char *id;
    royale_camera_status status = royale_camera_device_get_id(handle_, &id);

    if (ROYALE_STATUS_SUCCESS == status) {
      PyObject *ret = PyString_FromString(id);
      royale_free_string(id);
      return ret;
    } else {
      PyErr_SetString(PyExc_RuntimeError, "Failed to get camera ID.");
      return NULL;
    }
  };
  PyObject *get_camera_name() const {
    printf("Fetching camera name: %llu.\n", handle_);
    char *name;
    royale_camera_status status = royale_camera_device_get_camera_name(handle_, &name);
    if (ROYALE_STATUS_SUCCESS == status) {
      PyObject *ret = PyString_FromString(name);
      royale_free_string(name);
      return ret;
    } else {
      PyErr_SetString(PyExc_RuntimeError, "Failed to get camera name.");
      return NULL;
    }
  };
  PyObject *get_camera_info() const {
    printf("Fetching camera info from device: %llu.\n", handle_);
    uint32_t nr_info_entries;
    royale_pair_string_string *info;
    royale_camera_status status = royale_camera_device_get_camera_info(handle_, &info, &nr_info_entries);
    printf("Fetched %u info.\n", nr_info_entries);
    if (ROYALE_STATUS_SUCCESS == status) {
      PyObject *ret = to_dict(info, nr_info_entries);
      royale_free_pair_string_string_array(&info, nr_info_entries);
      return ret;
    } else {
      PyErr_SetString(PyExc_RuntimeError, "Failed to get camera info.");
      return NULL;
    }
  };
  PyObject *set_use_case(PyObject *use_case_name) const {
    printf("Setting use case.\n");
    if (!PyString_Check(use_case_name)) {
      PyErr_SetString(PyExc_TypeError, "Expecting a str");
      return NULL;
    }
    royale_camera_status status = royale_camera_device_set_use_case(handle_, PyString_AsString(use_case_name));
    if (ROYALE_STATUS_SUCCESS == status) {
      Py_RETURN_NONE;
    } else {
      set_error_message(status, "Failed to set use case", PyExc_RuntimeError);
      return NULL;
    }
  };
  PyObject *get_use_cases() const {
    printf("Getting use cases.\n");
    char **use_cases;
    uint32_t nr_use_cases;
    royale_camera_status status = royale_camera_device_get_use_cases(handle_, &use_cases, &nr_use_cases);

    if (ROYALE_STATUS_SUCCESS == status) {
      PyObject *ret = to_list_of_strings(use_cases, nr_use_cases);
      royale_free_string_array(use_cases, nr_use_cases);
      return ret;
    } else {
      set_error_message(status, "Failed to set use case", PyExc_RuntimeError);
      return NULL;
    }
  };
  PyObject *get_current_use_case() const {
    printf("Getting the current use case.\n");
    char *use_case_name;
    royale_camera_status status = royale_camera_device_get_current_use_case(handle_, &use_case_name);
    if (ROYALE_STATUS_SUCCESS == status) {
      PyObject *ret = PyString_FromString(use_case_name);
      royale_free_string(use_case_name);
      return ret;
    } else {
      set_error_message(status, "Failed to set use case", PyExc_RuntimeError);
      return NULL;
    }
  };
  PyObject *set_exposure_time(PyObject *exposure_time) const {
    if (!PyInt_Check(exposure_time)) {
      PyErr_SetString(PyExc_TypeError, "exposure_time must be integer");
      return NULL;
    }
    printf("Setting exposure time.\n");
    royale_camera_status status = royale_camera_device_set_exposure_time(handle_, PyInt_AsUnsignedLongLongMask(exposure_time));

    if (ROYALE_STATUS_SUCCESS == status) {
      Py_RETURN_NONE;
    } else {
      set_error_message(status, "Failed to set exporuse time", PyExc_RuntimeError);
      return NULL;
    }
  };
  PyObject *set_exposure_mode(PyObject *exposure_mode) const {
    if (!PyString_Check(exposure_mode)) {
      PyErr_SetString(PyExc_TypeError, "exposure_mode must be string");
      return NULL;
    }
    char* mode_str = PyString_AsString(exposure_mode);
    royale_exposure_mode mode;

    if (0 == strcmp(mode_str, "MANUAL")) {
      mode = ROYALE_EXPOSURE_MANUAL;
    } else if (0 == strcmp(mode_str, "AUTOMATIC")) {
      mode = ROYALE_EXPOSURE_AUTOMATIC;
    } else {
      PyErr_SetString(PyExc_ValueError, "exposure_mode must be either \"MANUAL\" or \"AUTOMATIC\"");
      return NULL;
    }
    printf("Setting exposure time.\n");
    royale_camera_status status = royale_camera_device_set_exposure_time(handle_, mode);
    if (ROYALE_STATUS_SUCCESS == status) {
      Py_RETURN_NONE;
    } else {
      set_error_message(status, "Failed to set exporuse time", PyExc_RuntimeError);
      return NULL;
    }
  };
  PyObject *get_exposure_limits() {
    uint32_t lower_limit, upper_limit;
    royale_camera_status status = royale_camera_device_get_exposure_limits(handle_, &lower_limit, &upper_limit);

    if (ROYALE_STATUS_SUCCESS == status) {
      PyObject *ret = PyTuple_New(2);
      PyTuple_SetItem(ret, 0, PyInt_FromSize_t(lower_limit));
      PyTuple_SetItem(ret, 1, PyInt_FromSize_t(upper_limit));
      return ret;
    } else {
      set_error_message(status, "Failed to get exposure limits", PyExc_RuntimeError);
      return NULL;
    }
  };
  PyObject *start_capture() {
    printf("Starting capture.\n");
    royale_camera_status status = royale_camera_device_start_capture(handle_);

    if (ROYALE_STATUS_SUCCESS == status) {
      Py_RETURN_NONE;
    } else {
      set_error_message(status, "Failed to start capture", PyExc_RuntimeError);
      return NULL;
    }
  };
  PyObject *stop_capture() {
    printf("Stopping capture.\n");
    royale_camera_status status = royale_camera_device_stop_capture(handle_);
    if (ROYALE_STATUS_SUCCESS == status) {
      Py_RETURN_NONE;
    } else {
      set_error_message(status, "Failed to stop capture", PyExc_RuntimeError);
      return NULL;
    }
  };
  PyObject *register_data_listener(PyObject *callable=Py_None) {
    printf("Registering depth image listener.\n");
    if (callable != Py_None && !PyCallable_Check(callable)) {
      PyErr_SetString(PyExc_TypeError, "Argument must be None or callable object.");
      return NULL;
    }

    // Currently picoflexx supports one resolution 224x171.
    // If it supports something other we need to change it here dynamically.
    uint16_t width = 224, height = 171;
    G_DEPTH_IMAGE_BUFFER.allocate(width, height);
    G_GRAY_IMAGE_BUFFER.allocate(width, height);

    // DO NOT CHANGE THE ORDER OF THE FOLLOWING THREE LINES, OTHERWISE THE CALL TO C API HANGS UP
    // ----->
    royale_camera_status status = royale_camera_device_register_data_listener(handle_, &parse_images);
    if (callable != Py_None) {
      G_PYTHON_DATA_CALLBACK = callable;
      Py_XINCREF(callable);
    }
    // <-----

    if (ROYALE_STATUS_SUCCESS == status) {
      Py_RETURN_NONE;
    } else {
      set_error_message(status, "Failed to register depth image listener", PyExc_RuntimeError);
      return NULL;
    }
  };
  PyObject *unregister_data_listener() {
    printf("Unregistering depth image listener.\n");
    if (!is_capturing()) {
      PyErr_SetString(PyExc_RuntimeError,
		      "Camera must be capturing data to unregister callback, otherwise the underlying C API call hangs.");
      return NULL;
    }
    // DO NOT CHANGE THE ORDER OF THE FOLLOWING THREE LINES, OTHERWISE THE CALL TO C API HANGS UP
    // ----->
    if (G_PYTHON_DATA_CALLBACK != Py_None) {
      Py_XDECREF(G_PYTHON_DATA_CALLBACK);
      G_PYTHON_DATA_CALLBACK = NULL;
    }
    royale_camera_status status = royale_camera_device_unregister_data_listener(handle_);
    // <-----

    G_DEPTH_IMAGE_BUFFER.deallocate();
    G_GRAY_IMAGE_BUFFER.deallocate();

    if (ROYALE_STATUS_SUCCESS == status) {
      Py_RETURN_NONE;
    } else {
      set_error_message(status, "Failed to unregister data listner", PyExc_RuntimeError);
      return NULL;
    }
  };
  PyObject *is_capturing() {
    bool is_capturing;
    royale_camera_status status = royale_camera_device_is_capturing(handle_, &is_capturing);

    if (ROYALE_STATUS_SUCCESS == status) {
      return PyBool_FromLong(is_capturing);
    } else {
      set_error_message(status, "Failed to check capturing status", PyExc_RuntimeError);
      return NULL;
    }
  }
  // *TODO
  // register_depth_image_listener
  // unregister_depth_image_listener
  // register_ir_image_listener
  // unregister_ir_image_listener
  // register_spc_listener
  // unregister_spc_listener
  // register_event_listener
  // unregister_event_listener
  // get_max_sensor_height
  // get_max_sensor_width
  // get_lens_parameters
  // is_connected
  // is_calibrated
  // get_access_level
  // start_recording
  // stop_recording
  // register_record_stop_listener
  // unregister_record_stop_listener
  // register_exposure_listener
  // unregister_exposure_listener
  // set_frame_rate
  // get_frame_rate
  // get_max_frame_rate
};
%}
