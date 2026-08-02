/// Cross-platform "save these downloaded bytes somewhere the user can get
/// to them" helper. Resolves to a different implementation per platform at
/// compile time (see the three files this exports):
///
///  - mobile/desktop (dart:io available): writes to the app's sandboxed
///    documents directory, then opens it with the system's default viewer.
///  - web (dart:html available): triggers a normal browser "Save As" /
///    download via a Blob + anchor click. There is no filesystem to write
///    to and nothing to "open" separately - the browser download *is* the
///    action.
///
/// Both implementations expose the same two functions so call sites never
/// need to branch on platform themselves.
library;

export 'save_file_stub.dart'
    if (dart.library.io) 'save_file_io.dart'
    if (dart.library.html) 'save_file_web.dart';
