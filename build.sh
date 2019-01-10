#!/bin/bash
set -x
set -e

CM_EXT_BRANCH=cm5-5.13.0

STREAMSETS_URL=http://10.250.190.182:8081/streamsets-datacollector-3.3.1.tgz
#STREAMSETS_MD5="6f84f5581f59838b632a75071a2157cc"
STREAMSETS_VERSION=3.3.1

streamsets_archive="$( basename $STREAMSETS_URL )"
streamsets_folder="$( basename $streamsets_archive .tgz )"
streamsets_parcel_folder="STREAMSETS_DATACOLLECTOR-${STREAMSETS_VERSION}"
streamsets_parcel_name="${streamsets_parcel_folder}-el7.parcel"
streamsets_built_folder="${streamsets_parcel_folder}_build"

function build_cm_ext {

  #Checkout if dir does not exist
  if [ ! -d cm_ext ]; then
    git clone https://github.com/cloudera/cm_ext.git
  fi
  if [ ! -f cm_ext/validator/target/validator.jar ]; then
    cd cm_ext
    git checkout "$CM_EXT_BRANCH"
    mvn package
    cd ..
  fi
}

function get_streamsets {
  if [ ! -f "$streamsets_archive" ]; then
    wget $STREAMSETS_URL
  fi
#  streamsets_md5="$( md5sum $streamsets_archive | cut -d' ' -f1 )"
#  if [ "$streamsets_md5" != "$STREAMSETS_MD5" ]; then
#    echo ERROR: md5 of $streamsets_archive is not correct
#    exit 1
#  fi
  if [ ! -d "$streamsets_folder" ]; then
    tar -xzf $streamsets_archive
  fi
}

function build_streamsets_parcel {
  if [ -f "$streamsets_built_folder/$streamsets_parcel_name" ] && [ -f "$streamsets_built_folder/manifest.json" ]; then
    return
  fi
  if [ ! -d $streamsets_parcel_folder ]; then
    get_streamsets
    mv $streamsets_folder $streamsets_parcel_folder
  fi
  cp -r streamsets-parcel-src/meta $streamsets_parcel_folder
  sed -i -e "s/%VERSION%/$STREAMSETS_VERSION/" ./$streamsets_parcel_folder/meta/parcel.json
  java -jar cm_ext/validator/target/validator.jar -d ./$streamsets_parcel_folder
  mkdir -p $streamsets_built_folder
  tar zcvhf ./$streamsets_built_folder/$streamsets_parcel_name $streamsets_parcel_folder --owner=root --group=root
  java -jar cm_ext/validator/target/validator.jar -f ./$streamsets_built_folder/$streamsets_parcel_name
  python cm_ext/make_manifest/make_manifest.py ./$streamsets_built_folder
}

function build_streamsets_csd {
  JARNAME=STREAMSETS-${STREAMSETS_VERSION}.jar
  if [ -f "$JARNAME" ]; then
    return
  fi
  java -jar cm_ext/validator/target/validator.jar -s ./streamsets-csd-src/descriptor/service.sdl

  jar -cvf ./$JARNAME -C ./streamsets-csd-src .
}

case $1 in
clean)
  if [ -d cm_ext ]; then
    rm -rf cm_ext
  fi
  ;;
parcel)
  build_cm_ext
 build_streamsets_parcel
  ;;
csd)
  build_streamsets_csd
  ;;
*)
  echo "Usage: $0 [parcel|csd|clean]"
  ;;
esac
