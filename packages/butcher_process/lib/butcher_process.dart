/// Process-tree lifetime and kill primitives for the butcher mutation engine.
///
/// A consumer starts work through [SupervisedProcess], which owns the spawn
/// through a [ProcessInterlock] so the started process is a kill boundary from
/// the moment it exists. [terminateAllSupervisedProcesses] reaps whatever is
/// still running.
library;

export 'src/process_interlock.dart' show ProcessInterlock;
export 'src/supervised_process.dart'
    show SupervisedProcess, terminateAllSupervisedProcesses;
