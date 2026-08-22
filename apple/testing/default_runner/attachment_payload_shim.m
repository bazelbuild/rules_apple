// Optional memory shim for tests run through `xcodebuild test-without-building`.
//
// XCTAttachment payloads transit xcodebuild's memory at ~1.4x their size on
// their way into the result bundle - even when the configured attachment
// lifetime discards them at finalization, and even when no result bundle was
// requested. For attachment-heavy suites this dominates the harness's memory
// footprint and limits how many simulators a machine can run in parallel.
//
// Link this library into a test's `deps` and set the environment variable
// RULES_APPLE_ATTACHMENT_PAYLOADS (e.g. via the test rule's `env` attribute):
//   - "drop":  payloads over 4KB are replaced with a short note. Use when the
//              attachment lifetime is "keepNever" - the payloads were going to
//              be discarded after transfer anyway.
//   - "spill": payloads over 4KB are written to
//              $TEST_UNDECLARED_OUTPUTS_DIR/spilled_attachments/ (delivered in
//              Bazel's test outputs zip) and replaced in the attachment with a
//              note naming the file.
//   - unset or anything else: the shim does nothing.
//
// The shim intercepts XCTAttachment's public designated initializer, so it
// covers every data-based attachment from any library. It fails open: if the
// class or selector is missing (a future Xcode restructuring), it logs and
// leaves XCTest untouched.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static IMP gOriginalInit;
static BOOL gSpill;

static id RulesAppleAttachmentInit(id self, SEL _cmd, NSString *uti, NSString *name,
                                   NSData *payload, NSDictionary *userInfo) {
  NSData *replacement = payload;
  if (payload.length > 4096) {
    NSString *note = nil;
    if (gSpill) {
      const char *outDir = getenv("TEST_UNDECLARED_OUTPUTS_DIR");
      if (outDir) {
        NSString *dir = [[NSString stringWithUTF8String:outDir]
            stringByAppendingPathComponent:@"spilled_attachments"];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
        NSString *file = [dir stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%@-%@", [NSUUID UUID].UUIDString,
                                       name ?: @"attachment"]];
        if ([payload writeToFile:file atomically:NO]) {
          note = [NSString stringWithFormat:@"attachment payload (%lu bytes) spilled to %@",
                                            (unsigned long)payload.length, file];
        }
      }
    } else {
      note = [NSString stringWithFormat:
          @"attachment payload (%lu bytes) dropped (RULES_APPLE_ATTACHMENT_PAYLOADS=drop)",
          (unsigned long)payload.length];
    }
    if (note) {
      NSLog(@"RulesAppleAttachmentShim: %@", note);
      replacement = [note dataUsingEncoding:NSUTF8StringEncoding];
    }
  }
  typedef id (*InitFn)(id, SEL, NSString *, NSString *, NSData *, NSDictionary *);
  return ((InitFn)gOriginalInit)(self, _cmd, uti, name, replacement, userInfo);
}

__attribute__((constructor)) static void RulesAppleInstallAttachmentShim(void) {
  const char *mode = getenv("RULES_APPLE_ATTACHMENT_PAYLOADS");
  if (!mode) return;
  if (strcmp(mode, "spill") == 0) {
    gSpill = YES;
  } else if (strcmp(mode, "drop") != 0) {
    return;
  }
  Class cls = objc_getClass("XCTAttachment");
  if (!cls) {
    NSLog(@"RulesAppleAttachmentShim: XCTAttachment class not found; shim inactive");
    return;
  }
  SEL sel = sel_getUid("initWithUniformTypeIdentifier:name:payload:userInfo:");
  Method m = class_getInstanceMethod(cls, sel);
  if (!m) {
    NSLog(@"RulesAppleAttachmentShim: designated initializer not found; shim inactive");
    return;
  }
  gOriginalInit = method_setImplementation(m, (IMP)RulesAppleAttachmentInit);
  NSLog(@"RulesAppleAttachmentShim: installed (%s mode)", gSpill ? "spill" : "drop");
}
