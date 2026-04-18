# 🚀 AWS Infrastructure Cheat Sheet (Windows PowerShell)

Ikuti panduan ini langkah demi langkah agar konfigurasimu tidak error.

---

## 1. Persiapan GitHub (PENTING!)
Sebelum push ke GitHub, kamu **WAJIB** mengisi konfigurasi di menu **Settings > Secrets and variables > Actions**:

### 🔒 Secrets (Rahasia)
*   `AWS_ACCESS_KEY_ID`: Dari console IAM AWS.
*   `AWS_SECRET_ACCESS_KEY`: Dari console IAM AWS.
*   `AWS_ACCOUNT_ID`: 12 digit nomor akun AWS-mu.
*   `DB_PASSWORD`: Password untuk database RDS (bebas, minimal 8 karakter).

### 📊 Variables (Variabel)
*   `PROJECT_PREFIX`: Nama unikmu (contoh: `alfi`). **WAJIB SAMA** dengan yang kamu pakai di PowerShell.
*   `AWS_REGION`: Isi dengan `ap-southeast-1`.

---

## 2. Persiapan PowerShell (Lakukan TIAP BUKA Terminal)
Hapus stack lama jika statusnya `ROLLBACK_COMPLETE`, lalu set variabel ini:

```powershell
# Set nama unikmu dan region
$PREFIX = "alfi"
$REGION = "ap-southeast-1"

# Ambil Account ID untuk bucket naming
$ACCOUNT_ID = aws sts get-caller-identity --query "Account" --output text
```

---

## 3. Deployment Infrastruktur (Urutan 1 - 6)

```powershell
# 1. VPC
aws cloudformation deploy --template-file cloudformation/01-vpc.yaml --stack-name "$PREFIX-vpc" --parameter-overrides ProjectPrefix="$PREFIX" --region "$REGION"

# 2. RDS (Password ambil dari input atau set manual)
aws cloudformation deploy --template-file cloudformation/02-rds.yaml --stack-name "$PREFIX-rds" --parameter-overrides ProjectPrefix="$PREFIX" DBPassword=YourPassword123 --capabilities CAPABILITY_IAM --region "$REGION"

# 3. Storage
aws cloudformation deploy --template-file cloudformation/03-storage.yaml --stack-name "$PREFIX-storage" --parameter-overrides ProjectPrefix="$PREFIX" --region "$REGION"

# 4. Beanstalk (Backend)
aws cloudformation deploy --template-file cloudformation/04-beanstalk.yaml --stack-name "$PREFIX-beanstalk" --parameter-overrides ProjectPrefix="$PREFIX" DBPassword=YourPassword123 --capabilities CAPABILITY_IAM --region "$REGION"

# 5. Lambda
aws cloudformation deploy --template-file cloudformation/05-lambda.yaml --stack-name "$PREFIX-lambda" --parameter-overrides ProjectPrefix="$PREFIX" DBPassword=YourPassword123 --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --region "$REGION"

# 6. API Gateway
aws cloudformation deploy --template-file cloudformation/06-apigateway.yaml --stack-name "$PREFIX-apigateway" --parameter-overrides ProjectPrefix="$PREFIX" --region "$REGION"
```

---

## 4. Testing & Verifikasi

```powershell
# Ambil URL API Gateway secara otomatis
$API_URL = aws cloudformation describe-stacks --stack-name "$PREFIX-apigateway" --query 'Stacks[0].Outputs[?OutputKey==`APIEndpoint`].OutputValue' --output text

# TEST POST (Kirim Data)
$body = @{ name = "sensor-01"; value = 25.5; category = "suhu" } | ConvertTo-Json
Invoke-RestMethod -Uri "$API_URL/data" -Method Post -Body $body -ContentType "application/json"

# TEST GET (Ambil Data)
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
