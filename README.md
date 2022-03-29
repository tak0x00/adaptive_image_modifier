# これはなに

user-agentをもとに、リクエストされた画像を事前定義された解像度や形式に変換して返却する仕組みです
(某Imge○luxとか○kamai ImageM○nagerとかの自家版です)

user-agentに対する解像度や対応フォーマットはvarnish configに記述します。
そのため、更新後はvarnishをreloadする必要があります。

# 起動方法

`docker-compose-local.yml` の `ORIGIN_DOMAIN` を適切に置き換えて、

`docker-compose -f docker-compose-local.yml up --build`

あとは `http://127.0.0.1:8080/任意のパス` でアクセスすればOK.

golang側はAir入れているので自動再コンパイルされます。
varnish側は下記の通りに。

# varnishの設定ファイルをいじったあとのリロードについて

環境変数の置換が必要となるため、こんな感じで。

```
docker cp varnish/default.vcl adaptive_image_modifier-varnish-1:/etc/varnish/default.vcl \
&& docker exec adaptive_image_modifier-varnish-1 /replaceenv.sh \
&& docker exec adaptive_image_modifier-varnish-1 varnishreload
```

# デバッグヘッダーの確認について

```
curl -vv -H "X-aim-debug: true" http://127.0.0.1:8080/hoge.png
```

という感じで、 `X-aim-debug` ヘッダに `true` のみを入れて投げると `x-aim-***` ヘッダに情報が返ってきます。

# ECS上へのデプロイについて

[Docker composeを用いたECSへのデプロイ](https://docs.docker.com/cloud/ecs-compose-examples/)に対応しています。
`docker-compose.yml` にECRやoriginの設定をしたのち、[このあたりの手順](https://dev.classmethod.jp/articles/provision-locust-cluster-with-docker-compose-ecs-integration/) を参考に設定し、 `docker compose --project-name adaptive-image-modifier up` とかすると起動します。

varnishは[vmod_dynamic](https://github.com/nigoroll/libvmod-dynamic)を導入しているため、app側を複数立ち上げることに対応しています。
