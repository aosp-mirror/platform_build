// Copyright (C) 2024 The Android Open Source Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <vector>

#include "foo.pb.h"

using ide_query::prober_scripts::ProtoMsg;

void Foo(int x, double y) {}
float Foo(float x, float y) { return 0.0f; }

void TestCompletion() {
  // Test completion on protos and fuzzy matching of completion suggestions.

  ProtoMsg foo;

  // ^

  // step
  // workspace.waitForReady()
  // type("f")
  // completion.trigger()
  // assert completion.items.filter(label="foo")
  // delline()
  // type("foo.sf")
  // completion.trigger()
  // assert completion.items.filter(
  //  label="some_field.*",
  //  insertText="some_field.*",
  // )
  // delline()

  std::vector<int> v;

  // ^

  // step
  // workspace.waitForReady()
  // type("v.push")
  // completion.trigger()
  // assert completion.items.filter(label="push_back.*")
  // delline()
}

void TestNavigation() {
  std::vector<int> ints;
  //               |   | ints
  //      ^

  // step
  // ; Test navigation to definition on STL types.
  // workspace.waitForReady()
  // navigation.trigger()
  // assert navigation.items.filter(path=".*/vector")

  ints.push_back(0);
  // ^

  // step
  // ; Test navigation to definition on local symbols.
  // workspace.waitForReady()
  // navigation.trigger()
  // assert navigation.items.filter(path=".*/general.cc", range=ints)

  ProtoMsg msg;
  msg.set_some_field(0);
  //          ^

  // step
  // ; Test navigation to definition on proto fields. We do not check for a
  // ; specific target as it can be in generated code.
  // workspace.waitForReady()
  // navigation.trigger()
  // assert navigation.items
}

void TestParameterInfo() {
  std::vector<int> v;
  v.push_back(0);
  //          ^

  // step
  // ; Test the signature help for STL functions. We do not check for a specific
  // ; text as it can be implementation-dependent.
  // workspace.waitForReady()
  // paraminfo.trigger()
  // assert paraminfo.items

  Foo(0, 0.0);
  //      ^

  // step
  // ; Test the signature help for the function 'Foo' having two overloads.
  // workspace.waitForReady()
  // paraminfo.trigger()
  // assert paraminfo.items.filter(
  //  active=true,
  //  label="Foo\\(int x, double y\\) -> void",
  //  selection="double y",
  // )
  // assert paraminfo.items.filter(
  //  active=false,
  //  label="Foo\\(float x, float y\\) -> float",
  // )
}

int main() { return 0; }
