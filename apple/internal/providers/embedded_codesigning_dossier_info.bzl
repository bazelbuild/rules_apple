# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""AppleEmbeddedCodesigningDossierInfo provider implementation."""

visibility("@build_bazel_rules_apple//apple/internal/...")

AppleEmbeddedCodesigningDossierInfo = provider(
    doc = """
Private provider to propagate codesigning dossier information.
""",
    fields = {
        "direct_embedded_dossier": """
A struct with codesigning dossier information to be embedded in another target, with the following
fields:
  * bundle_location: The location within the bundle to sign this artifact. This is typically based
      on location_enum values, and in that case will be resolved to the relative path of the
      bundle root when writing out the JSON for the dossier.
  * bundle_filename: The file name of the artifact to be signed.
  * dossier_file: The dossier zip file that provides context and inputs for signing.
  * user_defined_location: Whether the bundle_location was specified by the user. i.e. if the
      location was defined through "additional_contents". If true, the `bundle_location` will be
      a custom relative path within the bundle contents to the artifact to sign, which will be used
      directly when generating the JSON for the dossier.
""",
    },
)
