#!/bin/bash
kubectl create secret generic my-api-secret-literal --from-literal=url=https://my-secret-url-location.topsecret.com --from-literal=token='/x~Lhx\nAz!,;.Vk%[#n+";9p%jGF6['
