## はじめに

この記事では 手を動かしながらAWSが提供するAWS App Runner(以下、App Runner)を学習していく記事です。主な内容としては実践したときのメモを中心に書きます。（忘れやすいことなど）
誤りなどがあれば書き直していく予定です。

## 前提知識

### 欲しかったのはAWS App Runner でした

何を言っているのかわからないと思いますが、まさしくこの通りでコンテナでアプリケーションを開発する人は待望のサービスかなと思います。いくつか理由を述べつつ、前提知識をおさらいしていきます。

### 特徴

Amazon ECSのように専門用語と言われるようなものは特にありません。
特徴は以下のサイトにまとまっています。
<https://aws.amazon.com/jp/apprunner/features/>

簡単に述べるとApp Runnerはアプリケーションリポジトリさえあれば、アプリケーションをデプロイできます。
もしくはすでに作成済みのイメージレジストリを共有するだけでもアプリケーションのデプロイが可能です。

とても便利なサービスですが、気になる責任共有モデルはどうなっているのでしょうか。また、料金はいくらなのでしょうか。

### 責任共有モデル

EC2,ECS,App Runnerの違いを簡単に表した図ですが、以下のAWS Startup CommunityのTweetが参考になります。

https://twitter.com/startups_on_aws/status/1501153315396399104?s=20

公式の`よくあるQA`では以下のように語られています。

> また、アプリケーションは AWS が保守、運用するインフラストラクチャ上で稼働するので、セキュリティパッチの自動化や暗号化など、セキュリティおよびコンプライアンス上のベストプラクティスも提供されます。

[参考](https://aws.amazon.com/jp/apprunner/faqs/)

### 料金体系

簡単に言えば、CPUとメモリの使用量に応じて課金が発生する仕組みです。

公式の`料金体系の仕組み`では以下のように語られています。

> アプリケーションがアイドル状態のときは、プロビジョニングされたコンテナインスタンスに対してメモリの GB 単位で支払うことによってアプリケーションがウォームに保たれ、コールドスタートが不要になります。リクエストがあると、アプリケーションはミリ秒単位で応答し、アプリケーションがリクエストを処理している間にアクティブなコンテナインスタンスが消費した vCPU およびメモリ分の料金を支払います。

[参考](https://aws.amazon.com/jp/apprunner/pricing/)

## 実際に使ってみよう

## 今回扱うサービス

- AWS CodeCommit
- AWS CodeBuild
- AWS CodePipeline
- Amazon Elastic Container Registry (Amazon ECR)
- Amazon S3

## 構成

簡単にですが、今回作成する構成図です。

![AWS CICD構成図_Qiita.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/527543/5093ba43-34e6-c96d-8a39-b51dcb15cc0e.png)

厳密にはCodeBuildでS3を利用していますが、省略してます。
VPCリソースは存在しない為、ネットワークについても省略しています。

## 事前準備

[app_runner - GitHub](https://github.com/ymd65536/app_runner.git)をgitコマンドでDesktop上にcloneします。

### リポジトリを作成する

以下のコマンドで`codecommit.yml`をCloudFormationで実行します。

```sh
aws cloudformation deploy --stack-name codecommit --template-file ./codecommit.yml --tags Name=cicdhandson --profile app_user
```

### CodeCommitのリポジトリをクローンする

Desktop上にCodeCommitのリポジトリをcloneします。

```sh
git clone codecommit::ap-northeast-1://app_user@cicdhandson ~/Desktop/cicdhandson
```

ディレクトリを移動します。

```sh
cd ~/Desktop/cicdhandson
```

### mainブランチを作成

```sh
git checkout -b main
```

```sh
echo "Hello App Runner" > README.md
```

```sh
git add .
git commit -m "App Runner"
git push -u 
```

### app_runner ブランチを切る

新しいブランチでビルドを実行する為にCodeBuild用に新しくブランチを切ります。

```sh
git checkout -b app_runner
```

### buildspec.yamlを作成する

CodeBuildで利用する設定ファイル(buildspec.yml)を作成します。
app_runnerリポジトリにある`buildspec.yml`を`cicdhandson`リポジトリにコピーします。

```sh
cp ~/Desktop/app_runner/buildspec.yml ~/Desktop/cicdhandson/
```

### dockerfileを作成する

dockerfileを`cicdhandson`リポジトリにコピーします。

```sh
cp ~/Desktop/app_runner/dockerfile ~/Desktop/cicdhandson/
```

### リモートリポジトリを更新する

CodeCommitのリモートリポジトリにdockerfileをpushします。
リモートリポジトリにブランチを追加します。

```sh
git add .
git commit -m "add files"
git push --set-upstream origin app_runner
```

### CodeBuild用 S3バケットの作成

cicdhandsonリポジトリに移動します。

```sh
cd ~/Desktop/cicdhandson
```

以下のコマンドで`s3.yml`をCloudFormationで実行します。

```sh
aws cloudformation deploy --stack-name s3 --template-file ./s3.yml --tags Name=cicdhandson --profile app_user
```

### ECRリポジトリの作成

以下のコマンドで`ecr.yml`をCloudFormationで実行します。

```sh
aws cloudformation deploy --stack-name ecr --template-file ./ecr.yml --tags Name=cicdhandson --profile app_user
```

### ハンズオンで利用するIAM Roleを作成する

以下のコマンドを実行してIAMロールを作成します。

```sh
aws cloudformation deploy --stack-name codebuild-iam-role --template-file ./codebuild-role.yml --tags Name=cicdhandson --capabilities CAPABILITY_NAMED_IAM --profile app_user && aws cloudformation deploy --stack-name event-bridge-iam-role --template-file ./event-bridge-iam-role.yml --tags Name=cicdhandson --capabilities CAPABILITY_NAMED_IAM --profile app_user && aws cloudformation deploy --stack-name pipeline-iam-role --template-file ./pipeline-iam-role.yml --tags Name=cicdhandson --capabilities CAPABILITY_NAMED_IAM --profile app_user

```

### CodePipeline を構築

以下のコマンドを実行してCodePipelineのを構築します。

```sh
aws cloudformation deploy --stack-name code-build --template-file ./code-build.yml --tags Name=cicdhandson --profile app_user && aws cloudformation deploy --stack-name pipeline --template-file ./pipeline.yml --tags Name=cicdhandson --profile app_user
```

### プルリクエストを作成する

環境構築は以上となります。CodeCommitでプルリクエストを作成する為に以下のコマンドを実行します。

```sh
aws codecommit create-pull-request --title "new pull request" --description "App Runner ci/cd" --targets repositoryName=cicdhandson,sourceReference=app_runner --profile app_user && PULL_REQUEST_ID=`aws codecommit list-pull-requests --profile app_user --pull-request-status OPEN --repository-name cicdhandson --query 'pullRequestIds' --output text` && echo $PULL_REQUEST_ID && COMMITID=`aws codecommit get-branch --repository-name cicdhandson --branch-name app_runner --profile app_user --query 'branch.commitId' --output text` && echo $COMMITID
```

### ブランチをマージする

プルリクエストをマージします。

```sh
aws codecommit merge-pull-request-by-fast-forward --pull-request-id $PULL_REQUEST_ID --source-commit-id $COMMITID --repository-name cicdhandson --profile app_user
```

結果

```json
{
    "pullRequest": {
        "pullRequestId": "11",
        "title": "new pull request",
        "description": "App Runner ci/cd",
        "lastActivityDate": "2023-06-15T20:25:04.181000+09:00",
        "creationDate": "2023-06-15T20:23:08.812000+09:00",
        "pullRequestStatus": "CLOSED",
        "authorArn": "arn",
        "pullRequestTargets": [
            {
                "repositoryName": "cicdhandson",
                "sourceReference": "refs/heads/app_runner",
                "destinationReference": "refs/heads/main",
                "destinationCommit": "",
                "sourceCommit": "",
                "mergeBase": "",
                "mergeMetadata": {
                    "isMerged": true,
                    "mergedBy": "arn",
                    "mergeCommitId": "",
                    "mergeOption": "FAST_FORWARD_MERGE"
                }
            }
        ],
        "clientRequestToken": "",
        "revisionId": "",
        "approvalRules": []
    }
}
```

### ビルドされたイメージを確認する

CodeBuildでイメージがビルドされているかを確認します。

```sh
aws ecr list-images --profile app_user --repository-name cicdhandson --query "imageIds[*].imageDigest" --output table
```

結果

```text
-----------------------------------------------------------------------------
|                                ListImages                                 |
+---------------------------------------------------------------------------+
|  sha256:70f9eda4317cdce66c06fe1a699cae9bb1627cac91e1c9c6a09f6b3572fd56b4  |
+---------------------------------------------------------------------------+
```

### App Runnerにコンテナをデプロイする

```sh
aws cloudformation deploy --stack-name apprunner --template-file ./app_runner.yml --tags Name=cicdhandson --capabilities CAPABILITY_NAMED_IAM --profile app_user
```

実行結果
![nginx.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/527543/0813f8dc-a395-b0d1-f070-a112aefc6d1a.png)

## まとめ

これでハンズオンは以上です。App Runnerは今回紹介した以外にも違う使い方があります。もちろん、その中にはもっと簡単にできる方法がありますが
この記事ではイメージをリポジトリにpushしたことをトリガーにApp Runnerへアプリケーションデプロイする方法を紹介しました。

なお、本番用にデプロイする場合は考慮すべきことも多く、例えば、IP制限を実行することも導入した際には課題として挙がる可能性があります。
今年の初めまではIP制限に対応していませんでしたが、現在(2023年6月)はWAFに対応しており、IP制限を実行できるようになっています。

これからの進化に期待できそうなサービスなので今後の進化に期待です。

## おわり
