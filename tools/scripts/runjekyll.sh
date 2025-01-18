#!/bin/bash

# Run jekyll in a pod.

working_dir=/memtmp/docdoc
jekyll_cmd="$1"

PODMAN_RUN_ARGS=
JEKYLL_ARGS=

case "$jekyll_cmd" in
  build) ;;
  serve)
        PODMAN_RUN_ARGS="$PODMAN_RUN_ARGS --publish=127.0.0.1:4000:4000/tcp"
        JEKYLL_ARGS="$JEKYLL_ARGS --host 0.0.0.0"
        ;;
  *)    >&2 echo "unknown/invalid jekyll command '$jekyll_cmd'"
        exit 1
        ;;
esac

[[ -e "${working_dir}" ]] || mkdir "${working_dir}"

exec podman run --rm -it \
  -v=.:/srcdir:ro \
  ${PODMAN_RUN_ARGS} \
  -v="${working_dir}":/outdir:rw \
  localhost/myjekyll:latest \
  jekyll "${jekyll_cmd}" --disable-disk-cache -s /srcdir/doc -d /outdir ${JEKYLL_ARGS}
