/*
 * Copyright 2014 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package jvm;

import jvm.other.Other;

/** Foo class. */
public final class Foo {
//               ^  ^ foo_def

  void testParameterInfo() {
    // Test signature help for type parameters.

    Bar<Integer, Double> b = new Bar<>();
    //                               ^ ctor
    //     ^ decl_1
    //              ^ decl_2
    System.out.println(b);

    // step at ctor
    // workspace.waitForReady()
    // paraminfo.trigger()
    // assert paraminfo.items.filter(
    //  label="K extends Number, V extends Number",
    //  selection="K extends Number",
    // )

    // step at decl_1
    // workspace.waitForReady()
    // paraminfo.trigger()
    // assert paraminfo.items.filter(
    //  label="K extends Number, V extends Number",
    //  selection="K extends Number",
    // )

    // step at decl_2
    // workspace.waitForReady()
    // paraminfo.trigger()
    // assert paraminfo.items.filter(
    //  label="K extends Number, V extends Number",
    //  selection="V extends Number",
    // )

    // Test signature help for constructor parameters.

    Other other = new Other(123, "foo");
    //                       ^ param_1
    //                             ^ param_2
    System.out.println(other);

    // step at param_1
    // workspace.waitForReady()
    // paraminfo.trigger()
    // assert paraminfo.items.filter(
    //  label="\\(int first, String second\\)",
    //  selection="int first",
    // )

    // step at param_2
    // workspace.waitForReady()
    // paraminfo.trigger()
    // assert paraminfo.items.empty()
  }

  void testCompletion() {
    Bar<Integer, Double> b = new Bar<>();
    System.out.println(b);

    // ^

    // step
    // ; Test completion on types from the same package.
    // workspace.waitForReady()
    // type("b.")
    // completion.trigger()
    // assert completion.items.filter(label="foo.*")
    // delline()

    Other other = new Other(1, "foo");
    System.out.println(other);

    // ^

    // step
    // ; Test completion on types from a different package.
    // workspace.waitForReady()
    // type("other.")
    // completion.trigger()
    // apply(completion.items.filter(label="other.*").first())
    // type(".")
    // completion.trigger()
    // apply(completion.items.filter(label="other.*").first())
    // delline()
  }

  void testDiagnostics() {

    // ^

    // step
    // ; Test diagnostics about wrong type argument bounds.
    // workspace.waitForReady()
    // type("Bar<String, Double> b;")
    // assert diagnostics.items.filter(
    //  message="type argument .* is not within bounds .*",
    //  code="compiler.err.not.within.bounds",
    // )
    // delline()
  }
}
