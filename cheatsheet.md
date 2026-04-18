# 📑 AWS Full-Stack CLI Cheat Sheet

Panduan ini berisi kumpulan perintah `aws-cli` yang kita gunakan untuk mengelola seluruh infrastruktur Anda. Bagus untuk dipelajari jika ingin mendeploy ulang dari terminal.

---

## 🏗️ 1. Deployment Infrastruktur (CloudFormation)

Sebelum memulai, tentukan prefix project Anda:
```bash
# Set prefix (Ganti dengan nama unik Anda)
PREFIX="alfi"
REGION="ap-southeast-1"
```

Jalankan perintah ini secara berurutan:

```bash
# STACK 1: VPC
aws cloudformation deploy --template-file cloudformation/01-vpc.yaml --stack-name $PREFIX-vpc --parameter-overrides ProjectPrefix=$PREFIX --region $REGION

# STACK 2: RDS
aws cloudformation deploy --template-file cloudformation/02-rds.yaml --stack-name $PREFIX-rds --parameter-overrides ProjectPrefix=$PREFIX DBPassword=YourPassword123 --capabilities CAPABILITY_IAM --region $REGION

# STACK 3: Storage
aws cloudformation deploy --template-file cloudformation/03-storage.yaml --stack-name $PREFIX-storage --parameter-overrides ProjectPrefix=$PREFIX --region $REGION

# STACK 4: Elastic Beanstalk
aws cloudformation deploy --template-file cloudformation/04-beanstalk.yaml --stack-name $PREFIX-beanstalk --parameter-overrides ProjectPrefix=$PREFIX DBPassword=YourPassword123 --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --region $REGION

# STACK 5: Lambda Functions
aws cloudformation deploy --template-file cloudformation/05-lambda.yaml --stack-name $PREFIX-lambda --parameter-overrides ProjectPrefix=$PREFIX DBPassword=YourPassword123 --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --region $REGION

# STACK 6: API Gateway
aws cloudformation deploy --template-file cloudformation/06-apigateway.yaml --stack-name $PREFIX-apigateway --parameter-overrides ProjectPrefix=$PREFIX --region $REGION
```

---

## 📦 2. Mengelola Lambda (Python)

```bash
# Update fungsi Lambda langsung
aws lambda update-function-code --function-name $PREFIX-get-handler --zip-file fileb://get_handler.zip
```

---

## 🧪 3. Testing API (Smoke Test)

```bash
# Mendapatkan URL API Gateway
API_URL=$(aws cloudformation describe-stacks --stack-name $PREFIX-apigateway --query 'Stacks[0].Outputs[?OutputKey==`APIEndpoint`].OutputValue' --output text)

# Test POST
curl -X POST "$API_URL/data" -H "Content-Type: application/json" -d '{"name":"tes-sensor","value":25.5,"category":"Suhu"}'

# Test GET
curl "$API_URL/data"
```

---

## 🗑️ 4. Pembersihan Total (Destroy)

```bash
# 1. Kosongkan S3 Bucket Artifak & Storage
BUCKET="$PREFIX-storage-$(aws sts get-caller-identity --query Account --output text)-$REGION"
aws s3 rm s3://$BUCKET --recursive

# 2. Hapus Stack (Urutan Terbalik)
aws cloudformation delete-stack --stack-name $PREFIX-apigateway
aws cloudformation delete-stack --stack-name $PREFIX-lambda
aws cloudformation delete-stack --stack-name $PREFIX-beanstalk
aws cloudformation delete-stack --stack-name $PREFIX-storage
aws cloudformation delete-stack --stack-name $PREFIX-rds
aws cloudformation delete-stack --stack-name $PREFIX-vpc

# 3. Tunggu hingga statusnya DELETED
aws cloudformation wait stack-delete-complete --stack-name $PREFIX-vpc
```

---
*Catatan: Selalu gunakan region `ap-southeast-1` (Singapura) untuk respon terbaik di Asia Tenggara.*
