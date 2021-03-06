# BromiumCoreUtils

Core Objective-C/Cocoa utilities by Bromium Inc. Everything in here should not
depend on AppKit or any third party libraries.

## Contents

 - `BRUARCUtils` --  Helper macros like `BRU_weakify` and `BRU_strongify` that help with dealing with weak/strong variables.
 - `BRUArithmetic` --  Helper functions for safe (overflow-aware) arithmetic.
 - `BRUAsserts` --  Assertion macros.
 - `BRUConcurrentBox` --  A simple concurrency primitive to safely exchange data between threads.
 - `BRUConcurrentVariable` --  A simple concurrency primitive to safely access shared data from multiple threads.
 - `BRUDeferred` --  Deferred/promise implementation.
 - `BRUDispatchUtils` --  Helpers for GCD/libdispatch.
 - `BRUEitherErrorOrSuccess` --  A simple data type to represent failure or success of computations.
 - `BRUFileMonitor` -- A simple mechanism for monitoring file changes.
 - `BRUMemoryRegion` -- Safe memory region representation and methods.
 - `BRUNullabilityUtils` --  Nullability helpers.
 - `BRURateLimiter` -- Utility for rate limiting operations.
 - `BRUResourceCleanup` --  An helper object to handle resource cleanup if a sequence of resource acquiring operations fails midway.
 - `BRURetry` -- Utility class for managing the lifecycle of retryable actions.
 - `BRUSetDiffFormatter` --  Helper function to calculate and format a diff of sets.
 - `BRUTask` --  An drop-in `NSTask` replacement.
 - `BRUTemporaryFiles` --  Temporary file and directory utilities.
 - `BRUTimer` --  An `NSTimer` replacement built on top of GCD/libdispatch.

## License

BSD 2-Clause, for details see `LICENSE`.
