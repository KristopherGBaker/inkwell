import Foundation

enum LiveReloadScript {
    static let path = "/__live_reload"

    static let snippet = """
    (() => {
        const source = new EventSource('/__live_reload');
        source.onmessage = (event) => {
            if (event.data === 'reload') {
                window.location.reload();
            }
        };
    })();
    """
}
