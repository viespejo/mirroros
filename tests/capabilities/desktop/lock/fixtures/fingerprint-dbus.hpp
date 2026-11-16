// Test-only D-Bus and hyprlock doubles; no authentication or session operations.
#include <any>
#include <cassert>
#include <chrono>
#include <deque>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <type_traits>
#include <vector>

namespace sdbus {
using ServiceName = std::string;
using ObjectPath = std::string;
struct Error {
    std::string name;
    const std::string& getName() const { return name; }
    const char* what() const { return name.c_str(); }
};
struct Variant {
    bool value = false;
    template <typename T> T get() const { return value; }
};
struct Bus {
    std::map<std::string, std::deque<std::function<void(std::optional<Error>)>>> replies;
    std::map<std::string, std::any> signals;
    std::vector<std::string> calls;
    std::string failSync;
} inline bus;
struct Method {
    std::string name;
    bool async;
    Method& onInterface(const ServiceName&) {
        if (!async) {
            bus.calls.push_back(name);
            if (bus.failSync == name) throw Error{"test-error"};
        }
        return *this;
    }
    template <typename... T> Method& withArguments(T&&...) { return *this; }
    template <typename T> void storeResultsTo(T& result) { result = "/test/device"; }
    template <typename F> void uponReplyInvoke(F callback) {
        bus.calls.push_back(name);
        bus.replies[name].push_back(callback);
    }
};
struct Signal {
    std::string name;
    Signal& onInterface(const ServiceName&) { return *this; }
    template <typename F> void call(F callback) {
        if constexpr (std::is_invocable_v<F, const std::string&, bool>)
            bus.signals[name] = std::function<void(const std::string&, bool)>(callback);
        else if constexpr (std::is_invocable_v<F, const std::string&, const std::map<std::string, Variant>&>)
            bus.signals[name] = std::function<void(const std::string&, const std::map<std::string, Variant>&)>(callback);
        else if constexpr (std::is_invocable_v<F, const std::string&>)
            bus.signals[name] = std::function<void(const std::string&)>(callback);
        else
            bus.signals[name] = std::function<void(bool)>(callback);
    }
};
struct Property {
    Property& onInterface(const ServiceName&) { return *this; }
    template <typename F> void uponReplyInvoke(F callback) { callback(std::nullopt, Variant{}); }
};
struct IProxy {
    Method callMethod(const std::string& name) { return {name, false}; }
    Method callMethodAsync(const std::string& name) { return {name, true}; }
    Signal uponSignal(const std::string& name) { return {name}; }
    Property getPropertyAsync(const std::string&) { return {}; }
};
inline std::unique_ptr<IProxy> createProxy(int&, const ServiceName&, const ObjectPath&) {
    return std::make_unique<IProxy>();
}
inline void reply(const std::string& name, std::optional<Error> error = std::nullopt) {
    assert(!bus.replies[name].empty());
    auto callback = bus.replies[name].front();
    bus.replies[name].pop_front();
    callback(error);
}
inline void status(const std::string& result, bool done = true) {
    std::any_cast<std::function<void(const std::string&, bool)>>(bus.signals.at("VerifyStatus"))(result, done);
}
inline void present() {
    std::any_cast<std::function<void(const std::string&, const std::map<std::string, Variant>&)>>(
        bus.signals.at("PropertiesChanged"))("net.reactivated.Fprint.Device", {{"finger-present", Variant{true}}});
}
}
namespace Log {
enum { WARN, ERR, INFO };
struct Logger { template <typename... T> void log(int, const char*, T&&...) {} };
inline Logger instance;
inline Logger* logger = &instance;
}
namespace Hyprlang { using STRING = std::string; using INT = int; }
struct Config {
    template <typename T> T* getValue(const char*) {
        static T value{};
        if constexpr (std::is_same_v<T, std::string>) value = "ready";
        return &value;
    }
} inline config;
inline Config* g_pConfigManager = &config;
struct CTimer {};
template <typename T> using ASP = std::shared_ptr<T>;
struct Lock {
    bool fading = false;
    std::deque<std::function<void()>> timers;
    bool isFadingOutOrTerminating() const { return fading; }
    void enqueueForceUpdateTimers() {}
    template <typename D, typename F> void addTimer(D, F callback, void* data) {
        timers.push_back([=] { callback(nullptr, data); });
    }
    void tick() {
        assert(!timers.empty());
        auto callback = timers.front();
        timers.pop_front();
        callback();
    }
} inline lock;
inline Lock* g_pHyprlock = &lock;
enum eAuthImplementations { AUTH_IMPL_FINGERPRINT };
struct IAuthImplementation {
    virtual ~IAuthImplementation() = default;
    virtual eAuthImplementations getImplType() = 0;
    virtual void init() = 0;
    virtual void handleInput(const std::string&) = 0;
    virtual bool checkWaiting() = 0;
    virtual std::optional<std::string> getLastFailText() = 0;
    virtual std::optional<std::string> getLastPrompt() = 0;
    virtual void terminate() = 0;
};
struct Auth {
    int unlocks = 0;
    int failures = 0;
    void enqueueUnlock() { unlocks++; }
    void enqueueFail(const std::string&, eAuthImplementations) { failures++; }
} inline auth;
inline Auth* g_pAuth = &auth;
inline int connection;
struct Dbus {
    int* m_connection = &connection;
    std::unique_ptr<sdbus::IProxy> m_freedesktopLogin1 = std::make_unique<sdbus::IProxy>();
} inline dbus;
inline Dbus* g_dbus = &dbus;
