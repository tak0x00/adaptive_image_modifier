# これはなに

user-agentをもとに、リクエストされた画像を事前定義された解像度や形式に変換して返却する仕組みです
(某Imge○luxとか○kamai ImageM○nagerとかの自家版です)

user-agentに対する解像度や対応フォーマットはvarnish configに記述します。
そのため、更新後はvarnishをreloadする必要があります。

# 起動方法

`docker-compose.yml` の `ORIGIN_DOMAIN` を適切に置き換えて、

`docker-compose up`

あとは `http://127.0.0.1:8080/任意のパス` でアクセスすればOK.

golang側はAir入れているので自動再コンパイルされます。
varnish側は下記の通りに。

# varnishの設定ファイルをいじったあとのリロードについて

環境変数の置換が必要となるため、こんな感じで。

```
docker cp varnish/default.vcl VARNISH_CONTAINER_NAME:/etc/varnish/default.vcl \
&& docker exec VARNISH_CONTAINER_NAME /replaceenv.sh \
&& docker exec aim-varnish-1 varnishreload
```
