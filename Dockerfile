ARG BASE_CONTAINER=nvidia/cuda:latest
ARG COPY_CONTAINER=jupyter/datascience-notebook:latest

FROM $BASE_CONTAINER
COPY --from=$COPY_CONTAINER

LABEL maintainer="Cecelia lab - cell-cell interaction analysis <schienstockd@student.unimelb.edu.au>"

# Install Tensorflow
#RUN conda install --quiet --yes \
#    'tensorflow=1.13*' \
#    'keras=2.2*' && \
#    conda clean --all -f -y && \
#    fix-permissions $CONDA_DIR && \
#    fix-permissions /home/$NB_USER

# Install Python modules
COPY requirements.txt /tmp/
RUN pip install --requirement /tmp/requirements.txt && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Install R libraries
# COPY install_biocmanager.R /tmp/
# COPY install_libraries.R /tmp/

# RUN Rscript /tmp/install_biocmanager.R
# RUN Rscript /tmp/install_libraries.R
