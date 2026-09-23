/// Process-tree lifetime and kill primitives for the butcher mutation engine.
///
/// A consumer starts every process through a [ProcessInterlock], so the
/// started process is a kill boundary from the moment it exists and its whole
/// tree dies in one call.
library;

export 'src/process_interlock.dart' show ProcessInterlock;
