#!/bin/bash

# get Dockerfiles from Jupyter project
# git clone https://github.com/jupyter/docker-stacks.git
cd docker-stacks
git pull
cd ..

# copy files/directories from base-notebook
cp -rf ./docker-stacks/base-notebook/test ./
cp ./docker-stacks/base-notebook/*.sh ./
cp ./docker-stacks/base-notebook/*.py ./
cp ./docker-stacks/base-notebook/fix-permissions ./

# define base image
cat Dockerfile.base > Dockerfile.tmp

# get Dockerfile definitions and merge together
jpt_dockerfiles=(
	"base"
	"minimal"
	"scipy"
	"datascience"
)

echo "# ! FROM https://github.com/jupyter/docker-stacks" >> Dockerfile.tmp

for i in "${jpt_dockerfiles[@]}"
do
   cat docker-stacks/$i-notebook/Dockerfile | grep -v "FROM.*" >> Dockerfile.tmp
done

# define cecelialab part
cat Dockerfile.cecelialab >> Dockerfile.tmp

# create Dockerfile
mv Dockerfile.tmp Dockerfile
