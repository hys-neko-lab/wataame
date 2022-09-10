### USE FOR LEARNING ONLY

実運用は非推奨です。

# 動作環境

Ubuntu20.04、物理マシン上での動作を確認しています。

ネットワークインタフェースは2つ以上用意してください。PCに元からあるNIC+USB-Ethernetアダプタなどがおすすめです。後者をWataAmeで占有します。

VirtualBox上の動作は確認できていません。neted VT-X/AMD-Vが有効になれば動くかもしれませんが、ネットワーク周りで沼る可能性大です。チャレンジする場合はネットワークインタフェースを2つ以上に設定してください。

仮想マシンのサービスを動かせるかは以下で確認できます。

```
$ kvm-ok
```

## 主な依存ソフトウェア

 * Python3
 * Docker
 * Kubernetes
 * MySQL
 * Monaco Editor

# インストール方法

### 本リポジトリのクローン

```
$ git clone --recursive https://github.com/hys-neko-lab/wataame.git
```

### Pythonパッケージ

```
$ python3 -m pip install --upgrade pip
$ pip3 install \
grpcio grpcio-tools \
flask flask-sqlalchemy flask-migrate \
flask-wtf email-validator flask-login PyMySQL \
ipget docker kubernetes 
```

### apt

```
$ sudo apt install \
libvirt-clients virtinst qemu-system libvirt-daemon-system \
mysql-server mysql-client python3-mysqldb
# 実行後、libvirtdへのアクセス権限を有効にするため再起動してください
```

### MySQL初期設定

```
$ sudo mysql_secure_installation
# うまくいかない場合/わからない場合は下記記事を参照してください
# https://techblog.hys-neko-lab.com/entry/2022/09/10/055119

$ mysql -u root -p
# DBを作る
mysql> CREATE DATABASE clouduser;
# ユーザーを作る
mysql> CREATE USER 'wata-ame'@'localhost' IDENTIFIED BY '3qPfyqCYuu_3k';
# ユーザーにデータベースへのアクセスを許可
mysql> GRANT ALL ON clouduser.* TO 'wata-ame'@'localhost';
```

### Docker

インストール方法は公式ページを参照してください

https://docs.docker.com/engine/install/ubuntu/

sudoなし実行のため次のコマンドを実行後、システムを再起動してください

```
$ sudo usermod -aG docker $USER
```

### Kubernetes

インストール方法は公式ページを参照してください

https://kubernetes.io/ja/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#kubeadm-kubelet-kubectl%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB

スワップを切らないと動作しません。設定を永続化する場合は適宜ググってください。

```
$ sudo swapoff -a
```

インストール時のメッセージ通り設定

```
$ mkdir -p $HOME/.kube
$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

flannelをインストール

```
$ sudo sysctl net.bridge.bridge-nf-call-iptables=1
$ kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

コントロールプレーン上でポッドを動作させるためTaintsを切る

```
$ kubectl describe node main | grep Taints
Taints:             node-role.kubernetes.io/control-plane:NoSchedule
# if you get NoSchedule, remove Taints
$ kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

metrics-serverのインストール

そのままだと接続できない事象が起きたのでcomponents.yamlを編集して適用

```
$ kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# metrics-server setting
$ wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
$ vi components.yaml
(省略)
    spec:
      containers:
      - args:
        - --cert-dir=/tmp
        - --secure-port=4443
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        - --kubelet-use-node-status-port
        - --kubelet-insecure-tls ### これを追記 ###
        - --metric-resolution=15s
        image: k8s.gcr.io/metrics-server/metrics-server:v0.6.1
$ kubectl apply -f components.yaml
```

dockerプライベートレジストリの起動

wataame-serverlessはプライベートレジストリにイメージをpushするため。

https://docs.docker.com/registry/deploying/

```
$ docker run -d -p 5000:5000 --restart=always --name registry registry:2
```

## watame-dashboard
wataame-dashboard/README.md を参照してください。

その後、データベースに対してテーブルを自動生成します。

```
cd wataame-dashboard/api
./generate.sh
cd ../
./dbinit.sh
```

## wataame-network

WataAmeに占有させるインタフェースがeth0、現在自動で割り当てられているIPが192.168.0.100/16の場合、次のようにIPアドレスを削除。

```
sudo ip addr del 192.168.0.100/16 dev eth0
```

その後、wataame-network/README.mdに従ってブリッジを作成してください。


## wataame-compute

README.mdに従ってUbuntuイメージのセッティングをしてください。

その後、DBにイメージとマシンタイプの情報をINSERTしておきます。

```
$ mysql -u root -p
mysql> use clouduser;
mysql> INSERT INTO machine_types(name) VALUES ('standard');
mysql> INSERT INTO images(name,path) VALUES ('Ubuntu20.04','path/to/ubuntu_iso.iso');
mysql> exit
```

# 使い方

wataame-rpcを除く全てのディレクトリについてapi/generate.shを実行してください。これは最初とgRPC更新時のみ実行すればよいです。

run.shはWataAmeを使用するたびに実行してください。サーバーが立ち上がります。サービスごと別のターミナルで実行してください。

```
$ cd wataame-xxxx/api
$ ./generate.sh
$ cd ../
$ ./run.sh
```

ダッシュボードへのアクセスはhttp://127.0.0.1:5001です。

初めて使用するときはサインアップしてください。以降はサインインすることで使用できます。

### はじめに作成すべきもの

必ずResourceを最低1つは作成します。次にNetworkでNATかブリッジを作成するとよいでしょう。

### 仮想マシンの作成

Resource, Networkが作成済みであれば、あとはKeypairだけ作成が必要です。

Storageは仮想マシン作成時に自動で作成します。

### コンテナの作成

Resource, Networkが作成済みであれば作成可能です。

コンテナへのネットワークアクセスは一覧表示されたIPで可能です。

# FaaSの作成

Resourceが作成済みであれば作成可能です。

FaaSへのJSONリクエストは、WataAmeを実行しているホストの「占有させていない方」のIPアドレスに対して、一覧表示されているポートから可能です。