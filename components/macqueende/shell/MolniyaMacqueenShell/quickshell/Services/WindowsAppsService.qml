pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Services

Singleton {
    id: root

    property bool available: false
    property bool loading: false
    property var apps: []
    property var runtimes: []
    property var releases: []
    property var state: ({"phase": "idle"})
    property bool _terminalHandled: false

    readonly property bool busy: ["preparing", "downloading", "starting"].includes(state?.phase || "")
    readonly property bool appRunning: state?.phase === "running"

    Connections {
        target: DMSService
        function onCapabilitiesReceived() { root._updateAvailability(); }
        function onConnectionStateChanged() { root._updateAvailability(); }
    }

    Component.onCompleted: _updateAvailability()

    Timer {
        interval: 750
        repeat: true
        running: root.busy || root.appRunning
        onTriggered: root.refreshState()
    }

    function _updateAvailability() {
        available = DMSService.isConnected
                 && Array.isArray(DMSService.capabilities)
                 && DMSService.capabilities.includes("windows");
        if (available)
            refresh();
    }

    function refresh() {
        if (!available || loading)
            return;
        loading = true;
        DMSService.windowsApps(response => {
            if (response?.result)
                apps = response.result;
            DMSService.windowsRuntimes(runtimeResponse => {
                if (runtimeResponse?.result)
                    runtimes = runtimeResponse.result;
                const installedTags = (runtimes || []).map(runtime => runtime.tag);
                releases = (releases || []).map(release => Object.assign({}, release, {
                    "installed": installedTags.includes(release.tag)
                }));
                loading = false;
            });
        });
    }

    function loadReleases() {
        if (!available)
            return;
        DMSService.windowsReleases(response => {
            if (response?.result)
                releases = response.result;
            else
                ToastService.showWarning("Не удалось получить список версий GE-Proton.", "", "", "windows-runtime");
        });
    }

    function installRuntime(release) {
        if (!release || busy)
            return;
        _terminalHandled = false;
        DMSService.windowsInstallRuntime(release, response => {
            if (response?.result)
                state = response.result;
            else
                ToastService.showError(response?.error || "Не удалось начать установку Proton.", "", "", "windows-runtime");
        });
    }

    function openExecutable(path) {
        if (!path || busy)
            return;
        _terminalHandled = false;
        DMSService.windowsOpen(path, response => {
            if (response?.result) {
                state = response.result;
                ToastService.showInfo("Windows-приложение запускается…", "Первый запуск может занять около минуты.", "", "windows-launch");
            } else {
                ToastService.showError(response?.error || "Не удалось открыть EXE.", "", "", "windows-launch");
            }
        });
    }

    function launch(app) {
        if (!app || busy)
            return;
        _terminalHandled = false;
        DMSService.windowsLaunch(app.id, response => {
            if (response?.result) {
                state = response.result;
                ToastService.showInfo("Запускается: " + app.name, "Первый запуск может занять около минуты.", "", "windows-launch");
            } else {
                ToastService.showError(response?.error || "Приложение не запустилось.", "", "", "windows-launch");
            }
        });
    }

    function remove(app, removePrefix) {
        if (!app || busy)
            return;
        DMSService.windowsRemove(app.id, removePrefix, response => {
            if (!response?.error) {
                ToastService.showInfo("Удалено из меню: " + app.name, "", "", "windows-app");
                refresh();
            } else {
                ToastService.showError(response.error, "", "", "windows-app");
            }
        });
    }

    function cancel() {
        if (busy)
            DMSService.windowsCancel(null);
    }

    function refreshState() {
        if (!available)
            return;
        DMSService.windowsState(response => {
            if (!response?.result)
                return;
            state = response.result;
            const phase = state.phase || "idle";
            if ((phase === "complete" || phase === "error") && !_terminalHandled) {
                _terminalHandled = true;
                if (phase === "complete") {
                    ToastService.showInfo(state.message || "Готово.", "", "", "windows-launch");
                    refresh();
                } else {
                    const launchFailure = state?.app !== undefined && state.app !== null;
                    ToastService.showError(launchFailure ? "Приложение не запустилось." : "Не удалось установить GE-Proton.",
                                           state?.logPath ? "Диагностический журнал сохранён автоматически." : "Повторите попытку позже.",
                                           "", "windows-launch");
                }
            }
        });
    }
}
