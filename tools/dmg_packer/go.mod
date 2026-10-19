// Pins the `dmg-packer` tool used by `macos_dmg`, and the modules it needs. The `go_deps` extension in the top-level
// `MODULE.bazel` reads this file and the `go.sum` beside it.
//
// To move the packer version, run these commands in this folder:
//
//	go get -tool github.com/jetbrains/go-dmg-packer/cmd/dmg-packer@<version>
//	go mod tidy
module github.com/bazelbuild/rules_apple/tools/dmg_packer

go 1.25.0

tool github.com/jetbrains/go-dmg-packer/cmd/dmg-packer

require (
	github.com/jetbrains/go-dmg-packer v0.1.0 // indirect
	github.com/jetbrains/go-dmg-writer v0.0.0-20260907121604-149c5f3195fe // indirect
	// Raised above what the packer asks for, to the first release that fixes GO-2026-5024.
	golang.org/x/sys v0.44.0 // indirect
	golang.org/x/text v0.41.0 // indirect
	howett.net/plist v1.0.1 // indirect
)
