# Internal Apple bundling logic

The `.bzl` files in this directory are internal implementation details for the
Apple bundling rules. They should not be imported directly by users; instead,
import the platform-specific rules in `//apple:ios.bzl`, `//apple:tvos.bzl`,
and so forth.

As a matter of style, files ending in `_actions.bzl` export modules with
functions that register specific actions (such as compiling Interface Builder
files with `ibtool`), whereas files ending in `_support.bzl` export modules
with general support functions (most of which do not register actions, but some
of which do in a generic sense, such as `xcode_env_action` in
`platform_support`). This separation helps to avoid circular dependencies in
Skylark `load` statements (because actions are only registered in one place,
but support functions may be needed in multiple places throughout the bundling
codebase).
