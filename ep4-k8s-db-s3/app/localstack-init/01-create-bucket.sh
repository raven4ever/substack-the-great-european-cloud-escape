#!/bin/bash
set -euo pipefail

awslocal s3 mb "s3://${APP_BUCKET_NAME:-animal-images}"
