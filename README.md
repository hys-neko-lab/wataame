### USE FOR LEARNING ONLY

「Pythonで作るおうちクラウドコンピューティング」用リポジトリ。

実運用は非推奨です。

### 技術書典13頒布本の読者の方へ

「TBF13」タグのついたコミットをご使用ください。

# 動作環境

Ubuntu20.04、物理マシン上での動作を確認しています。

ネットワークインタフェースは2つ以上用意してください。PCに元からあるNIC+USB-Ethernetアダプタなどがおすすめです。後者をWataAmeで占有します。

仮想マシンのサービスを動かせるかは以下で確認できます。

```
$ kvm-ok
```

なお、VirtualBox上での動作は確認できていません。neted VT-X/AMD-Vが有効になれば動くかもしれませんが、ネットワーク周りで沼る可能性大です。チャレンジする場合はネットワークインタフェースを2つ以上に設定してください。

## 主な依存ソフトウェア

 * Python3
 * Docker
 * Kubernetes(kind)
 * MySQL
 * Monaco Editor

# インストール方法

### 本リポジトリのクローン

```
$ git clone --recursive https://github.com/hys-neko-lab/wataame.git
```

### システムセットアップ

```
$ ./setup/setup_wataame.sh
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

### Kubernetes(kind)

インストール方法は公式ページを参照してください

https://kind.sigs.k8s.io/docs/user/quick-start/#installation

インストール完了後、次のコマンドでシェルスクリプトを実行してください

```
$ ./setup/setup_kind.sh
```

## for watame-dashboard

wataame-dashboard/README.md を参照してください。

その後、データベースに対してテーブルを自動生成します。

```
cd wataame-dashboard/api
./generate.sh
cd ../
./dbinit.sh
```

## for wataame-network

WataAmeに占有させるインタフェースがeth0、現在自動で割り当てられているIPが192.168.0.100/16の場合、次のようにIPアドレスを削除。

```
sudo ip addr del 192.168.0.100/16 dev eth0
```

その後、wataame-network/README.mdに従ってブリッジを作成してください。


## for wataame-compute

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

ダッシュボードへのアクセスは http://127.0.0.1:5001 です。

初めて使用するときはサインアップしてください。以降はサインインすることで使用できます。

### はじめに作成すべきもの

必ずResourceを最低1つは作成します。次にNetworkでNATかブリッジを作成するとよいでしょう。

### 仮想マシンの作成

Resource, Networkが作成済みであれば、あとはKeypairだけ作成が必要です。

Storageは仮想マシン作成時に自動で作成します。

### コンテナの作成

Resource, Networkが作成済みであれば作成可能です。

コンテナへのネットワークアクセスは一覧表示されたIPで可能です。

### サーバーレスアプリケーションの作成

Resourceが作成済みであれば作成可能です。

作成したサーバーレスアプリケーションへのJSONリクエストは、WataAmeを実行しているホストの「占有させていない方」のIPアドレスに対して下記のように投げることができます。

```
# ホストIP=192.168.0.100、アプリ名「myfunc」の場合
$ curl -X POST \
-H "Content-Type: application/json" \
-d '{"hello":"world"}' http://192.168.0.100/serverless/myfunc
```