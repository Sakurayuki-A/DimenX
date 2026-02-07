#include "com_method_channel.h"
#include "com_resource_manager.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

ComMethodChannel::ComMethodChannel(flutter::FlutterEngine* engine) {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        engine->messenger(), "com_resource_manager",
        &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler(
        [](const flutter::MethodCall<flutter::EncodableValue>& call,
           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
            
            const std::string& method = call.method_name();
            
            if (method == "initializeCOM") {
                bool success = ComResourceManager::GetInstance().Initialize();
                result->Success(flutter::EncodableValue(success));
            }
            else if (method == "forceReleaseCOM") {
                ComResourceManager::GetInstance().ForceRelease();
                result->Success(flutter::EncodableValue(true));
            }
            else if (method == "resetCOM") {
                bool success = ComResourceManager::GetInstance().Reset();
                result->Success(flutter::EncodableValue(success));
            }
            else if (method == "checkCOMStatus") {
                bool status = ComResourceManager::GetInstance().CheckStatus();
                result->Success(flutter::EncodableValue(status));
            }
            else {
                result->NotImplemented();
            }
        });
}
