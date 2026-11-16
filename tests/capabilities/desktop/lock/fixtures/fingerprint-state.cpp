// Appended to the actual patched Fingerprint translation unit by fingerprint-state.bats.
int main(int argc, char** argv) {
    assert(argc == 2);
    const std::string test = argv[1];
    CFingerprint fingerprint;
    auto& state = fingerprint.m_sDBUSState;
    fingerprint.startVerify();
    assert(state.claiming && !state.claimed && !state.verifying);

    if (test == "busy") {
        sdbus::reply("Claim", sdbus::Error{"net.reactivated.Fprint.Error.AlreadyInUse"});
        sdbus::present();
        sdbus::status("verify-no-match");
        sdbus::status("verify-match");
        assert(!fingerprint.getLastPrompt());
        assert(auth.unlocks == 0 && auth.failures == 0);
        assert(sdbus::bus.replies["VerifyStart"].empty());
        return 0;
    }
    if (test == "recover") {
        sdbus::reply("Claim", sdbus::Error{"net.reactivated.Fprint.Error.AlreadyInUse"});
        sdbus::status("verify-match");
        assert(auth.unlocks == 0 && !fingerprint.getLastPrompt());
        lock.tick();
        assert(state.claiming);
    }
    if (test == "late-claim") {
        fingerprint.terminate();
        sdbus::reply("Claim");
        assert(!state.claimed && !state.verifying && !fingerprint.getLastPrompt());
        assert(sdbus::bus.replies["VerifyStart"].empty());
        assert(auth.unlocks == 0);
        return 0;
    }
    sdbus::reply("Claim");
    assert(state.claimed && state.verifying && !state.claiming);

    if (test == "early-match") {
        sdbus::status("verify-match");
        assert(auth.unlocks == 1 && !state.claimed);
        sdbus::reply("VerifyStart");
        assert(!fingerprint.getLastPrompt() && !state.verifying);
        return 0;
    }
    if (test == "start-error") {
        sdbus::reply("VerifyStart", sdbus::Error{"net.reactivated.Fprint.Error.NoEnrolledPrints"});
        sdbus::present();
        sdbus::status("verify-match");
        assert(!state.verifying && !fingerprint.getLastPrompt() && auth.unlocks == 0);
        return 0;
    }
    if (test == "late-start") {
        fingerprint.stopVerify();
        sdbus::reply("VerifyStart");
        sdbus::present();
        sdbus::status("verify-match");
        assert(!state.verifying && !fingerprint.getLastPrompt() && auth.unlocks == 0);
        return 0;
    }
    if (test == "generation") {
        fingerprint.stopVerify();
        fingerprint.startVerify(true);
        sdbus::reply("VerifyStart", sdbus::Error{"old-error"});
        assert(state.verifying);
        sdbus::reply("VerifyStart");
        assert(fingerprint.getLastPrompt());
        sdbus::status("verify-match");
        assert(auth.unlocks == 1);
        return 0;
    }
    sdbus::reply("VerifyStart");
    assert(fingerprint.getLastPrompt());
    if (test == "exhausted") {
        state.retries = 3;
        sdbus::status("verify-no-match");
        sdbus::present();
        sdbus::status("verify-match");
        assert(state.done && !state.verifying && !fingerprint.getLastPrompt());
        assert(auth.unlocks == 0 && auth.failures == 1);
        return 0;
    }
    if (test == "retry") {
        sdbus::status("verify-no-match");
        assert(!state.verifying && !state.done && !fingerprint.getLastPrompt());
        sdbus::status("verify-match");
        assert(auth.unlocks == 0);
        lock.tick();
        sdbus::reply("VerifyStart");
        assert(state.verifying && state.retries == 1);
    }
    if (test == "sleep") {
        state.sleeping = true;
        sdbus::status("verify-match");
        assert(auth.unlocks == 0 && !state.verifying && !fingerprint.getLastPrompt());
        state.sleeping = false;
        fingerprint.startVerify();
        sdbus::reply("VerifyStart");
    }
    if (test == "terminate") {
        fingerprint.terminate();
        sdbus::present();
        sdbus::status("verify-match");
        assert(auth.unlocks == 0 && !state.claimed && !fingerprint.getLastPrompt());
        return 0;
    }
    if (test == "fading") {
        lock.fading = true;
        sdbus::status("verify-match");
        assert(auth.unlocks == 0);
        return 0;
    }
    if (test == "release-error") {
        sdbus::bus.failSync = "Release";
        fingerprint.releaseDevice();
        sdbus::status("verify-match");
        assert(auth.unlocks == 0 && !state.claimed && !fingerprint.getLastPrompt());
        return 0;
    }
    sdbus::present();
    assert(fingerprint.getLastPrompt());
    sdbus::status("verify-match");
    assert(auth.unlocks == 1 && !state.claimed && !state.verifying);
    assert(!fingerprint.getLastPrompt());
    sdbus::status("verify-match");
    assert(auth.unlocks == 1);
    fingerprint.terminate();
    return 0;
}
