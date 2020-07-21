---
title: kubernetes 之 admission webhook生成证书
slug: kubernetes/admission-webhook
date: 2020-07-21
categories:
- kubernetes
- admission
- webhook
tags:
- kubernetes
- webhook
autoThumbnailImage: true
metaAlignment: center
showPagination: false
---
本文主要讲解kubernetes的admission webhook双向认证证书生成流程。

<!--more-->

<!-- toc -->

> [kubernetes集群三步安装](https://sealyun.com/pro/products/)


{{< alert info >}}
其实就是使用kubernetes的csr生成证书：
- 自建一个私钥
- 根据自建私钥生成一个csr文件
- 把生成的csr提交给kubernetes的csr资源使用kubernetes进行证书签发(其实本质就是拿kubernetes的ca的证书进行签发的)
- 最后别忘记把ca证书设置给webhook资源的caBundle字段
{{< /alert >}}

### 手动签发证书

{{< alert warning >}}
这里需要注意一下: 需要根据部署的service的名称和namespace设置对应的name和namespace。
{{< /alert >}}

这里我们提前设置一下访问的service的名称是 webhook-svc所在的namespace是 webhook,所设置kubernetes的csr资源叫webhook-csr

#### 设置证书配置

{{< codeblock "csr.conf" "conf" "http://cuisongliu.github.io/2020/07/kubernetes/admission-webhook/#设置证书配置" "csr.conf" >}}

[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = webhook-svc
DNS.2 = webhook-svc.webhook
DNS.3 = webhook-svc.webhook.svc
{{< /codeblock >}}

#### 生成秘钥和csr文件

{{< codeblock "csr.bash" "bash" "http://cuisongliu.github.io/2020/07/kubernetes/admission-webhook/#生成秘钥和csr文件" "csr.bash" >}}

#!/bin/bash
openssl genrsa -out server-key.pem 2048
openssl req -new -key server-key.pem -subj "/CN=webhook-svc.webhook.svc" -days 36500 -out server.csr -config csr.conf

{{< /codeblock >}}

#### 使用kubernetes签发证书

{{< codeblock "csr-k8s.sh" "bash" "http://cuisongliu.github.io/2020/07/kubernetes/admission-webhook/#使用kubernetes签发证书" "csr-k8s.sh" >}}

#!/bin/bash
kubectl delete csr webhook-csr  2>/dev/null || true

cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: webhook-csr
spec:
  groups:
  - system:authenticated
  request: $(cat server.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

# 重新认证csr
kubectl certificate approve webhook-csr
# 这里需要重试几次,需要等kubernetes签发证书后才会有status信息
for x in $(seq 10); do
    serverCert=$(kubectl get csr webhook-csr -o jsonpath='{.status.certificate}')
    if [[ ${serverCert} != '' ]]; then
        break
    fi
    sleep 1
done

echo ${serverCert} | openssl base64 -d -A -out server-cert.pem

{{< /codeblock >}}

#### 设置ca证书给对应的webhook资源

这里需要把ca的base64值证书设置给对应的MutatingWebhookConfiguration和ValidatingWebhookConfiguration的caBundle字段。这里就不详细赘述了,说明一下ca证书如何获取。

{{< codeblock "ca-k8s.sh" "bash" "http://cuisongliu.github.io/2020/07/kubernetes/admission-webhook/#设置ca证书给对应的webhook资源" "ca-k8s.sh" >}}

#!/bin/bash
export caBundle=$(kubectl get configmap -n kube-system extension-apiserver-authentication -o=jsonpath='{.data.client-ca-file}' | base64 | tr -d '\n')
echo $caBundle

{{< /codeblock >}}

#### 手动签发证书的问题

{{< alert danger >}}
使用手动签发证书需要每次启动项目之前都要把证书准备好并设置到项目中去,如果证书更改就需要重新签发。比较麻烦，于是我们可以使用代码进行签发证书。
{{< /alert >}}

### 使用代码签发证书

{{< alert success >}}
其实流程跟手动签发流程基本一致:
- 读取秘钥中存储的私钥和csr(证书相关信息存储到秘钥中),若不存在自动生成证书(私钥和csr)并存储到秘钥中
- 根据生成的证书提交给kubernetes中进行ca证书签名出公钥信息并存储到秘钥中
- 读取ca证书并存储到秘钥中
- 根据ca证书修改对应的MutatingWebhookConfiguration和ValidatingWebhookConfiguration
- 读取出证书信息写入本地目录提供pod使用证书(需要在https的服务启动之前设置好)
{{< /alert >}}

{{< alert warning >}}
需要提前设置一下相关信息:
- service的名称和namespace分别为webhook-svc和webhook
- 存储的秘钥信息为webhook-secrets
- 设置的kubernetes的csr信息为webhook-csr
- MutatingWebhookConfiguration名称为webhook-mutate,ValidatingWebhookConfiguration为webhook-validate
- 写入的目录为 /etc/kubernetes/webhhok/tls
{{< /alert >}}

#### 生成证书数据
{{< codeblock "key.go" "go" "http://cuisongliu.github.io/2020/07/kubernetes/admission-webhook/#生成证书数据" "key.go" >}}
type CertConfig struct {
	CommonName   string
	Organization []string
	// AltNames contains the domain names and IP addresses that will be added
	// to the API Server's x509 certificate SubAltNames field. The values will
	// be passed directly to the x509.Certificate object.
	AltNames struct {
		DNSNames []string
		IPs      []net.IP
	}
}
// NewPrivateKey creates an RSA private key
func NewPrivateKey(keyType x509.PublicKeyAlgorithm) (crypto.Signer, error) {
	if keyType == x509.ECDSA {
		return ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	}
	return rsa.GenerateKey(rand.Reader, 2048)
}

func NewSigned(cfg CertConfig) (csr, keyPEM []byte, err error) {
	key, err := NewPrivateKey(x509.RSA)
	if err != nil {
		return nil, nil, fmt.Errorf("new signed private failed %s", err)
	}
	pk := x509.MarshalPKCS1PrivateKey(key.(*rsa.PrivateKey))
	keyPEM = pem.EncodeToMemory(&pem.Block{
		Type: "RSA PRIVATE KEY", Bytes: pk,
	})
	_, csr, err = GenerateCSR(cfg, key)
	csr = pem.EncodeToMemory(&pem.Block{
		Type: "CERTIFICATE REQUEST", Bytes: csr,
	})
	if err != nil {
		return nil, nil, fmt.Errorf("new signed csr failed %s", err)
	}
	return
}

// GenerateCSR will generate a new *x509.CertificateRequest template to be used
// by issuers that utilise CSRs to obtain Certificates.
// The CSR will not be signed, and should be passed to either EncodeCSR or
// to the x509.CreateCertificateRequest function.
func GenerateCSR(cfg CertConfig, key crypto.Signer) (*x509.CertificateRequest, []byte, error) {
	if len(cfg.CommonName) == 0 {
		return nil, nil, errors.New("must specify a CommonName")
	}
	var dnsNames []string
	var ips []net.IP
	for _, v := range cfg.AltNames.DNSNames {
		dnsNames = append(dnsNames, v)
	}
	for _, v := range cfg.AltNames.IPs {
		ips = append(ips, v)
	}
	certTmpl := x509.CertificateRequest{
		Subject: pkix.Name{
			CommonName:   cfg.CommonName,
			Organization: cfg.Organization,
		},
		DNSNames:    dnsNames,
		IPAddresses: ips,
	}
	certDERBytes, err := x509.CreateCertificateRequest(rand.Reader, &certTmpl, key)
	if err != nil {
		return nil, nil, err
	}
	r1, r3 := x509.ParseCertificateRequest(certDERBytes)
	return r1, certDERBytes, r3
}
func generateTLS() (csr []byte, key []byte, err error) {
	host := fmt.Sprintf("%s.%s", "webhook-svc", "webhook")
	dnsNames := []string{
		host,
		fmt.Sprintf("%s.svc", host),
		fmt.Sprintf("%s.svc.cluster.local", host),
	}
	cfg := CertConfig{
		CommonName:   host,
		Organization: c.Subject,
		AltNames: struct {
			DNSNames []string
			IPs      []net.IP
		}{
			DNSNames: dnsNames,
		},
	}
	csr, key, err = NewSigned(cfg)
	return
}
{{< /codeblock >}}

#### 生成证书数据并存储到秘钥

{{< codeblock "cert.go" "go" "http://cuisongliu.github.io/2020/07/kubernetes/admission-webhook/#生成证书数据并存储到秘钥" "cert.go" >}}
const (
	certKey     = "tls.crt"
	keyKey      = "tls.key"
	csrKey      = "tls.csr"
	caBundleKey = "caBundle"
)
func generateSecret() (*corev1.Secret, error) {
    secret, err := clientset.CoreV1().Secrets("webhook").Get("webhook-secrets", v1.GetOptions{})
    if err != nil {
        if !errors.IsNotFound(err) {
            return nil, err
        }
        csr, key, err := generateTLS()
        if err != nil {
            return nil, err
        }
        secret = &corev1.Secret{
            ObjectMeta: v1.ObjectMeta{
                Namespace: "webhook",
                Name:      "webhook-secrets",
            },
            Data: map[string][]byte{
                csrKey: csr,
                keyKey: key,
            },
        }
        secret, err = clientset.CoreV1().Secrets("webhook").Create(secret)
        if err != nil {
            return nil, err
        }
    }
    return secret,nil
}
{{< /codeblock >}}

#### 使用csr使用kubernetes签发公钥

{{< codeblock "csr.go" "go" "http://cuisongliu.github.io/2020/07/kubernetes/admission-webhook/#使用csr使用kubernetes签发公钥" "csr.go" >}}
const (
	certKey     = "tls.crt"
	keyKey      = "tls.key"
	csrKey      = "tls.csr"
	caBundleKey = "caBundle"
)
func pathCsr(secret *corev1.Secret) error {
	dPolicy := v1.DeletePropagationBackground
	label := map[string]string{
		"csr-name": "webhook-csr",
	}
	_ = clientset.CertificatesV1beta1().CertificateSigningRequests().Delete("webhook-csr", &v1.DeleteOptions{PropagationPolicy: &dPolicy})
	csrResource := &v1beta1.CertificateSigningRequest{}
	csrResource.Name = "webhook-csr"
	csrResource.Labels = label
	csrResource.Spec.Groups = []string{"system:authenticated"}
	csrResource.Spec.Usages = []v1beta1.KeyUsage{
		"digital signature",
		"key encipherment",
		"server auth",
	}
	csrResource.Spec.Request = secret.Data[csrKey]
	csrResource, err := clientset.CertificatesV1beta1().CertificateSigningRequests().Create(csrResource)
	if err != nil {
		return err
	}
	csrResource.Status.Conditions = []v1beta1.CertificateSigningRequestCondition{
		{Type: v1beta1.CertificateApproved, Reason: "PodSelfApprove", Message: "This CSR was approved by pod certificate approve.", LastUpdateTime: v1.NewTime(time.Now())},
	}
	csrResource, err = clientset.CertificatesV1beta1().CertificateSigningRequests().UpdateApproval(csrResource)
	if err != nil {
		return err
	}
	w, err := clientset.CertificatesV1beta1().CertificateSigningRequests().Watch(v1.ListOptions{LabelSelector: "csr-name=" + "webhook-csr"})
	if err != nil {
		return err
	}
	for {
		select {
		case <-time.After(time.Second * 10):
			return errors.NewBadRequest("The CSR is not ready.")
		case event := <-w.ResultChan():
			if event.Type == watch.Modified || event.Type == watch.Added {
				csr := event.Object.(*v1beta1.CertificateSigningRequest)
				if csr.Status.Certificate != nil {
					secret.Data[certKey] = csr.Status.Certificate
					return nil
				}
			}
		}
	}
}
{{< /codeblock >}}

#### 获取ca证书并修改webhook资源

{{< codeblock "ca.go" "go" "http://cuisongliu.github.io/2020/07/kubernetes/admission-webhook/#获取ca证书并修改webhook资源" "ca.go" >}}
func ca(secret *corev1.Secret) (*corev1.Secret, error){
    caConfigMap, err := clientset.CoreV1().ConfigMaps("kube-system").Get("extension-apiserver-authentication", v1.GetOptions{})
	if err != nil {
		return nil, err
	}
	var caData string
	if caConfigMap != nil {
		caData = caConfigMap.Data["client-ca-file"]
	} else {
		return nil, errors.NewUnauthorized("ca configmap [extension-apiserver-authentication] data [client-ca-file] is not found.")
	}
	secret.Data[caBundleKey] = []byte(caData)
	secret, err = clientset.CoreV1().Secrets(c.Namespace).Update(secret)
	if err != nil {
		return nil, err
	}
}
{{< /codeblock >}}

#### 根据ca数据修改webhook资源

{{< codeblock "webhook.go" "go" "http://cuisongliu.github.io/2020/07/kubernetes/admission-webhook/#根据ca数据修改webhook资源" "webhook.go" >}}
const (
	certKey     = "tls.crt"
	keyKey      = "tls.key"
	csrKey      = "tls.csr"
	caBundleKey = "caBundle"
)
func () patchWebHook(secret *corev1.Secret) error {
    caBundle:=secret.Data[caBundleKey]
    validatingName:="webhook-validate"
    mutatingName:="webhook-mutate"
    {
        vwebhook, err := c.client.AdmissionregistrationV1().ValidatingWebhookConfigurations().Get(validatingName, v1.GetOptions{})
        if err != nil {
            return err
        }
        for i := range vwebhook.Webhooks {
            vwebhook.Webhooks[i].ClientConfig.Service.Name = c.ServiceName
            vwebhook.Webhooks[i].ClientConfig.CABundle = caBundle
        }
        _, err = c.client.AdmissionregistrationV1().ValidatingWebhookConfigurations().Update(vwebhook)
        if err != nil {
            return err
        }
    }
    {
        mwebhook, err := c.client.AdmissionregistrationV1().MutatingWebhookConfigurations().Get(mutatingName, v1.GetOptions{})
        if err != nil {
            return err
        }
        for i := range mwebhook.Webhooks {
            mwebhook.Webhooks[i].ClientConfig.Service.Name = c.ServiceName
            mwebhook.Webhooks[i].ClientConfig.CABundle = caBundle
        }
        _, err = c.client.AdmissionregistrationV1().MutatingWebhookConfigurations().Update(mwebhook)
        if err != nil {
            return err
        }
    }
	return nil
}
{{< /codeblock >}}

#### 把存储的秘钥写入文件夹

{{< codeblock "write.go" "go" "http://cuisongliu.github.io/2020/07/kubernetes/admission-webhook/#把存储的秘钥写入文件夹" "write.go" >}}
const (
	certKey     = "tls.crt"
	keyKey      = "tls.key"
	csrKey      = "tls.csr"
	caBundleKey = "caBundle"
)
func (c *CertWebHook) writeTLSFiles(secret *corev1.Secret) error {
    certData:=secret.Data[certKey]
    keyData:=secret.Data[keyKey]
    certDir:="/etc/kubernetes/webhhok/tls"
	if _, err := os.Stat(certDir); os.IsNotExist(err) {
		if err := os.MkdirAll(certDir, 0700); err != nil {
			return err
		}
	}
	if err := ioutil.WriteFile(path.Join(certDir, "tls.crt"), certData, 0600); err != nil {
		return err
	}
	if err := ioutil.WriteFile(path.Join(certDir, "tls.key"), keyData, 0600); err != nil {
		return err
	}
	return nil
}
{{< /codeblock >}}
