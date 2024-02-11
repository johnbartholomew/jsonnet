# Copyright 2015 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

CMAKE ?= cmake
CMAKE_BUILD_DIR ?= ./build

default: jsonnet jsonnetfmt

all:
	$(CMAKE) -B "$(CMAKE_BUILD_DIR)" && $(CMAKE) --build "$(CMAKE_BUILD_DIR)" --target all

install:
	$(CMAKE) -B "$(CMAKE_BUILD_DIR)" && $(CMAKE) --build "$(CMAKE_BUILD_DIR)" --target install

# test: jsonnet jsonnetfmt libjsonnet.so libjsonnet_test_snippet libjsonnet_test_file libjsonnet_test_locale
# 	./tests.sh

reformat:
	clang-format -i -style=file **/*.cpp **/*.h

test-formatting:
	clang-format -Werror --dry-run -style=file **/*.cpp **/*.h

# Commandline executable.
jsonnet:
	$(CMAKE) -B "$(CMAKE_BUILD_DIR)" && $(CMAKE) --build "$(CMAKE_BUILD_DIR)" --target jsonnet && cp "$(CMAKE_BUILD_DIR)"/jsonnet "$@"

# Commandline executable (reformatter).
jsonnetfmt:
	$(CMAKE) -B "$(CMAKE_BUILD_DIR)" && $(CMAKE) --build "$(CMAKE_BUILD_DIR)" --target jsonnetfmt && cp "$(CMAKE_BUILD_DIR)"/jsonnetfmt "$@"

clean:
	rm -rvf "$(CMAKE_BUILD_DIR)"

.PHONY: default all install clean reformat test-formatting
