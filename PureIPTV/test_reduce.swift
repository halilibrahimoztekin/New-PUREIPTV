import ComposableArchitecture

// We just want to extract the closure body into a regular function to see the error.
// We can use awk or sed. But let's just use `swiftc -typecheck` on a modified version where we type out the closure signature explicitly.
