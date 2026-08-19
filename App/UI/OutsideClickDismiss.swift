import AppKit
import SwiftUI

/// Schließt eine `.popover`-Präsentation bei Klick außerhalb ihres eigenen
/// Fensters — Ersatz für AppKits eingebautes Outside-Click-Dismiss, das
/// innerhalb des selbstverwalteten `.applicationDefined`-NSPopovers aus
/// AppDelegate nicht zuverlässig greift (siehe Kommentar dort: SwiftUIs
/// `.popover` baut normalerweise auf genau das native transient-Verhalten
/// auf, das dort bewusst abgeschaltet ist). Analog zu AppDelegates
/// startOutsideClickMonitor()/closePopoverIfClickOutside(), hier aber auf
/// das eigene Content-Fenster statt das AppDelegate-Popover bezogen.
private struct OutsideClickDismissModifier: ViewModifier {
    @Binding var isPresented: Bool
    @State private var capturedWindow: NSWindow?
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?

    func body(content: Content) -> some View {
        content
            .background(WindowCaptureView(window: $capturedWindow))
            .onChange(of: isPresented) { _, presented in
                if presented {
                    startMonitoring()
                } else {
                    stopMonitoring()
                }
            }
            .onDisappear { stopMonitoring() }
    }

    private func startMonitoring() {
        stopMonitoring()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            closeIfOutside(event.window)
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            isPresented = false
        }
    }

    private func stopMonitoring() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        localMonitor = nil
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        globalMonitor = nil
    }

    private func closeIfOutside(_ eventWindow: NSWindow?) {
        // Solange das eigene Fenster noch nicht eingefangen wurde, keine
        // Klicks als "außerhalb" werten — sonst schließt sich das Popover
        // beim allerersten Event nach dem Öffnen sofort selbst.
        guard let capturedWindow else { return }
        guard eventWindow !== capturedWindow else { return }
        isPresented = false
    }
}

/// Fängt das AppKit-Fenster ein, in dem dieser SwiftUI-Content gehostet wird
/// (hier: das native Child-Fenster des inneren `.popover`), sobald es
/// verfügbar ist — SwiftUI bietet dafür keine direkte API, `view.window` ist
/// erst nach dem Einhängen in die Fensterhierarchie gesetzt.
private struct WindowCaptureView: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { window = view.window }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { window = nsView.window }
    }
}

extension View {
    /// Schließt `isPresented`, sobald außerhalb des Popovers geklickt wird —
    /// für `.popover`s, die innerhalb des AppDelegate-eigenen
    /// `.applicationDefined`-NSPopovers gehostet werden und daher AppKits
    /// normales Outside-Click-Dismiss nicht automatisch bekommen.
    func dismissPopoverOnOutsideClick(isPresented: Binding<Bool>) -> some View {
        modifier(OutsideClickDismissModifier(isPresented: isPresented))
    }
}
