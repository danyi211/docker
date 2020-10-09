
FROM ubuntu:18.04
LABEL ubuntu.version="18.04"
MAINTAINER Tom Eichlersmith <eichl008@umn.edu>

# The minimal argument is an attempt to decrease the size of the container
# by only including necessary packages/libraries for running ldmx-sw.
#   It is still in development
#
# The options are: "ON" or "OFF"
ARG MINIMAL=OFF
LABEL minimal="${MINIMAL}"

# First install any required dependencies from ubuntu repos
#   TODO clean up this dependency list
# Ongoing documentation for this list is in docs/ubuntu-packages.md
RUN apt-get update &&\
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y \
        binutils \
        ca-certificates \
        davix-dev \
        dcap-dev \
        dpkg-dev \
        fonts-freefont-ttf \
        g++-7 \
        gcc-7 \
        git \
        libafterimage-dev \
        libcfitsio-dev \
        libfcgi-dev \
        libfftw3-dev \
        libfreetype6-dev \
        libftgl-dev \
        libgfal2-dev \
        libgif-dev \
        libgl1-mesa-dev \
        libgl2ps-dev \
        libglew-dev \
        libglu-dev \
        libgraphviz-dev \
        libgsl-dev \
        libjpeg-dev \
        liblz4-dev \
        liblzma-dev \
        libmysqlclient-dev \
        libpcre++-dev \
        libpng-dev \
        libpq-dev \
        libpythia8-dev \
        libsqlite3-dev \
        libssl-dev \
        libtbb-dev \
        libtiff-dev \
        libx11-dev \
        libxext-dev \  
        libxft-dev \
        libxml2-dev \
        libxmu-dev \
        libxpm-dev \
        libz-dev \
        libzstd-dev \
        locales \
        make \
        python-dev \
        python-pip \
        python-numpy \
        python-tk \
        python3-dev \
        python3-pip \
        python3-numpy \
        python3-tk \
        srm-ifce-dev \
        unixodbc-dev \
        wget \
    && rm -rf /var/lib/apt/lists/* &&\
    python3 -m pip install --upgrade --no-cache-dir cmake

###############################################################################
# Install CERN's ROOT into the container
#
# Assumptions
#  - ROOT defined as a  tag/branch of ROOT's git source tree
#  - MINIMAL defined as either ON or OFF
#  - ROOTSYS defined as target install location
###############################################################################
ARG ROOT=v6-22-00-patches
LABEL root.version="${ROOT}"
ENV ROOTSYS /deps/cernroot
RUN mkdir cernroot &&\
    git clone -b ${ROOT} --single-branch https://github.com/root-project/root.git &&\
    mkdir /cernroot/build &&\
    cmake \
        -Dxrootd=OFF \
        -DCMAKE_CXX_STANDARD=17 \
        -Dminimal=${MINIMAL} \
        -DCMAKE_INSTALL_PREFIX=$ROOTSYS \
        -B /cernroot/build \
        -S /cernroot/root \
        &&\
    cmake \
        --build /cernroot/build \
        --target install \
    &&\
    rm -rf cernroot

################################################################################
# Install Xerces-C into container
#
# Assumptions
#  - XERCESC set to version matching an archived location of its source
#  - XercesC_DIR set to target installation location
################################################################################
ENV XercesC_DIR /deps/xerces-c
ARG XERCESC=3.2.3
LABEL xercesc.version="${XERCESC}"
RUN mkdir xerces-c && cd xerces-c &&\
    wget http://archive.apache.org/dist/xerces/c/3/sources/xerces-c-${XERCESC}.tar.gz &&\
    tar -zxvf xerces-c-*.tar.gz &&\
    cd xerces* && mkdir build && cd build &&\
    cmake -DCMAKE_INSTALL_PREFIX=$XercesC_DIR .. &&\
    make install &&\
    cd ../../../ && rm -rf xerces-c

###############################################################################
# Install Geant4 into the container
#
# Assumptions
#  - GEANT4 defined to be a branch/tag of geant4 or LDMX's fork of geant4
#  - XercesC_DIR set to install of Xerces-C
#  - G4DIR set to path where Geant4 should be installed
###############################################################################
ENV G4DIR /deps/geant4
ARG GEANT4=geant4-10.5-release
LABEL geant4.version="${GEANT4}"
RUN _geant4_remote="https://gitlab.cern.ch/geant4/geant4.git" &&\
    if echo "${GEANT4}" | grep -q "LDMX"; then \
        _geant4_remote="https://github.com/LDMX-Software/geant4.git"; \
    fi &&\
    git clone -b ${GEANT4} --single-branch ${_geant4_remote} &&\
    mkdir geant4/build &&\
    cmake \
        -DGEANT4_INSTALL_DATA=ON \
        -DGEANT4_USE_GDML=ON \
        -DGEANT4_INSTALL_EXAMPLES=OFF \
        -DXERCESC_ROOT_DIR=$XercesC_DIR \
        -DCMAKE_INSTALL_PREFIX=$G4DIR \
        -B geant4/build \
        -S geant4
        &&\
    cmake \
        --build geant4/build \
        --target install \
    &&\
    make install &&\
    rm -rf geant4

###############################################################################
# Installing DD4hep within the container build
#
# Assumptions
#  - ROOT installed at $ROOTSYS
#  - Geant4 installed at $G4DIR
#  - Xerces-C installed at $XercesC_DIR
#  - DD4HEP set to branch/tag name from GitHub repository
#  - $DD4hep_DIR set to install path
###############################################################################
ENV DD4hep_DIR /deps/dd4hep
ARG DD4HEP=v01-14-01
LABEL dd4hep.version="${DD4HEP}"
RUN git clone -b ${DD4HEP} --single-branch https://github.com/AIDASoft/DD4hep.git &&\
    export PYTHONPATH=$ROOTSYS/lib &&\
    export CLING_STANDARD_PCH=none &&\
    export LD_LIBRARY_PATH=$XercesC_DIR/lib:$ROOTSYS/lib:$G4DIR/lib:$LD_LIBRARY_PATH &&\
    export CMAKE_PREFIX_PATH=$XercesC_DIR:$ROOTSYS:$G4DIR &&\
    cmake \
        -DCMAKE_INSTALL_PREFIX=$DD4hep_DIR \
        -DBoost_NO_BOOST_CMAKE=ON \
        -DBUILD_TESTING=OFF \
        -DDD4HEP_USE_GEANT4=ON \
        -B DD4hep/build \
        -S DD4hep \
    &&\
    cmake \
        --build DD4hep/build \
        --target install \
    &&\
    rm -rf DD4hep

################################################################################
# Install Eigen headers into container
#
# Assumptions
#  - EIGEN set to branch/tag name from GitLab repository
#  - Eigen_DIR set to install path
################################################################################
ENV Eigen_DIR /deps/eigen
ARG EIGEN=3.3.8
LABEL eigen.version="${EIGEN}"
RUN git clone -b ${EIGEN} --single-branch https://gitlab.com/libeigen/eigen.git &&\
    cmake \
        -DCMAKE_INSTALL_PREFIX=$Eigen_DIR \
        -B eigen/build \
        -S eigen \
    &&\
    cmake \
        --build eigen/build \
        --target install \
    &&\
    rm -rf eigen

###############################################################################
# Install Boost into the container
#
# TODO: THe boost installed from this PPA seems to work with everything,
#       but cmake complains with piles of warnings.
# 
# Assumptions
#  - BOOST version of boost release available at the referenced PPA
###############################################################################
ARG BOOST=1.74
LABEL boost.version="${BOOST}"
RUN apt-get update &&\
    apt-get install -y \
        software-properties-common \
    &&\
    add-apt-repository ppa:mhier/libboost-latest &&\
    apt-get update &&\
    apt-get install -y libboost${BOOST}-dev &&\
    apt-get purge -y \
        software-properties-common \
    &&\
    apt-get autoremove -y

###############################################################################
# Install ACTS Common Tracking Software into the container
#
# Assumptions
#  - Eigen installed at Eigen_DIR
#  - ACTS_DIR set to install path
#  - ACTS set to branch/tag name of GitHub repository
#  - ROOTSYS set to ROOT install path
#  - G4DIR set to Geant4 install path
#  - XercesC_DIR set to xerces-c install path
#  - DD4hep_DIR set to DD4hep install path
###############################################################################
ENV ACTS_DIR /deps/acts
ARG ACTS=v1.1.0
LABEL acts.version="${ACTS}"
RUN git clone -b ${ACTS} --single-branch https://github.com/acts-project/acts &&\
    export PYTHONPATH=$ROOTSYS/lib &&\
    export CLING_STANDARD_PCH=none &&\
    export LD_LIBRARY_PATH=$XercesC_DIR/lib:$ROOTSYS/lib:$G4DIR/lib:$LD_LIBRARY_PATH &&\
    export CMAKE_PREFIX_PATH=$XercesC_DIR:$ROOTSYS:$G4DIR:$Eigen_DIR &&\
    mkdir acts/build &&\
    cmake \
        -DACTS_BUILD_PLUGIN_DD4HEP=ON \
        -DACTS_BUILD_EXAMPLES=OFF \
        -DEigen3_DIR=$Eigen_DIR/share/eigen3/cmake \
        -DCMAKE_INSTALL_PREFIX=$ACTS_DIR \
        -B acts/build \
        -S acts \
    &&\
    cmake \
        --build acts/build \
        --target install \
    &&\
    rm -rf acts

###############################################################################
# Extra python packages for analysis
#   
# Assumptions
#  - ROOTSYS is installation location of root
###############################################################################
RUN export PYTHONPATH=$ROOTSYS/lib &&\
    export CLING_STANDARD_PCH=none &&\
    export LD_LIBRARY_PATH=$XercesC_DIR/lib:$ROOTSYS/lib:$G4DIR/lib:$LD_LIBRARY_PATH &&\
    python3 -m pip install --upgrade --no-cache-dir \
        uproot \
        numpy \
        matplotlib \
        xgboost \
        sklearn &&\
    python -m pip install --upgrade --no-cache-dir \
        uproot \
        numpy \
        matplotlib \
        xgboost \
        sklearn

# clean up source and build files from apt-get
RUN rm -rf /tmp/* && apt-get clean && apt-get autoremove 

#copy over necessary running script which sets up environment
COPY ./ldmx.sh /home/
RUN chmod 755 /home/ldmx.sh

# add any ssl certificates to the container to trust
COPY ./certs/ /usr/local/share/ca-certificates
RUN update-ca-certificates

#run environment setup when docker container is launched and decide what to do from there
#   will require the environment variable LDMX_BASE defined
ENTRYPOINT ["/home/ldmx.sh"]
