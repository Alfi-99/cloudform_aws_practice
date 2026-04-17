# 🚀 AWS Full-Stack Architecture — Deployment Guide

> **Stack:** Amplify (React) · Elastic Beanstalk (Node.js) · Lambda (Python) · API Gateway · RDS PostgreSQL · S3 · EFS  
> **CI/CD:** GitHub Actions · CloudFormation IaC

---

## 📁 Struktur Proyek

```
my-aws-app/
├── README.md
├── .github/
│   └── workflows/
│       ├── deploy-infrastructure.yml   ← CloudFormation deploy
│       ├── deploy-backend.yml          ← Elastic Beanstalk deploy
│       ├── deploy-lambda.yml           ← Lambda Python deploy
│       └── deploy-frontend.yml         ← Amplify trigger deploy
├── cloudformation/
│   ├── 01-vpc.yaml                     ← VPC, Subnet, NAT Gateway
│   ├── 02-rds.yaml                     ← RDS PostgreSQL Free Tier
│   ├── 03-storage.yaml                 ← S3 Bucket + EFS
│   ├── 04-beanstalk.yaml               ← Elastic Beanstalk Node.js
│   ├── 05-lambda.yaml                  ← Lambda POST & GET Python
│   └── 06-apigateway.yaml              ← API Gateway REST
├── frontend/
│   ├── amplify.yml                     ← Build spec Amplify
│   ├── package.json
│   ├── vite.config.js
│   ├── index.html
│   └── src/
│       ├── main.jsx
│       └── App.jsx                     ← Dashboard + Chart + Form
├── backend/
│   ├── Procfile                        ← Entry point Beanstalk
│   ├── package.json
│   └── src/
│       └── app.js                      ← Express API + Proxy
└── lambda/
    ├── post_handler/
    │   └── handler.py                  ← POST → Insert ke RDS
    ├── get_handler/
    │   └── handler.py                  ← GET → Query RDS + Statistik
    └── tests/
        ├── test_post.py
        └── test_get.py
```

---

## 🔧 LANGKAH 0 — Persiapan Awal

### 0.1 Install Tools yang Diperlukan

```bash
# 1. AWS CLI (Windows)
winget install Amazon.AWSCLI

# 2. Node.js 20 LTS
winget install OpenJS.NodeJS.LTS

# 3. Python 3.12
winget install Python.Python.3.12

# 4. Git
winget install Git.Git
```

### 0.2 Konfigurasi AWS CLI

```bash
aws configure
```
Masukkan:
- **AWS Access Key ID** → dari IAM User Anda
- **AWS Secret Access Key** → dari IAM User Anda
- **Default region** → `ap-southeast-1` (Singapore, terdekat & mendukung free tier)
- **Output format** → `json`

### 0.3 Buat IAM User untuk GitHub Actions

```bash
# Buat user
aws iam create-user --user-name github-actions-deploy

# Beri permission (untuk demo, gunakan PowerUser)
aws iam attach-user-policy \
  --user-name github-actions-deploy \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

aws iam attach-user-policy \
  --user-name github-actions-deploy \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

# Buat Access Key — SIMPAN outputnya!
aws iam create-access-key --user-name github-actions-deploy
```

### 0.4 Push ke GitHub

```bash
git init
git remote add origin https://github.com/<username>/<repo-name>.git
git add .
git commit -m "Initial commit: AWS Architecture Setup"
git push -u origin main
```

---

## 🏗️ LANGKAH 1 — Setup GitHub Secrets

Buka: `GitHub Repo → Settings → Secrets and variables → Actions → New repository secret`

| Secret Name | Nilai | Cara Dapatkan |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Access Key IAM User | Output step 0.3 |
| `AWS_SECRET_ACCESS_KEY` | Secret Key IAM User | Output step 0.3 |
| `AWS_ACCOUNT_ID` | 12-digit Account ID | `aws sts get-caller-identity --query Account --output text` |
| `DB_PASSWORD` | Password kuat (min 12 karakter) | Buat sendiri, contoh: `MyP@ssw0rd2024!` |

---

## 🌐 LANGKAH 2 — Deploy Infrastruktur via CloudFormation

> ⚠️ **Urutan deploy HARUS berurutan** karena ada dependency antar stack.

### 2.1 Buat S3 Bucket untuk Artifact (PERTAMA KALI SAJA)

```bash
# Ganti <account-id> dengan Account ID AWS Anda
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="myapp-artifacts-${ACCOUNT_ID}"

aws s3 mb s3://${BUCKET_NAME} --region ap-southeast-1
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled

echo "Artifact bucket: ${BUCKET_NAME}"
```

### 2.2 Upload CloudFormation Templates ke S3

```bash
aws s3 sync cloudformation/ s3://${BUCKET_NAME}/cloudformation/ \
  --exclude "*" --include "*.yaml"
```

### 2.3 Deploy Stack Satu per Satu (Manual Pertama Kali)

```bash
# === STACK 1: VPC ===
aws cloudformation deploy \
  --template-file cloudformation/01-vpc.yaml \
  --stack-name myapp-vpc \
  --region ap-southeast-1 \
  --capabilities CAPABILITY_IAM

# Cek status
aws cloudformation describe-stacks \
  --stack-name myapp-vpc \
  --query 'Stacks[0].StackStatus'

# === STACK 2: RDS PostgreSQL ===
aws cloudformation deploy \
  --template-file cloudformation/02-rds.yaml \
  --stack-name myapp-rds \
  --parameter-overrides DBPassword=MyP@ssw0rd2024! \
  --region ap-southeast-1 \
  --capabilities CAPABILITY_IAM

# === STACK 3: Storage (S3 + EFS) ===
aws cloudformation deploy \
  --template-file cloudformation/03-storage.yaml \
  --stack-name myapp-storage \
  --region ap-southeast-1 \
  --capabilities CAPABILITY_IAM

# === STACK 4: Elastic Beanstalk ===
aws cloudformation deploy \
  --template-file cloudformation/04-beanstalk.yaml \
  --stack-name myapp-beanstalk \
  --region ap-southeast-1 \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

# === STACK 5: Lambda (Python POST & GET) ===
# Package Lambda dulu
cd lambda/post_handler && pip install psycopg2-binary -t ./ -q && zip -r ../../post-handler.zip . && cd ../..
cd lambda/get_handler && pip install psycopg2-binary -t ./ -q && zip -r ../../get-handler.zip . && cd ../..

# Upload Lambda packages
aws s3 cp post-handler.zip s3://${BUCKET_NAME}/lambda/post-handler.zip
aws s3 cp get-handler.zip s3://${BUCKET_NAME}/lambda/get-handler.zip

aws cloudformation deploy \
  --template-file cloudformation/05-lambda.yaml \
  --stack-name myapp-lambda \
  --parameter-overrides DBPassword=MyP@ssw0rd2024! \
  --region ap-southeast-1 \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

# === STACK 6: API Gateway ===
aws cloudformation deploy \
  --template-file cloudformation/06-apigateway.yaml \
  --stack-name myapp-apigateway \
  --region ap-southeast-1 \
  --capabilities CAPABILITY_IAM

# Lihat API Gateway URL
aws cloudformation describe-stacks \
  --stack-name myapp-apigateway \
  --query 'Stacks[0].Outputs[?OutputKey==`APIEndpoint`].OutputValue' \
  --output text
```

### 2.4 Selanjutnya — Otomatis via GitHub Actions

Setelah pertama kali berhasil, setiap push ke `main` akan trigger GitHub Actions yang menjalankan ulang deploy otomatis.

---

## 🌐 LANGKAH 3 — Setup AWS Amplify (Frontend)

### 3.1 Hubungkan Amplify ke GitHub

1. Buka **AWS Console → AWS Amplify**
2. Klik **"New app" → "Host web app"**
3. Pilih **GitHub** → Klik **Authorize AWS Amplify**
4. Pilih repository: `<username>/<repo-name>`
5. Pilih branch: `main`
6. **App name:** `myapp-frontend`
7. **Build settings:** Amplify otomatis deteksi dari `frontend/amplify.yml`
8. **Environment variables:**
   - `VITE_API_URL` = `https://<beanstalk-url>.ap-southeast-1.elasticbeanstalk.com/api`
9. Klik **"Save and deploy"**

### 3.2 Dapatkan Amplify App ID

```bash
# Setelah Amplify app dibuat
aws amplify list-apps --query 'apps[0].appId' --output text
# Tambahkan ke GitHub Secrets sebagai: AMPLIFY_APP_ID
```

### 3.3 Tambahkan Secret AMPLIFY_APP_ID dan VITE_API_URL

```
GitHub Secrets:
- AMPLIFY_APP_ID   → App ID dari step 3.2
- VITE_API_URL     → https://<beanstalk-url>/api
```

---

## 🚀 LANGKAH 4 — Deploy Backend ke Elastic Beanstalk

### 4.1 Update Environment Variable Beanstalk

```bash
# Dapatkan Beanstalk URL
EB_URL=$(aws cloudformation describe-stacks \
  --stack-name myapp-beanstalk \
  --query 'Stacks[0].Outputs[?OutputKey==`BeanstalkURL`].OutputValue' \
  --output text)
echo "Beanstalk URL: $EB_URL"

# Update environment variable API Gateway URL
API_URL=$(aws cloudformation describe-stacks \
  --stack-name myapp-apigateway \
  --query 'Stacks[0].Outputs[?OutputKey==`APIEndpoint`].OutputValue' \
  --output text)

aws elasticbeanstalk update-environment \
  --environment-name myapp-backend-env \
  --option-settings \
    Namespace=aws:elasticbeanstalk:application:environment,OptionName=API_GATEWAY_URL,Value=${API_URL} \
    Namespace=aws:elasticbeanstalk:application:environment,OptionName=DB_NAME,Value=myappdb \
    Namespace=aws:elasticbeanstalk:application:environment,OptionName=DB_USER,Value=myappuser
```

### 4.2 Deploy Manual Backend (Opsional)

```bash
cd backend
npm install
zip -r ../backend-deploy.zip . -x "node_modules/*"
cd ..

aws s3 cp backend-deploy.zip s3://${BUCKET_NAME}/backend/

aws elasticbeanstalk create-application-version \
  --application-name myapp-backend \
  --version-label manual-v1 \
  --source-bundle S3Bucket=${BUCKET_NAME},S3Key=backend/backend-deploy.zip

aws elasticbeanstalk update-environment \
  --application-name myapp-backend \
  --environment-name myapp-backend-env \
  --version-label manual-v1
```

---

## 🔄 LANGKAH 5 — Alur CI/CD GitHub Actions

Setelah semua setup selesai, alur otomatis adalah:

```
Push ke GitHub main
        │
        ├─► deploy-infrastructure.yml  (jika ada perubahan di cloudformation/)
        │       └─► Validate + Deploy CloudFormation stacks
        │
        ├─► deploy-backend.yml         (jika ada perubahan di backend/)
        │       └─► Test → Build → Upload S3 → Deploy Beanstalk
        │
        ├─► deploy-lambda.yml          (jika ada perubahan di lambda/)
        │       └─► Test → Package → Upload S3 → Update Lambda
        │
        └─► deploy-frontend.yml        (jika ada perubahan di frontend/)
                └─► Build → Trigger Amplify Release
```

---

## 🧪 LANGKAH 6 — Testing

### 6.1 Test Lambda via AWS CLI

```bash
# Dapatkan API Gateway URL
API_URL=$(aws cloudformation describe-stacks \
  --stack-name myapp-apigateway \
  --query 'Stacks[0].Outputs[?OutputKey==`APIEndpoint`].OutputValue' \
  --output text)

echo "API URL: $API_URL"

# --- TEST POST (Insert Data) ---
curl -X POST "${API_URL}/data" \
  -H "Content-Type: application/json" \
  -d '{"name":"sensor-suhu","value":28.5,"category":"sensor"}' \
  -w "\nHTTP Status: %{http_code}\n"

# --- TEST GET (Ambil Data) ---
curl "${API_URL}/data" -w "\nHTTP Status: %{http_code}\n"

# --- TEST GET dengan Filter ---
curl "${API_URL}/data?category=sensor&limit=5"

# --- TEST Validasi (harus return 400) ---
curl -X POST "${API_URL}/data" \
  -H "Content-Type: application/json" \
  -d '{"value":10}' \
  -w "\nHTTP Status: %{http_code}\n"
```

### 6.2 Test Backend Health Check

```bash
EB_URL=$(aws cloudformation describe-stacks \
  --stack-name myapp-beanstalk \
  --query 'Stacks[0].Outputs[?OutputKey==`BeanstalkURL`].OutputValue' \
  --output text)

curl "http://${EB_URL}/health" -w "\nHTTP: %{http_code}\n"
```

### 6.3 Unit Test Lambda (Python)

```bash
cd lambda
pip install pytest psycopg2-binary
pytest tests/ -v
```

### 6.4 Unit Test Backend (Node.js)

```bash
cd backend
npm install
npm test
```

### 6.5 Load Test (High Traffic) — Perlu install Artillery

```bash
npm install -g artillery

# Jalankan load test (sudah ada di load-test.yml)
artillery run load-test.yml --output results.json
artillery report results.json
# Buka results.json.html di browser
```

### 6.6 Cek CloudWatch Logs Lambda

```bash
# Log POST Lambda
aws logs tail /aws/lambda/myapp-post-handler --follow

# Log GET Lambda
aws logs tail /aws/lambda/myapp-get-handler --follow
```

---

## 📊 Monitoring & Alerting

```bash
# Cek status semua stack
for stack in myapp-vpc myapp-rds myapp-storage myapp-beanstalk myapp-lambda myapp-apigateway; do
  STATUS=$(aws cloudformation describe-stacks \
    --stack-name $stack \
    --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND")
  echo "$stack: $STATUS"
done

# Cek Lambda invocations 1 jam terakhir
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=myapp-post-handler \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 --statistics Sum --output table
```

---

## 💰 Estimasi Biaya

| Service | Free Tier | Biaya Normal |
|---|---|---|
| **Amplify** | 1.000 build menit/bulan | ~$0.01/build menit |
| **Elastic Beanstalk** | t3.micro 750 jam/bulan | ~$8/bulan |
| **Lambda** | 1 juta request + 400K GB-detik | ~$0.20/1M request |
| **API Gateway** | 1 juta API call/bulan | ~$3.50/1M call |
| **RDS db.t3.micro** | 750 jam/bulan, 20GB | ~$13/bulan |
| **S3** | 5GB, 20K GET request | ~$0.023/GB |
| **EFS** | 5GB | ~$0.30/GB |
| **Total** | **~$0 (Free Tier)** | **~$25-35/bulan** |

> ⚡ **High Availability:** Aktifkan RDS Multi-AZ + Beanstalk MinSize=2 → ~$50-60/bulan

---

## ✅ Checklist Deployment

**Persiapan:**
- [ ] AWS CLI terinstall dan terkonfigurasi
- [ ] Node.js 20 dan Python 3.12 terinstall
- [ ] IAM User untuk GitHub Actions dibuat
- [ ] Repo GitHub dibuat dan kode di-push

**CloudFormation:**
- [ ] Artifact S3 bucket dibuat
- [ ] Stack `myapp-vpc` — ✅ CREATE_COMPLETE
- [ ] Stack `myapp-rds` — ✅ CREATE_COMPLETE
- [ ] Stack `myapp-storage` — ✅ CREATE_COMPLETE
- [ ] Stack `myapp-beanstalk` — ✅ CREATE_COMPLETE
- [ ] Stack `myapp-lambda` — ✅ CREATE_COMPLETE
- [ ] Stack `myapp-apigateway` — ✅ CREATE_COMPLETE

**Aplikasi:**
- [ ] Amplify terhubung ke GitHub
- [ ] GitHub Secrets dikonfigurasi (6 secrets)
- [ ] Beanstalk env var `API_GATEWAY_URL` diset
- [ ] Frontend accessible via Amplify URL

**Testing:**
- [ ] POST data berhasil (HTTP 201)
- [ ] GET data berhasil (HTTP 200)
- [ ] Validasi error berhasil (HTTP 400)
- [ ] Frontend menampilkan grafik
- [ ] Load test Artillery dijalankan
