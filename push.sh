#!/bin/bash
set -x
git clone https://github.com/kakawait/hugo-tranquilpeak-theme.git themes/hugo-tranquilpeak-theme
hugo   -t hugo-tranquilpeak-theme

git clone git@github.com:cuisongliu/cuisongliu.github.io.git
cd cuisongliu.github.io
rm -rf *
cp -rf ../public/* .
git add .
git commit -am "auto shell commit by hugo"
git push   origin master
cd ../
rm -rf cuisongliu.github.io

git add .
git commit -am "auto shell commit by hugo"
git push   origin master
