#!/bin/bash

set -eu -o pipefail

project="multiplane"

autobuild="alpine debian"
scratch_variant="alpine"

cwd="$(dirname "$0")"
template_dir="$cwd/templates"
dockerfile_dir="$cwd/docker-images"

#If there is no ruby available install it
if ! which ruby 2>&1 > /dev/null; then
  alias ruby="docker run --rm -u $(id -u) -v "${PWD}":/usr/src/myapp -w /usr/src/myapp ruby:2.5-alpine ruby"
fi

semver_re='[^0-9]*\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*\)\([0-9A-Za-z-]*\)'
iwantplate="ruby $template_dir/iwantplate.rb"
travis_matrix=""

for version in `${iwantplate} --list-versions --quiet | tr -d '\r'`; do
    for variant in `${iwantplate} --list-variants --quiet | tr -d '\r'`; do
        release=`echo $version | sed -e "s/$semver_re/\1.\2/"`
        echo "multiplane:${release} (${version}): ${variant}"
        mkdir -p ${dockerfile_dir}/${release}/${variant}
        sh ${iwantplate} -V ${variant} -v ${version} > ${dockerfile_dir}/${release}/${variant}/Dockerfile
        #sh ${iwantplate} -s -V ${variant} -v ${version} > ${dockerfile_dir}/${release}/${variant}/Manifest &
        if echo ${autobuild} | grep -q "$variant"; then
            travis_matrix="${travis_matrix} - VERSION=${release} VARIANT=${variant}\n"
        fi

        if [ "${variant}" = "${scratch_variant}" ]; then
            echo "multiplane:${release} (${version}): scratch (${scratch_variant})"
            mkdir -p ${dockerfile_dir}/${release}/scratch
            sh ${iwantplate} -V ${variant} -v ${version} -m > ${dockerfile_dir}/${release}/scratch/Dockerfile &
            sh ${iwantplate} -s -V ${variant} -v ${version} > ${dockerfile_dir}/${release}/${variant}/Manifest &
            travis_matrix="${travis_matrix} - VERSION=${release} VARIANT=scratch\n"
        fi;
    done
done
wait

#sed -e "s/%%VERSIONS%%/${travis_matrix}/" ${template_dir}/travis.template > .travis.yml

