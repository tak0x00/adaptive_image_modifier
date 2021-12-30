# これはなに

user-agentをもとに、リクエストされた画像を事前定義された解像度や形式に変換して返却する仕組みです
(某Imge○luxとか○kamai ImageM○nagerとかの自家版です)

user-agentに対する解像度や対応フォーマットはnginx configの形式で記述します。
そのため、更新後はnginx reloadの必要があります。

# 起動方法

`docker-compose.yml` の `ORIGIN_DOMAIN` を適切に置き換えて、

`docker-compose up`

あとは `http://127.0.0.1:8080/任意のパス` でアクセスすればOK.

golang側はAir入れているので自動再コンパイルされます。
nginx側はcopyコマンド使ってるのでre-build必要です。