# Copyright 2024, The Android Open Source Project
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

"""MetricsAgent is a singleton class that collects metrics for optimized build."""

from enum import Enum
import time
import metrics_pb2
import os
import logging


class MetricsAgent:
  _SOONG_METRICS_PATH = 'logs/soong_metrics'
  _DIST_DIR = 'DIST_DIR'
  _instance = None

  def __init__(self):
    raise RuntimeError(
        'MetricsAgent cannot be instantialized, use instance() instead'
    )

  @classmethod
  def instance(cls):
    if not cls._instance:
      cls._instance = cls.__new__(cls)
      cls._instance._proto = metrics_pb2.OptimizedBuildMetrics()
      cls._instance._init_proto()
      cls._instance._target_results = dict()

    return cls._instance

  def _init_proto(self):
    self._proto.analysis_perf.name = 'Optimized build analysis time.'
    self._proto.packaging_perf.name = 'Optimized build total packaging time.'

  def analysis_start(self):
    self._proto.analysis_perf.start_time = time.time_ns()

  def analysis_end(self):
    self._proto.analysis_perf.real_time = (
        time.time_ns() - self._proto.analysis_perf.start_time
    )

  def packaging_start(self):
    self._proto.packaging_perf.start_time = time.time_ns()

  def packaging_end(self):
    self._proto.packaging_perf.real_time = (
        time.time_ns() - self._proto.packaging_perf.start_time
    )

  def report_optimized_target(self, name: str):
    target_result = metrics_pb2.OptimizedBuildMetrics.TargetOptimizationResult()
    target_result.name = name
    target_result.optimized = True
    self._target_results[name] = target_result

  def report_unoptimized_target(self, name: str, optimization_rationale: str):
    target_result = metrics_pb2.OptimizedBuildMetrics.TargetOptimizationResult()
    target_result.name = name
    target_result.optimization_rationale = optimization_rationale
    target_result.optimized = False
    self._target_results[name] = target_result

  def target_packaging_start(self, name: str):
    target_result = self._target_results.get(name)
    target_result.packaging_perf.start_time = time.time_ns()
    self._target_results[name] = target_result

  def target_packaging_end(self, name: str):
    target_result = self._target_results.get(name)
    target_result.packaging_perf.real_time = (
        time.time_ns() - target_result.packaging_perf.start_time
    )

  def add_target_artifact(
      self,
      target_name: str,
      artifact_name: str,
      size: int,
      included_modules: set[str],
  ):
    target_result = self.target_results.get(target_name)
    artifact = (
        metrics_pb2.OptimizedBuildMetrics.TargetOptimizationResult.OutputArtifact()
    )
    artifact.name = artifact_name
    artifact.size = size
    for module in included_modules:
      artifact.included_modules.add(module)
    target_result.output_artifacts.add(artifact)

  def end_reporting(self):
    for target_result in self._target_results.values():
      self._proto.target_result.append(target_result)
    soong_metrics_proto = metrics_pb2.MetricsBase()
    # Read in existing metrics that should have been written out by the soong
    # build command so that we don't overwrite them.
    with open(os.path.join(os.environ[self._DIST_DIR], self._SOONG_METRICS_PATH), 'rb') as f:
      soong_metrics_proto.ParseFromString(f.read())
    soong_metrics_proto.optimized_build_metrics.CopyFrom(self._proto)
    logging.info(soong_metrics_proto)
    with open(os.path.join(os.environ[self._DIST_DIR], self._SOONG_METRICS_PATH), 'wb') as f:
      f.write(soong_metrics_proto.SerializeToString())
