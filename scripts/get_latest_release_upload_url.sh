#!/bin/bash

curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/newrelic/open-install-library/releases/latest | jq -r '.upload_url'
