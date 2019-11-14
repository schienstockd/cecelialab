# ARG BASE_CONTAINER=tensorflow/tensorflow:1.14.0-gpu-py3
ARG BASE_CONTAINER=tensorflow/tensorflow:1.8.0-gpu-py3
FROM $BASE_CONTAINER

LABEL maintainer="Dominik Schienstock <schienstockd@student.unimelb.edu.au>"

# Run all as user to avoid root
ENV HOME=/home/$NB_USER
ARG NB_USER="rotund"
ARG NB_UID="1000"
ARG NB_GID="100"

###
# START Build jupyterlab
# Adapted from Jupyter notebook from base, minimal, scipy, datascience
# https://github.com/jupyter/docker-stacks
#
# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
###
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get -yq dist-upgrade \
 && apt-get install -yq --no-install-recommends \
    wget \
    bzip2 \
    ca-certificates \
    sudo \
    locales \
    fonts-liberation \
    run-one \
    build-essential \
    git \
    jed \
    libsm6 \
    libxext-dev \
    libxrender1 \
    lmodern \
    netcat \
    pandoc \
    python-dev \
    texlive-fonts-extra \
    texlive-fonts-recommended \
    texlive-generic-recommended \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-xetex \
    tzdata \
    unzip \
    # For matplotlib animations
    ffmpeg \
    # For R
    fonts-dejavu \
    gfortran \
    gcc \
 && rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Configure environment
ENV CONDA_DIR=/opt/conda \
  SHELL=/bin/bash \
  NB_USER=$NB_USER \
  NB_UID=$NB_UID \
  NB_GID=$NB_GID \
  LC_ALL=en_US.UTF-8 \
  LANG=en_US.UTF-8 \
  LANGUAGE=en_US.UTF-8
ENV PATH=$CONDA_DIR/bin:$PATH \
  HOME=/home/$NB_USER

# Add a script that we will use to correct permissions after running certain commands
ADD fix-permissions /usr/local/bin/fix-permissions

# Enable prompt color in the skeleton .bashrc before creating the default NB_USER
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc

# Create NB_USER with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER:$NB_GID $CONDA_DIR && \
    chmod g+w /etc/passwd && \
    fix-permissions $HOME && \
    fix-permissions "$(dirname $CONDA_DIR)"

USER $NB_UID
WORKDIR $HOME

# Install conda as user and check the md5 sum provided on the download site
ENV MINICONDA_VERSION=4.7.12 \
    CONDA_VERSION=4.7.12

RUN cd /tmp && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    echo "0dba759b8ecfc8948f626fa18785e3d8 *Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh" | md5sum -c - && \
    /bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    echo "conda ${CONDA_VERSION}" >> $CONDA_DIR/conda-meta/pinned && \
    $CONDA_DIR/bin/conda config --system --prepend channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    $CONDA_DIR/bin/conda config --system --set show_channel_urls true && \
    $CONDA_DIR/bin/conda install --quiet --yes conda && \
    $CONDA_DIR/bin/conda update --all --quiet --yes && \
    conda list python | grep '^python ' | tr -s ' ' | cut -d '.' -f 1,2 | sed 's/$/.*/' >> $CONDA_DIR/conda-meta/pinned && \
    conda clean --all -f -y && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Install Tini which takes care of killing zombie processes
RUN conda install --quiet --yes 'tini=0.18.0' && \
    conda list tini | grep tini | tr -s ' ' | cut -d ' ' -f 1,2 >> $CONDA_DIR/conda-meta/pinned && \
    conda clean --all -f -y && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Install Jupyter Notebook, Lab, and Hub
# Generate a notebook server config
# Cleanup temporary files
# Correct permissions
# Do all this in a single RUN command to avoid duplicating all of the
# files across image layers when the permissions change
RUN conda install --quiet --yes \
    'notebook=6.0.1' \
    'jupyterhub=1.0.0' \
    'jupyterlab=1.1.4' && \
    conda clean --all -f -y && \
    npm cache clean --force && \
    jupyter notebook --generate-config && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Install Python 3 packages
RUN conda install --quiet --yes \
    'beautifulsoup4' \
    'conda-forge::blas=*=openblas' \
    'bokeh' \
    'cloudpickle' \
    'cudatoolkit' \
    'cython' \
    'dask' \
    'dill' \
    'h5py' \
    'hdf5' \
    'ipywidgets' \
    'matplotlib-base' \
    'numba' \
    'numexpr' \
    'pandas' \
    'patsy' \
    'protobuf' \
    'scikit-image' \
    'scikit-learn' \
    'scipy' \
    'seaborn' \
    'spyder-kernels' \
    'sqlalchemy' \
    'statsmodels' \
    'sympy' \
    'vincent' \
    'xlrd' \
    && \
    conda clean --all -f -y && \
    # Activate ipywidgets extension in the environment that runs the notebook server
    jupyter nbextension enable --py widgetsnbextension --sys-prefix && \
    # Also activate ipywidgets extension for JupyterLab
    # Check this URL for most recent compatibilities
    # https://github.com/jupyter-widgets/ipywidgets/tree/master/packages/jupyterlab-manager
    jupyter labextension install @jupyter-widgets/jupyterlab-manager --no-build && \
    jupyter labextension install jupyterlab_bokeh --no-build && \
    jupyter lab build --dev-build=False && \
    npm cache clean --force && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    rm -rf /home/$NB_USER/.node-gyp && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Install facets which does not have a pip or conda package at the moment
# A way to visualise machine learning algorithms
RUN cd /tmp && \
    git clone https://github.com/PAIR-code/facets.git && \
    cd facets && \
    jupyter nbextension install facets-dist/ --sys-prefix && \
    cd && \
    rm -rf /tmp/facets && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Import matplotlib the first time to build the font cache.
ENV XDG_CACHE_HOME /home/$NB_USER/.cache/
RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot" && \
    fix-permissions /home/$NB_USER

USER root

# Julia dependencies
# install Julia packages in /opt/julia instead of $HOME
ENV JULIA_DEPOT_PATH=/opt/julia
ENV JULIA_PKGDIR=/opt/julia
ENV JULIA_VERSION=1.2.0

RUN mkdir /opt/julia-${JULIA_VERSION} && \
    cd /tmp && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/`echo ${JULIA_VERSION} | cut -d. -f 1,2`/julia-${JULIA_VERSION}-linux-x86_64.tar.gz && \
    echo "926ced5dec5d726ed0d2919e849ff084a320882fb67ab048385849f9483afc47 *julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | sha256sum -c - && \
    tar xzf julia-${JULIA_VERSION}-linux-x86_64.tar.gz -C /opt/julia-${JULIA_VERSION} --strip-components=1 && \
    rm /tmp/julia-${JULIA_VERSION}-linux-x86_64.tar.gz
RUN ln -fs /opt/julia-*/bin/julia /usr/local/bin/julia

# Show Julia where conda libraries are \
RUN mkdir /etc/julia && \
    echo "push!(Libdl.DL_LOAD_PATH, \"$CONDA_DIR/lib\")" >> /etc/julia/juliarc.jl && \
    # Create JULIA_PKGDIR \
    mkdir $JULIA_PKGDIR && \
    chown $NB_USER $JULIA_PKGDIR && \
    fix-permissions $JULIA_PKGDIR

# Switch back to user
USER $NB_UID

# R packages including IRKernel which gets installed globally.
RUN conda install --quiet --yes \
    'r-base' \
    'r-care' \
    'r-crayon' \
    'r-devtools' \
    'r-forecast' \
    'r-hexbin' \
    'r-htmltools' \
    'r-htmlwidgets' \
    'r-irkernel' \
    'r-nycflights13' \
    'r-plyr' \
    'r-randomforest' \
    'r-rcurl' \
    'r-reshape2' \
    'r-rmarkdown' \
    'r-rsqlite' \
    'r-shiny' \
    'r-sparklyr' \
    'r-tidyverse' \
    'rpy2' \
    && \
    conda clean --all -f -y && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Add Julia packages. Only add HDF5 if this is not a test-only build since
# it takes roughly half the entire build time of all of the images on Travis
# to add this one package and often causes Travis to timeout.
#
# Install IJulia as user and then move the kernelspec out
# to the system share location. Avoids problems with runtime UID change not
# taking effect properly on the .local folder in the jovyan home dir.
RUN julia -e 'import Pkg; Pkg.update()' && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("HDF5")') && \
    julia -e "using Pkg; pkg\"add IJulia\"; pkg\"precompile\"" && \
    # move kernelspec out of home \
    mv $HOME/.local/share/jupyter/kernels/julia* $CONDA_DIR/share/jupyter/kernels/ && \
    chmod -R go+rx $CONDA_DIR/share/jupyter && \
    rm -rf $HOME/.local && \
    fix-permissions $JULIA_PKGDIR $CONDA_DIR/share/jupyter
###
# END Build jupyterlab
###

###
# START Cytokit
# Adopted from https://github.com/hammerlab/cytokit
###
# Switch back to root
USER root

ARG CYTOKIT_REPO_URL="https://github.com/hammerlab/cytokit.git"
ARG BASE_DIR=/cytokit
ARG SIM_DIR=$BASE_DIR/lab/sim
ARG REPO_DIR=$BASE_DIR/lab/repos
ARG DATA_DIR=$BASE_DIR/lab/data
ARG CYTOKIT_REPO_DIR=$REPO_DIR/cytokit

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

RUN mkdir -p $LAB_DIR $REPO_DIR $DATA_DIR $SIM_DIR

RUN apt-get update && apt-get install -y --no-install-recommends git vim wget
RUN pip install --upgrade pip

# OpenCV package dependencies and tk matplotlib backend
RUN apt-get install -y libsm6 libxext6 libfontconfig1 libxrender1 python3-tk

######################
# Env Initialization #
######################

COPY cytokit-requirements.txt /tmp/
RUN pip --no-cache-dir install --requirement /tmp/cytokit-requirements.txt

# TO FIX: Create cytokit with the runtime user
# Error during build: fatal: could not create work tree dir 'cytokit': Permission denied
# USER $NB_UID

# Clone cytokit repo
RUN cd $REPO_DIR && git clone $CYTOKIT_REPO_URL

# Add any source directories for development to python search path
RUN mkdir -p $(python -m site --user-site) && \
    echo "$CYTOKIT_REPO_DIR/python/pipeline" > $(python -m site --user-site)/local.pth && \
    echo "$CYTOKIT_REPO_DIR/python/notebooks/src" >> $(python -m site --user-site)/local.pth && \
    echo "$CYTOKIT_REPO_DIR/python/applications" >> $(python -m site --user-site)/local.pth

# Switch back to root
USER root

#############
# Frontends #
#############

# Install itkwidgets extension
RUN mkdir $REPO_DIR/.nodeenv && \
    cd $REPO_DIR/.nodeenv && \
    pip install nodeenv && \
    nodeenv jupyterlab && \
    . jupyterlab/bin/activate && \
    pip install itkwidgets && \
    jupyter labextension install @jupyter-widgets/jupyterlab-manager itk-jupyter-widgets

################
# CellProfiler #
################
# This is for cell segmentation in 2D only
# Once you have another method I would drop this section

# Create symbolic link for CP installation
RUN ln -s $CONDA_DIR/etc/profile.d/conda.sh /etc/profile.d/conda.sh

# Install CellProfiler
RUN /bin/bash -c 'source /etc/profile.d/conda.sh && conda create -n cellprofiler python=2.7' && \
    apt-get update && \
    apt-get install -y openjdk-8-jdk libmysqlclient-dev
# Clone the repo, pin the version, and leave install as separate step
RUN cd $REPO_DIR && \
    git clone https://github.com/CellProfiler/CellProfiler.git && \
    cd CellProfiler && \
    git checkout v3.1.8
# Install numpy before CP b/c as of 07/2019, CP has a minimum numpy version but not a max requirement
# and the numpy>=1.17.x drops support for python 2 (causing errors in the CP install if not set to <1.17 first)
RUN cd $REPO_DIR/CellProfiler && \
    /bin/bash -c 'source /etc/profile.d/conda.sh && conda activate cellprofiler && \
    pip install numpy==1.16.4 PyYAML==3.13 tifffile==2019.7.2 && pip install -e .'
# Install CP kernel for jupyter (the pinned versions are necessary to avoid pyzmq errors for new kernel)
RUN /bin/bash -c 'source /etc/profile.d/conda.sh && conda activate cellprofiler && \
    pip install ipykernel==4.10.0 pyzmq==18.0.2 && \
    python -m ipykernel install --user --name cellprofiler --display-name "Python (CP)"'

#########
# Login #
#########

WORKDIR "/lab"

ENV CYTOKIT_SIM_DIR $SIM_DIR
ENV CYTOKIT_DATA_DIR $DATA_DIR
ENV CYTOKIT_REPO_DIR $CYTOKIT_REPO_DIR
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/jre
ENV SHELL /bin/bash

# Eliminate these warnings globally: FutureWarning: Conversion of the second argument of issubdtype from
# `float` to `np.floating` is deprecated. In future, it will be treated as `np.float64 == np.dtype(float).type`
# See here for discussion: https://github.com/h5py/h5py/issues/961
ENV PYTHONWARNINGS "ignore::FutureWarning:h5py"

###
# END Cytokit
###

###
# START cecelialab
###
# Switch to root
USER root

ARG CECELIA_REPO_URL="https://github.com/schienstockd/cecelia.git"

# GPU test script
COPY gpu-test.py $HOME/
RUN fix-permissions $HOME/

###
# END cecelialab
###

# Configure container startup
RUN chmod a+x $CYTOKIT_REPO_DIR/python/pipeline/cytokit/cli/main.py && \
    ln -s $CYTOKIT_REPO_DIR/python/pipeline/cytokit/cli/main.py /usr/local/bin/cytokit

EXPOSE 8888
ENTRYPOINT ["tini", "-g", "--"]
CMD ["start-notebook.sh"]

# Add local files as late as possible to avoid cache busting
COPY start.sh /usr/local/bin/
COPY start-notebook.sh /usr/local/bin/
COPY start-singleuser.sh /usr/local/bin/
COPY jupyter_notebook_config.py /etc/jupyter/

# Fix permissions on /etc/jupyter as root
USER root
RUN fix-permissions /etc/jupyter/

USER $NB_UID
