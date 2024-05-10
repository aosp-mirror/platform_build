#!/bin/bash

aprotoc --go_out=paths=source_relative:. ide_query.proto
