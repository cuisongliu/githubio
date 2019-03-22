#!/bin/bash
set -x
git clone https://github.com/kakawait/hugo-tranquilpeak-theme.git themes/hugo-tranquilpeak-theme
hugo server  -t hugo-tranquilpeak-theme --buildDrafts --watch
