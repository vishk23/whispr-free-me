import AppKit

/// Installs a global (and local) NSEvent monitor for the ⌥⌘S combo and fires
/// `onTrigger` on the main thread whenever the hotkey is pressed.
///
/// This class is intentionally isolated from all dictation-shortcut machinery.
/// It never touches HotkeyManager, ShortcutCore, ShortcutBinding, or any
/// other dictation path.  It uses only the plain NSEvent monitor API.
final class SpeakSelectionHotkey {

    /// Called on the main thread whenever ⌥⌘S is pressed.
    var onTrigger: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isRunning = false

    /// Install both global and local NSEvent monitors for ⌥⌘S.
    /// Idempotent — calling while already running is a no-op.
    func start() {
        guard !isRunning else { return }
        isRunning = true

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleEvent(event)
        }

        // The local monitor must return the event unchanged so the focused
        // app still receives it (observe-only; no swallowing).
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
    }

    /// Remove the installed monitors.
    /// Idempotent — calling while already stopped is a no-op.
    func stop() {
        guard isRunning else { return }
        isRunning = false

        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
            globalMonitor = nil
        }
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
    }

    // MARK: - Private

    private func handleEvent(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard mods == [.command, .option] else { return }
        guard event.charactersIgnoringModifiers?.lowercased() == "s" else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onTrigger?()
        }
    }
}
