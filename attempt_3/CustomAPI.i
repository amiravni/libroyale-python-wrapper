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
    }
    Py_RETURN_NONE;
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
      }
    return PyInt_FromSize_t(cam_handle);
  };
};
////////////////////////////////////////////////////////////////////////////////
struct CustomDepthImage {
  float *data;
  uint16_t width;
  uint16_t height;
  uint32_t nr_data_entries;

  CustomDepthImage()
    : data(NULL)
    , width(0)
    , height(0)
    , nr_data_entries(0)
  {};
  ~CustomDepthImage() {
    deallocate();
  };
  void deallocate() {
    width = height = nr_data_entries = 0;
    data = NULL;
  };
  void allocate(uint16_t width, uint16_t height, uint32_t nr_data_entries) {
    this->nr_data_entries = nr_data_entries;
    this->width = width;
    this->height = height;
    data = new float[nr_data_entries];
  };
};

PyObject *g_py_process_z = NULL;
CustomDepthImage g_custom_depth_image;

void parse_z_from_depth_data(royale_depth_data *info) {
  if (g_custom_depth_image.nr_data_entries != info->nr_points) {
    printf("Allocating %d memory\n", info->nr_points);
    if (g_custom_depth_image.data) {
      g_custom_depth_image.deallocate();
    }
    g_custom_depth_image.allocate(info->width, info->height, info->nr_points);
  }

  for (uint32_t i=0; i < info->nr_points; ++i) {
    g_custom_depth_image.data[i] = info->points[i].z;
  }

  if (g_py_process_z) {
    // Get GIL
    PyGILState_STATE gil_state = PyGILState_Ensure();

    // Convert to NumPy Image
    npy_intp dims[2] = {g_custom_depth_image.height, g_custom_depth_image.width};
    PyObject *image = PyArray_SimpleNewFromData(2, dims, NPY_FLOAT, g_custom_depth_image.data);
    PyObject *args = PyTuple_Pack(1, image);

    // Call Python callback
    PyObject *ret = PyObject_Call(g_py_process_z, args, NULL);

    Py_DECREF(ret);
    Py_DECREF(args);

    // Release GIL
    PyGILState_Release(gil_state);
  }
};
////////////////////////////////////////////////////////////////////////////////
class CameraDevice {
  royale_camera_handle handle_;
public:
  CameraDevice(PyObject *handle)
    :handle_(PyInt_AsSsize_t(handle))
  {};
  ~CameraDevice() {
    printf("Destroying camera device: %llu.\n", handle_);
    royale_camera_device_destroy(handle_);
  };
  PyObject *initialize() const {
    printf("Initializing camera device: %llu.\n", handle_);
    royale_camera_status status = royale_camera_device_initialize(handle_);
    if (ROYALE_STATUS_SUCCESS == status) {
      Py_RETURN_NONE;
    } else {
      PyErr_SetString(PyExc_RuntimeError, "Failed to initialize camera device.");
      return NULL;
    }
  };
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
    printf("Fetching camera info: %llu.\n", handle_);
    uint32_t nr_info_entries;
    royale_pair_string_string *info;
    royale_camera_status status = royale_camera_device_get_camera_info(handle_, &info, &nr_info_entries);

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
    royale_camera_status status = royale_camera_device_start_capture(handle_);

    if (ROYALE_STATUS_SUCCESS == status) {
      Py_RETURN_NONE;
    } else {
      set_error_message(status, "Failed to start capture", PyExc_RuntimeError);
      return NULL;
    }
  };
  PyObject *stop_capture() {
    royale_camera_status status = royale_camera_device_stop_capture(handle_);
    if (ROYALE_STATUS_SUCCESS == status) {
      Py_RETURN_NONE;
    } else {
      set_error_message(status, "Failed to stop capture", PyExc_RuntimeError);
      return NULL;
    }
  };
  PyObject *register_data_listener(PyObject *callable) {
    printf("Registering depth image listener.\n");
    if (!PyCallable_Check(callable)) {
      PyErr_SetString(PyExc_TypeError, "callable must be Callable object.");
      return NULL;
    }

    royale_camera_status status = royale_camera_device_register_data_listener(handle_, &parse_z_from_depth_data);
    g_py_process_z = callable;
    Py_XINCREF(callable);

    if (ROYALE_STATUS_SUCCESS == status) {
      Py_RETURN_NONE;
    } else {
      set_error_message(status, "Failed to register depth image listener", PyExc_RuntimeError);
      return NULL;
    }
  };
  PyObject *unregister_data_listener() {
    printf("Unregistering depth image listener.\n");

    Py_XDECREF(g_py_process_z);
    g_py_process_z = NULL;
    royale_camera_status status = royale_camera_device_unregister_data_listener(handle_);

    if (ROYALE_STATUS_SUCCESS == status) {
      Py_RETURN_NONE;
    } else {
      set_error_message(status, "Failed to unregister data listner", PyExc_RuntimeError);
      return NULL;
    }
  };
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
  // is_capturing
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
