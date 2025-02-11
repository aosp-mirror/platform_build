#!/bin/bash
aconfig create-cache \
    --package record_finalized_flags.test \
    --container system \
    --declarations flags.declarations \
    --values flags.values \
    --cache flags.protobuf
