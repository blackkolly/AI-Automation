# Kubernetes Backup Storage Location Guide

## 📁 Where are your backups stored?

Your Kubernetes backups are stored in the following locations:

### 🖥️ Windows File System Location
```
C:\Users\hp\AppData\Local\Temp\k8s-backups\
```

### 🐧 GitBash/Linux Path (in your terminal)
```
/tmp/k8s-backups/
```

## 🗂️ Current Backup Structure

```
C:\Users\hp\AppData\Local\Temp\k8s-backups\
├── 20250810-214803/          # Backup from Aug 10, 2025 at 21:48:03
├── 20250810-223331/          # Backup from Aug 10, 2025 at 22:33:31
└── 20250810-223431/          # Backup from Aug 10, 2025 at 22:34:31
```

### 📋 Each backup directory contains:
- **cluster/** - Kubernetes cluster-level resources (nodes, PVs, storage classes)
- **namespaces/** - Individual namespace backups (microservices, default, kube-system, etc.)

## 🔍 How to Access Your Backups

### Method 1: Windows File Explorer
1. Open File Explorer
2. Navigate to: `C:\Users\hp\AppData\Local\Temp\k8s-backups\`
3. Browse the timestamped backup folders

### Method 2: Command Line (GitBash)
```bash
# List all backups
ls -la /tmp/k8s-backups/

# View specific backup contents
ls -la /tmp/k8s-backups/20250810-223431/

# View backup structure
tree /tmp/k8s-backups/20250810-223431/
```

### Method 3: Quick Windows Access
- Press `Win + R`
- Type: `%TEMP%\k8s-backups`
- Press Enter

## 📊 Backup Details
- **Format**: YAML files
- **Size**: ~2.1MB per backup
- **Frequency**: On-demand (manual execution)
- **Retention**: Manual cleanup required
- **Compression**: None (raw YAML files)

## 🔧 Storage Management

### View backup sizes:
```bash
du -sh /tmp/k8s-backups/*
```

### Clean old backups (keep last 5):
```bash
cd /tmp/k8s-backups
ls -t | tail -n +6 | xargs -r rm -rf
```

### Check available space:
```bash
df -h /tmp
```

## ⚠️ Important Notes

1. **AppData\Local\Temp** is a temporary directory that may be cleaned by Windows
2. For production systems, consider moving backups to a permanent location
3. The backup location can be changed by modifying the scripts
4. Current setup stores ~3 successful backups

## 🚀 Quick Commands Reference

```bash
# View latest backup
ls -la /tmp/k8s-backups/$(ls -t /tmp/k8s-backups/ | head -1)/

# Count backup files
find /tmp/k8s-backups/ -name "*.yaml" | wc -l

# Find largest backup
du -sh /tmp/k8s-backups/* | sort -hr | head -1
```

---
*Generated on: August 10, 2025*
*Backup System: Kubernetes Local Backup Solution*
