# part5

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
