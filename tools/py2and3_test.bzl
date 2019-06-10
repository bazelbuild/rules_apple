# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Wrapper to test under python 2 and 3."""

def py2and3_test(**kwargs):
    """Wrapper to test under python 2 and 3.

    NOTE: This is only to be used within the rules_apple tests, it is not
    for use from other places as it will eventually go away.

    Args:
      **kwargs: py_test keyword arguments.
    """
    name = kwargs.pop("name")
    py2_name = name + ".python2"
    py3_name = name + ".python3"

    main = kwargs.pop("main", name + ".py")
    base_tags = kwargs.pop("tags", [])

    native.py_test(
        name = py2_name,
        python_version = "PY2",
        main = main,
        tags = base_tags + ["python2"],
        **kwargs
    )

    native.py_test(
        name = py3_name,
        python_version = "PY3",
        main = main,
        tags = base_tags + ["python3"],
        **kwargs
    )

    suite_kwargs = {}
    if kwargs.get("visibility"):
        suite_kwargs["visibility"] = kwargs.get("visibility")

    native.test_suite(
        name = name,
        tags = base_tags,
        tests = [py2_name, py3_name],
        **suite_kwargs
    )
