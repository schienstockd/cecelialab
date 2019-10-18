# Adapted from the following Dockerfiles:
# https://github.com/jupyter/docker-stacks
# https://github.com/hammerlab/cytokit
ARG BASE_CONTAINER=tensorflow/tensorflow:1.14.0-gpu-py3
FROM $BASE_CONTAINER

ARG CYTOKIT_REPO_URL="https://github.com/hammerlab/cytokit.git"
ARG CECELIA_REPO_URL="https://github.com/schienstockd/cecelia.git"

ARG REPO_DIR=/lab/repos
ARG DATA_DIR=/lab/data
ARG CYTOKIT_REPO_DIR=$REPO_DIR/cytokit
ARG CECELIA_REPO_DIR=$REPO_DIR/cecelia

ENV LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    MINICONDA_VERSION=4.7.12 \
    PYTHON_VERSION=3.7.5

RUN mkdir -p $LAB_DIR $REPO_DIR $DATA_DIR $SIM_DIR

# Otherwise there will be prompts during install
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends git vim wget
RUN pip install --upgrade pip

# OpenCV package dependencies and tk matplotlib backend
RUN apt-get install -y libsm6 libxext6 libfontconfig1 libxrender1 python3-tk

######################
# Env Initialization #
######################

# Install conda and initialize primary environment
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate cecelia" >> ~/.bashrc && \
    /bin/bash -c 'source /etc/profile.d/conda.sh && conda create -n cecelia python=${PYTHON_VERSION}'
ENV PATH /opt/conda/envs/cytokit/bin:$PATH
RUN pip install --upgrade pip

# Install Python modules
COPY requirements.txt /tmp/
RUN pip --no-cache-dir install --requirement /tmp/requirements.txt

# Clone cytokit repo
RUN cd $REPO_DIR && git clone $CYTOKIT_REPO_URL

# Add any source directories for development to python search path
RUN mkdir -p $(python -m site --user-site) && \
    echo "$CYTOKIT_REPO_DIR/python/pipeline" > $(python -m site --user-site)/local.pth && \
    echo "$CYTOKIT_REPO_DIR/python/notebooks/src" >> $(python -m site --user-site)/local.pth && \
    echo "$CYTOKIT_REPO_DIR/python/applications" >> $(python -m site --user-site)/local.pth

#############
# Frontends #
#############

# Install itkwidgets extension
RUN mkdir $REPO_DIR/.nodeenv && \
    cd $REPO_DIR/.nodeenv && \
    nodeenv jupyterlab && \
    . jupyterlab/bin/activate && \
    jupyter labextension install @jupyter-widgets/jupyterlab-manager itk-jupyter-widgets

#########
# Login #
#########
WORKDIR "/lab"

ENV CYTOKIT_DATA_DIR $DATA_DIR
ENV CYTOKIT_REPO_DIR $CYTOKIT_REPO_DIR
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/jre
ENV SHELL /bin/bash

# Eliminate these warnings globally: FutureWarning: Conversion of the second argument of issubdtype from
# `float` to `np.floating` is deprecated. In future, it will be treated as `np.float64 == np.dtype(float).type`
# See here for discussion: https://github.com/h5py/h5py/issues/961
ENV PYTHONWARNINGS "ignore::FutureWarning:h5py"

# Create cli links at runtime instead of container buildtime due to source scripts being
# in repos mounted at runtime
CMD chmod a+x $CYTOKIT_REPO_DIR/python/pipeline/cytokit/cli/main.py && \
    ln -s $CYTOKIT_REPO_DIR/python/pipeline/cytokit/cli/main.py /usr/local/bin/cytokit && \
    jupyter lab --allow-root --ip=0.0.0.0
