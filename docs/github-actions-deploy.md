# GitHub Actions — Build, Inject Config, Deploy

> นอก scope โปรเจกต์นี้ — reference สำหรับเรียนรู้ pattern production จริง

---

## ภาพรวม

```
Developer push code to main
        │
        ▼
GitHub Actions (CI/CD runner)
        ├─ build React
        ├─ build Docker image
        ├─ push image → Docker Hub / ECR
        └─ SSH เข้า server → pull image → restart container
                │
                ▼
           AWS EC2 (server)
                ├─ nginx (reverse proxy + static)
                ├─ container: React build
                └─ container: Express backend
```

---

## ทำไมต้อง Docker

**ไม่มี Docker:** ต้อง install Node, set PATH, manage version บน server เอง — ทำบน server 2 ตัวต่างกัน อาจได้ผลต่างกัน

**มี Docker:** pack app + dependencies ทุกอย่างใน image เดียว — run ที่ไหนก็ได้เหมือนกันเป๊ะ

```
"works on my machine" → Docker → "works everywhere"
```

---

## Dockerfile

### Frontend

```dockerfile
# frontend/Dockerfile

# Stage 1: build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
# output อยู่ที่ /app/dist

# Stage 2: serve ด้วย nginx
FROM nginx:alpine
COPY --from=builder /app/dist /var/www/app
COPY nginx.conf /etc/nginx/conf.d/default.conf
# config.json จะถูก inject ทีหลังตอน deploy
EXPOSE 80
```

### Backend

```dockerfile
# backend/Dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
EXPOSE 3001
CMD ["node", "src/index.js"]
```

---

## docker-compose.yml (สำหรับรันบน server)

```yaml
# docker-compose.yml
services:
  frontend:
    image: myuser/crud-demo-frontend:latest
    ports:
      - "80:80"
    volumes:
      # mount config.json เข้าไป — แก้ได้โดยไม่ต้อง build image ใหม่
      - ./config/config.json:/var/www/config/config.json:ro
    depends_on:
      - backend

  backend:
    image: myuser/crud-demo-backend:latest
    ports:
      - "3001:3001"
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - JWT_SECRET=${JWT_SECRET}
    env_file:
      - .env.production
```

---

## GitHub Actions Workflow

```yaml
# .github/workflows/deploy.yml
name: Build and Deploy

on:
  push:
    branches: [main]

env:
  DOCKER_IMAGE_FE: myuser/crud-demo-frontend
  DOCKER_IMAGE_BE: myuser/crud-demo-backend

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      # Login Docker Hub
      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      # Build + Push Frontend image
      - name: Build & Push Frontend
        uses: docker/build-push-action@v5
        with:
          context: ./frontend
          push: true
          tags: ${{ env.DOCKER_IMAGE_FE }}:latest

      # Build + Push Backend image
      - name: Build & Push Backend
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          push: true
          tags: ${{ env.DOCKER_IMAGE_BE }}:latest

      # SSH เข้า EC2 แล้ว deploy
      - name: Deploy to EC2
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ec2-user
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            cd /home/ec2-user/crud-demo

            # inject config.json ก่อน (URL จริงจาก Secrets)
            mkdir -p config
            cat > config/config.json <<EOF
            {
              "REACT_APP_API_ENDPOINT": "${{ secrets.API_ENDPOINT }}"
            }
            EOF

            # pull image ใหม่ แล้ว restart
            docker compose pull
            docker compose up -d --remove-orphans
```

---

## GitHub Secrets ที่ต้องตั้ง

ไปที่: `GitHub repo → Settings → Secrets and variables → Actions`

| Secret | ค่า | ใช้ตรงไหน |
|---|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub username | push image |
| `DOCKERHUB_TOKEN` | Docker Hub access token | push image |
| `EC2_HOST` | IP หรือ domain ของ EC2 | SSH deploy |
| `EC2_SSH_KEY` | private key (PEM) ของ EC2 | SSH deploy |
| `API_ENDPOINT` | URL backend จริง | inject config.json |

---

## AWS EC2 — Setup ครั้งแรก

```bash
# 1. launch EC2 instance (Amazon Linux 2023 หรือ Ubuntu)
#    เปิด Security Group: port 22 (SSH), 80 (HTTP), 443 (HTTPS)

# 2. SSH เข้าไป
ssh -i mykey.pem ec2-user@<EC2_IP>

# 3. install Docker
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user

# 4. install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 5. สร้าง folder สำหรับ project
mkdir -p /home/ec2-user/crud-demo/config
# วาง docker-compose.yml และ .env.production ไว้ที่นี่
```

---

## Flow สรุป

```
dev แก้ code
      ↓
git push main
      ↓
GitHub Actions:
  build image → push Docker Hub → SSH EC2 → inject config.json → docker compose up
      ↓
EC2 run containers:
  nginx (frontend + config.json) ←→ Express (backend)
```

---

## เทียบ approach การ deploy

| | SCP dist/ | Docker |
|---|---|---|
| setup | ง่าย | ซับซ้อนกว่า |
| reproducible | ❌ ขึ้นกับ server env | ✅ เหมือนกันทุกที่ |
| rollback | ยาก | `docker pull image:prev-tag` |
| scale | manual | ง่าย (ECS, Kubernetes) |

สำหรับ project เรียนรู้ — SCP พอ, Docker เรียนไว้เพื่อเข้าใจ production จริง
