# Adapted from the following Dockerfiles:
# https://github.com/jupyter/docker-stacks
# https://github.com/hammerlab/cytokit
ARG BASE_CONTAINER=tensorflow/tensorflow:1.14.0-gpu-py3
FROM $BASE_CONTAINER

LABEL maintainer="Dominik Schienstock <schienstockd@student.unimelb.edu.au>"

# Add git repositories
ARG CYTOKIT_REPO_URL="https://github.com/hammerlab/cytokit.git"
ARG CECELIA_REPO_URL="https://github.com/schienstockd/cecelia.git"

# Run all as user to avoid root
ENV HOME=/home/$NB_USER
ARG NB_USER="rotund"
ARG NB_UID="1000"
ARG NB_GID="100"

USER $NB_UID
WORKDIR $HOME

# GPU test script
COPY gpu-test.py /tmp/

# Run command at the start of the container
CMD /tmp/gpu-test.py
