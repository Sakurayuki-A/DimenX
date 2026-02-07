#ifndef COM_RESOURCE_MANAGER_H
#define COM_RESOURCE_MANAGER_H

class ComResourceManager {
public:
    ComResourceManager();
    ~ComResourceManager();

    // 初始化COM
    bool Initialize();
    
    // 强制释放COM资源
    void ForceRelease();
    
    // 重置COM环境
    bool Reset();
    
    // 检查COM状态
    bool CheckStatus();
    
    // 获取单例实例
    static ComResourceManager& GetInstance();
    
    // 是否已初始化
    bool IsInitialized() const { return is_initialized_; }

private:
    bool is_initialized_;
};

#endif // COM_RESOURCE_MANAGER_H
