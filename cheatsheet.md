# 📑 AWS Full-Stack CLI Cheat Sheet (Windows PowerShell Edition)

Cek panduan ini jika Anda ingin mengelola infrastruktur langsung dari terminal Windows. Semua perintah di bawah ini sudah disesuaikan untuk **PowerShell**.

---

## 🏗️ 1. Persiapan Variabel
Setial kali Anda membuka terminal baru, pastikan Anda menjalankan ini (Ganti `alfi` dengan prefix Anda):
```powershell
$PREFIX = "alfi"
$REGION = "ap-southeast-1"
```

---

## 🏗️ 2. Deployment Infrastruktur (CloudFormation)
Jalankan perintah ini secara berurutan:

```powershell
# STACK 1: VPC
aws cloudformation deploy --template-file cloudformation/01-vpc.yaml --stack-name "$PREFIX-vpc" --parameter-overrides ProjectPrefix="$PREFIX" --region "$REGION"

# STACK 2: RDS (Ganti YourPassword123)
aws cloudformation deploy --template-file cloudformation/02-rds.yaml --stack-name "$PREFIX-rds" --parameter-overrides ProjectPrefix="$PREFIX" DBPassword=YourPassword123 --capabilities CAPABILITY_IAM --region "$REGION"

# STACK 3: Storage
aws cloudformation deploy --template-file cloudformation/03-storage.yaml --stack-name "$PREFIX-storage" --parameter-overrides ProjectPrefix="$PREFIX" --region "$REGION"

# STACK 4: Elastic Beanstalk
aws cloudformation deploy --template-file cloudformation/04-beanstalk.yaml --stack-name "$PREFIX-beanstalk" --parameter-overrides ProjectPrefix="$PREFIX" DBPassword=YourPassword123 --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --region "$REGION"

# STACK 5: Lambda Functions (Gunakan GitHub Actions saja untuk hasil terbaik)
aws cloudformation deploy --template-file cloudformation/05-lambda.yaml --stack-name "$PREFIX-lambda" --parameter-overrides ProjectPrefix="$PREFIX" DBPassword=YourPassword123 --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --region "$REGION"

# STACK 6: API Gateway
aws cloudformation deploy --template-file cloudformation/06-apigateway.yaml --stack-name "$PREFIX-apigateway" --parameter-overrides ProjectPrefix="$PREFIX" --region "$REGION"
```

---

## 📦 3. Manual Update Lambda (Jika Push GitHub Gagal)
Jika Anda terpaksa update manual dari Windows, gunakan perintah ini agar ZIP-nya bersih:

```powershell
# Update GET Handler
Compress-Archive -Path lambda/get_handler/handler.py -DestinationPath lambda/get_handler_clean.zip -Force
aws lambda update-function-code --function-name "$PREFIX-get-handler" --zip-file fileb://lambda/get_handler_clean.zip --region "$REGION"

# Update POST Handler
Compress-Archive -Path lambda/post_handler/handler.py -DestinationPath lambda/post_handler_clean.zip -Force
aws lambda update-function-code --function-name "$PREFIX-post-handler" --zip-file fileb://lambda/post_handler_clean.zip --region "$REGION"
```

---

## 🧪 4. Testing API (Smoke Test)
Gunakan perintah ini untuk memastikan sistem berjalan:

```powershell
# Mendapatkan URL API Gateway
$API_URL = $(aws cloudformation describe-stacks --stack-name "$PREFIX-apigateway" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`APIEndpoint`].OutputValue' --output text)

# Test POST (Simpan Data)
$body = @{ name = "tes-sensor"; value = 25.5; category = "Suhu" } | ConvertTo-Json
Invoke-RestMethod -Uri "$API_URL/data" -Method Post -Body $body -ContentType "application/json"

# Test GET (Ambil Data)
Invoke-RestMethod -Uri "$API_URL/data"
```

---

## 🗑️ 5. Pembersihan Total (Destroy)
Jangan biarkan infrastruktur menyala jika tidak dipakai untuk menghemat biaya:

```powershell
# 1. Hapus Stack (Urutan Terbalik)
aws cloudformation delete-stack --stack-name "$PREFIX-apigateway" --region "$REGION"
aws cloudformation delete-stack --stack-name "$PREFIX-lambda" --region "$REGION"
aws cloudformation delete-stack --stack-name "$PREFIX-beanstalk" --region "$REGION"
aws cloudformation delete-stack --stack-name "$PREFIX-storage" --region "$REGION"
aws cloudformation delete-stack --stack-name "$PREFIX-rds" --region "$REGION"
aws cloudformation delete-stack --stack-name "$PREFIX-vpc" --region "$REGION"

# 2. Tunggu sampai selesai
aws cloudformation wait stack-delete-complete --stack-name "$PREFIX-vpc" --region "$REGION"
```

---
*Catatan: Cheat sheet ini dikhususkan untuk Windows PowerShell.*
