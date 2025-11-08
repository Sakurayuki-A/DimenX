#include "com_resource_manager.h"
#include <windows.h>
#include <objbase.h>
#include <iostream>

ComResourceManager::ComResourceManager() : is_initialized_(false) {}

ComResourceManager::~ComResourceManager() {
    ForceRelease();
}

bool ComResourceManager::Initialize() {
    if (is_initialized_) {
        std::cout << "COM already initialized" << std::endl;
        return true;
    }

    // 使用COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
    
    if (SUCCEEDED(hr) || hr == RPC_E_CHANGED_MODE) {
        is_initialized_ = true;
        std::cout << "COM initialized successfully" << std::endl;
        return true;
    } else {
        std::cout << "COM initialization failed with HRESULT: 0x" << std::hex << hr << std::endl;
        return false;
    }
}

void ComResourceManager::ForceRelease() {
    if (!is_initialized_) {
        return;
    }

    try {
        std::cout << "Force releasing COM resources..." << std::endl;
        
        // 强制垃圾回收
        CoFreeUnusedLibraries();
        
        // 等待一小段时间让资源释放
        Sleep(50);
        
        // 反初始化COM
        CoUninitialize();
        
        is_initialized_ = false;
        std::cout << "COM resources released successfully" << std::endl;
    } catch (...) {
        std::cout << "Exception during COM resource release" << std::endl;
        is_initialized_ = false;
    }
}

bool ComResourceManager::Reset() {
    std::cout << "Resetting COM environment..." << std::endl;
    
    ForceRelease();
    
    // 等待更长时间确保资源完全释放
    Sleep(200);
    
    return Initialize();
}

bool ComResourceManager::CheckStatus() {
    // 简单检查：尝试调用一个COM函数
    try {
        GUID guid;
        HRESULT hr = CoCreateGuid(&guid);
        return SUCCEEDED(hr);
    } catch (...) {
        return false;
    }
}

// 静态实例
ComResourceManager& ComResourceManager::GetInstance() {
    static ComResourceManager instance;
    return instance;
}
