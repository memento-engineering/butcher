/// Process-tree lifetime and kill primitives for the butcher mutation engine.
///
/// A consumer starts work through [SupervisedProcess], which owns the spawn
/// through a [ProcessInterlock] so the started process is a kill boundary from
/// the moment it exists. [terminateAllSupervisedProcesses] reaps whatever is
/// still running, [liveDescendants] says whether the run itself leaked, and
/// [hostProcessCount] is a whole-host diagnostic that judges nothing.
library;

export 'src/process_census.dart' show hostProcessCount;
export 'src/process_interlock.dart' show ProcessInterlock;
export 'src/supervised_process.dart'
    show SupervisedProcess, liveDescendants, terminateAllSupervisedProcesses;
