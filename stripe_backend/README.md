# Stripe Payment Backend

Backend Node.js để xử lý thanh toán Stripe cho Flutter app.

## 🚀 Cài đặt

```bash
cd stripe_backend
npm install
```

## ▶️ Chạy server

```bash
npm start
```

Hoặc dùng file `start.bat`:
```bash
start.bat
```

## 📡 Endpoints

- **POST** `/api/create-payment-intent` - Tạo Payment Intent
- **GET** `/api/payment-intent/:id` - Lấy trạng thái Payment Intent

## 🔑 Environment Variables

File `.env`:
```
STRIPE_SECRET_KEY=sk_test_...
PORT=3000
```

## 🧪 Test với Stripe Test Cards

### Thành công:
- **4242 4242 4242 4242** - Visa
- **5555 5555 5555 4444** - Mastercard

### Thất bại:
- **4000 0000 0000 0002** - Card declined
- **4000 0000 0000 9995** - Insufficient funds

**MM/YY:** Bất kỳ ngày tương lai  
**CVC:** Bất kỳ 3 số

## 📱 Android Emulator

Từ Android Emulator, truy cập:
```
http://10.0.2.2:3000
```

## 🔒 Security

⚠️ **QUAN TRỌNG:**
- KHÔNG commit file `.env` vào Git
- Secret key CHỈ dùng trong backend, KHÔNG bao giờ đưa vào Flutter code
- File `.env` đã được thêm vào `.gitignore`

## 📚 Documentation

- [Stripe API Docs](https://stripe.com/docs/api)
- [Stripe Testing](https://stripe.com/docs/testing)

