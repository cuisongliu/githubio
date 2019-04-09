---
title: ipvs永久开启方案
slug: ipvs
date: 2019-04-08
categories:
- ipvs
tags:
- ipvs
autoThumbnailImage: true
metaAlignment: center

---
主要讲述如果使用脚本永久开启ipvs模块。
<!--more-->

> [kubernetes集群三步安装](https://sealyun.com/pro/products/)


{{< codeblock  "ipvs.sh" >}}
#!/bin/bash
cat << EOF > /etc/sysconfig/modules/ipvs.modules 
#!/bin/bash
ipvs_modules_dir="/usr/lib/modules/\`uname -r\`/kernel/net/netfilter/ipvs"
for i in \`ls \$ipvs_modules_dir | sed  -r 's#(.*).ko.xz#\1#'\`; do
    /sbin/modinfo -F filename \$i  &> /dev/null
    if [ \$? -eq 0 ]; then
        /sbin/modprobe \$i
    fi
done
EOF
chmod +x /etc/sysconfig/modules/ipvs.modules 
bash /etc/sysconfig/modules/ipvs.modules
{{< /codeblock >}}
