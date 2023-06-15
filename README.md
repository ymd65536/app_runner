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

<https://twitter.com/startups_on_aws/status/1501153315396399104?s=20>

公式では`よくあるQA`では以下のように語られています。

> また、アプリケーションは AWS が保守、運用するインフラストラクチャ上で稼働するので、セキュリティパッチの自動化や暗号化など、セキュリティおよびコンプライアンス上のベストプラクティスも提供されます。

[参考](https://aws.amazon.com/jp/apprunner/faqs/)

### 料金体系

簡単に言えば、CPUとメモリの使用量に応じて課金が発生する仕組みです。

公式の`料金体系の仕組み`では以下のように語られています。

> アプリケーションがアイドル状態のときは、プロビジョニングされたコンテナインスタンスに対してメモリの GB 単位で支払うことによってアプリケーションがウォームに保たれ、コールドスタートが不要になります。リクエストがあると、アプリケーションはミリ秒単位で応答し、アプリケーションがリクエストを処理している間にアクティブなコンテナインスタンスが消費した vCPU およびメモリ分の料金を支払います。

[参考](https://aws.amazon.com/jp/apprunner/pricing/)

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
cd ~/Desktop
```

```sh
git clone codecommit::ap-northeast-1://app_user@cicdhandson
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
part3ディレクトリにあるbuildspec.ymlを`app_user`リポジトリにコピーします。

```sh
cp ~/Desktop/app_runner/buildspec.yml ~/Desktop/cicdhandson/
```

### dockerfileを作成する

dockerfileを`app_user`リポジトリにコピーします。

```sh
cp ~/Desktop/app_runner/dockerfile ~/Desktop/cicdhandson/
```

### app.py　を追加

`app.py`を`app_user`リポジトリにコピーします。

```sh
cp ~/Desktop/app_runner/app.py ~/Desktop/cicdhandson/
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

`aws_happy_code`リポジトリでターミナルを開き、part3にディレクトリを変更します。

```sh
cd ~/Desktop/app_runner
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

以下のコマンドを実行してCodeBuild用のIAMロールを作成します。

```sh
aws cloudformation deploy --stack-name codebuild-iam-role --template-file ./codebuild-role.yml --tags Name=cicdhandson --capabilities CAPABILITY_NAMED_IAM --profile app_user
```

以下のコマンドを実行して Event Bridge用のIAMロールを作成します。

```sh
aws cloudformation deploy --stack-name event-bridge-iam-role --template-file ./event-bridge-iam-role.yml --tags Name=cicdhandson --capabilities CAPABILITY_NAMED_IAM --profile app_user
```

以下のコマンドを実行して CodePipeline用のIAMロールを作成します。

```sh
aws cloudformation deploy --stack-name pipeline-iam-role --template-file ./pipeline-iam-role.yml --tags Name=cicdhandson --capabilities CAPABILITY_NAMED_IAM --profile app_user
```

### CodeBuildのプロジェクトを作成する

以下のコマンドを実行してCodeBuildのプロジェクトを作成します。

```sh
aws cloudformation deploy --stack-name code-build --template-file ./code-build.yml --tags Name=cicdhandson --profile app_user
```

### CodePipeline の環境構築

以下のコマンドを実行してCodePipelineのを構築します。

```sh
aws cloudformation deploy --stack-name pipeline --template-file ./pipeline.yml --tags Name=cicdhandson --profile app_user
```

### プルリクエストを作成する

環境構築は以上となります。CodeCommitでプルリクエストを作成してみます。

```sh
aws codecommit create-pull-request --title "new pull request" --description "App Runner ci/cd" --targets repositoryName=cicdhandson,sourceReference=app_runner --profile app_user
```

プルリクエストIDを環境変数に保存します。

```sh
PULL_REQUEST_ID=`aws codecommit list-pull-requests --profile app_user --pull-request-status OPEN --repository-name cicdhandson --query 'pullRequestIds' --output text` && echo $PULL_REQUEST_ID
```

コミットIDを環境変数に保存します。

```sh
COMMITID=`aws codecommit get-branch --repository-name cicdhandson --branch-name app_runner --profile app_user --query 'branch.commitId' --output text` && echo $COMMITID
```

### ブランチをマージする

```sh
aws codecommit merge-pull-request-by-fast-forward --pull-request-id $PULL_REQUEST_ID --source-commit-id $COMMITID --repository-name cicdhandson --profile app_user
```

### App Runnerにコンテンをデプロイする

```sh
aws cloudformation deploy --stack-name app-runner --template-file ./app_runner.yml --tags Name=cicdhandson --profile app_user
```

## まとめ

これでハンズオンは以上です。上記の構成でCodeCommit にDockerfileをおくことにより
buildspec.ymlの設定に従ってCodeBuildでイメージをビルドできます。これでイメージをリポジトリにpushしたことをトリガーに
CodeDeployによるデプロイやApp Runnerへのアプリケーションデプロイができます。
