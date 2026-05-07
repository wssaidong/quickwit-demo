#!/bin/bash
set -e

echo "Installing Quickwit..."
curl -L https://install.quickwit.io | sh

echo "Downloading dataset..."
curl -sO https://quickwit-datasets-public.s3.amazonaws.com/stackoverflow.posts.transformed-10000.json

echo "Dev container ready!"
echo "Run: ./quickwit-*/quickwit run"
