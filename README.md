# Issue in copyMemory() with MTLBuffer .storageModeShared on macOS and iOS

This is a tiny Xcode project for macOS and iOS, that have been sent to Apple Feedback Assistant to report an issue.
The issue number `FB11913672`.

# Update Feb 27, 2023 (Fix)

The issues has been addressed and fixed in **Xcode 14.3 Beta(14E5197f)**.
I have tested it with **MacMini M1 2020, OSX13.1(22C65)** and **iPhone 13 Mini, iOS 16.3.1**.
Now the data copied to a shared MTLBuffer with copyMemory() is in sync.

## Issuse Description

`MTLBuffer` in `storageModeShared`, which is used for a uniform constant for a fragment shader is not synced after  `buffer.contents().copyMemory( from:  byteCount: )` is called for it, if the Swift compiler optimization option is `-O` (speed).
If the compiler option is `-Onone `or `-Osize`, it is synced fine.
Also, if the `cocpyMemory()` function is replaced with element-by-element assignments using buffered pointer, it is synced regardless of the compiler optimization option specified.

Please see `updateUniformBuffer()` in `ios/MetalView.swift` and in `macos/MetalView.swift` in the attachment.
This happens with Xcode 14.2 (14C18) on iPhone 13 Mini, iOS 16.2 (20C65) and Mac Mini, macOS Ventura 13.1.

# How to Reproduce
- Launch Xcode 14.2.
- Open the project CopyMemoryIsolated attached.
- Build with the swift compilation optimization `-O` (speed), for example with the build configuration `Release`.
- Run the program. It should show a triangle with varying gray scale, but it does not. It stays black, because the uniform that specifies the color in  `SIMD3<Float>` is not propagated into the fragment shader execution ( `frag()` in `passthru.metal` ).
