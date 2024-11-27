#!/usr/bin/env bash

subscription-manager refresh
subscription-manager repos --enable rhel-8-for-x86_64-appstream-rpms
subscription-manager repos --enable rhel-8-for-x86_64-baseos-rpms
