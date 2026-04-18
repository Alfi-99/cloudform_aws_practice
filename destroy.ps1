$PREFIX = "alfi"
$REGION = "ap-southeast-1"
$ACCOUNT_ID = aws sts get-caller-identity --query "Account" --output text
$ARTIFACT_BUCKET = "$PREFIX-artifacts-$ACCOUNT_ID"
$STORAGE_BUCKET = "$PREFIX-storage-$ACCOUNT_ID-$REGION"

Write-Host "=== 🗑️ MEMULAI PEMBERSIHAN TOTAL AWS (Prefix: $PREFIX) ===" -ForegroundColor Yellow

# 1. Kosongkan S3 Buckets
foreach ($bucket in @($ARTIFACT_BUCKET, $STORAGE_BUCKET)) {
    if (aws s3 ls "s3://$bucket" 2>$null) {
        Write-Host "🧹 Mengosongkan bucket: $bucket"
        aws s3 rm "s3://$bucket" --recursive 2>$null
        # Hapus versi (jika ada)
        aws s3api list-object-versions --bucket $bucket --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json 2>$null | 
            ConvertFrom-Json | Select-Object -ExpandProperty Objects -ErrorAction SilentlyContinue | ForEach-Object {
                aws s3api delete-object --bucket $bucket --key $_.Key --version-id $_.VersionId 2>$null
            }
    }
}

# 2. Update RDS - Matikan Deletion Protection
Write-Host "🔓 Menonaktifkan RDS Deletion Protection..."
aws rds modify-db-instance --db-instance-identifier "$PREFIX-postgres" --no-deletion-protection --apply-immediately --region $REGION 2>$null
Start-Sleep -Seconds 30

# 3. Hapus Stack berurutan
$stacks = @("$PREFIX-apigateway", "$PREFIX-lambda", "$PREFIX-beanstalk", "$PREFIX-storage", "$PREFIX-rds", "$PREFIX-vpc")

foreach ($stack in $stacks) {
    Write-Host "🗑️ Menghapus stack: $stack..."
    aws cloudformation delete-stack --stack-name $stack --region $REGION
    Write-Host "⏳ Menunggu $stack selesai dihapus..."
    aws cloudformation wait stack-delete-complete --stack-name $stack --region $REGION
    Write-Host "✅ $stack BERHASIL DIHAPUS" -ForegroundColor Green
}

# 4. Hapus Artifact Bucket (setelah stack dihapus)
Write-Host "🗑️ Menghapus Artifact Bucket..."
aws s3api delete-bucket --bucket $ARTIFACT_BUCKET --region $REGION 2>$null

Write-Host "==========================================" -ForegroundColor Green
Write-Host "🚀 PEMBERSIHAN SELESAI: SEMUA RESOURCE AWS TELAH DIHAPUS" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
