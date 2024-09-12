#!/bin/bash

aprotoc --go_out=paths=source_relative:. cc_analyzer.proto
