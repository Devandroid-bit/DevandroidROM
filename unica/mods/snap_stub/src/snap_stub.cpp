// snap_stub.cpp
// Minimal stub for the vendor.samsung.hardware.snap.ISehSnap AIDL service.
// Purpose: register under the exact interface name the real snap service
// uses, so AServiceManager_waitForService() unblocks immediately instead of
// hanging forever (the real snap-service binary fails to link on this ROM).
// This stub does NOT implement any real snap functionality. Any actual
// call into it fails fast with an error -- that is the desired behavior:
// callers get an error instead of freezing the calling thread forever.

#include <android/binder_ibinder.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>
#include <android/binder_status.h>

// Exact interface descriptor and instance name, confirmed from the
// device's own vendor.samsung.hardware.snap-lazy.rc file.
static const char* kInterfaceDescriptor = "vendor.samsung.hardware.snap.ISehSnap";
static const char* kInstanceName = "vendor.samsung.hardware.snap.ISehSnap/default";

// Called for every incoming Binder transaction. We never implement any
// real transaction; we simply refuse it cleanly and immediately.
static binder_status_t onTransact(AIBinder* /*binder*/,
                                   transaction_code_t /*code*/,
                                   const AParcel* /*in*/,
                                   AParcel* /*out*/) {
    return STATUS_UNKNOWN_TRANSACTION;  // fail fast, never hang the caller
}

// Binder class lifecycle hooks -- no per-instance state needed for a stub.
static void* onCreate(void* args) { return args; }
static void onDestroy(void* /*userData*/) {}

int main() {
    // Define a minimal Binder class using the real interface's descriptor.
    AIBinder_Class* binderClass = AIBinder_Class_define(
        kInterfaceDescriptor, onCreate, onDestroy, onTransact);

    // Create the Binder object and register it under the exact instance
    // name that waitForService() callers are looking for.
    AIBinder* binder = AIBinder_new(binderClass, nullptr /*args*/);
    binder_status_t status = AServiceManager_addService(binder, kInstanceName);
    if (status != STATUS_OK) {
        // Registration failed; exit so init sees the failure and can retry
        // per its .rc policy instead of silently doing nothing.
        return 1;
    }

    // Stay alive forever, answering Binder calls (with onTransact's fast
    // failure) so the service is always present once started.
    ABinderProcess_setThreadPoolMaxThreadCount(0);
    ABinderProcess_startThreadPool();
    ABinderProcess_joinThreadPool();  // never returns

    return 0;
}
