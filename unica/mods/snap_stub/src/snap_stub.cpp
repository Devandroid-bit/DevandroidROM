// snap_stub.cpp
// Minimal stub for vendor.samsung.hardware.snap.ISehSnap.
//
// AServiceManager_* / ABinderProcess_* are intentionally excluded from
// the redistributable NDK's link stub (marked "# apex" in libbinder_ndk's
// linker version script -- reserved for platform/vendor builds done
// inside the full AOSP tree). The real device's /system/lib64 (or
// /apex/.../lib64) libbinder_ndk.so still exports them at runtime, so we
// resolve them ourselves via dlopen/dlsym instead of linking at compile
// time. This avoids both the missing-header and missing-symbol problems
// at once. See https://github.com/android/ndk/issues/1304.

#include <dlfcn.h>
#include <cstdint>
#include <cstdio>

// Opaque types -- never dereferenced by our code, only passed around as
// pointers, so a forward declaration keeps the ABI identical to the real
// headers without needing to include them.
struct AIBinder;
struct AIBinder_Class;

typedef int32_t binder_status_t;
typedef void* (*OnCreate)(void* args);
typedef void (*OnDestroy)(void* userData);
typedef binder_status_t (*OnTransact)(AIBinder*, uint32_t, const void*, void*);

typedef AIBinder_Class* (*fn_ClassDefine)(const char*, OnCreate, OnDestroy, OnTransact);
typedef AIBinder* (*fn_BinderNew)(const AIBinder_Class*, void*);
typedef binder_status_t (*fn_AddService)(AIBinder*, const char*);
typedef void (*fn_SetThreadPoolMax)(uint32_t);
typedef void (*fn_StartThreadPool)();
typedef void (*fn_JoinThreadPool)();

static const char* kInterfaceDescriptor = "vendor.samsung.hardware.snap.ISehSnap";
static const char* kInstanceName = "vendor.samsung.hardware.snap.ISehSnap/default";

// Fails fast on every real call instead of hanging the caller.
static binder_status_t onTransact(AIBinder*, uint32_t, const void*, void*) {
    return -1;  // any non-zero status_t reads as "not OK" to callers
}
static void* onCreate(void* args) { return args; }
static void onDestroy(void*) {}

int main() {
    void* lib = dlopen("libbinder_ndk.so", RTLD_NOW);
    if (!lib) {
        fprintf(stderr, "snap_stub: dlopen failed: %s\n", dlerror());
        return 1;
    }

    auto classDefine = (fn_ClassDefine)dlsym(lib, "AIBinder_Class_define");
    auto binderNew = (fn_BinderNew)dlsym(lib, "AIBinder_new");
    auto addService = (fn_AddService)dlsym(lib, "AServiceManager_addService");
    auto setMax = (fn_SetThreadPoolMax)dlsym(lib, "ABinderProcess_setThreadPoolMaxThreadCount");
    auto startPool = (fn_StartThreadPool)dlsym(lib, "ABinderProcess_startThreadPool");
    auto joinPool = (fn_JoinThreadPool)dlsym(lib, "ABinderProcess_joinThreadPool");

    if (!classDefine || !binderNew || !addService || !setMax || !startPool || !joinPool) {
        fprintf(stderr, "snap_stub: dlsym failed for one or more symbols\n");
        return 1;
    }

    AIBinder_Class* cls = classDefine(kInterfaceDescriptor, onCreate, onDestroy, onTransact);
    AIBinder* binder = binderNew(cls, nullptr);

    binder_status_t status = addService(binder, kInstanceName);
    if (status != 0) {  // 0 == STATUS_OK
        fprintf(stderr, "snap_stub: addService failed: %d\n", status);
        return 1;
    }

    setMax(0);
    startPool();
    joinPool();  // never returns
    return 0;
}
