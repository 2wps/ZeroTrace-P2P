# 🧅 تشغيل المنظومة عبر شبكة Tor (Tor Onion Hidden Services)

لتوفير أعلى درجات التخفي ومقاومة الرقابة الحكومية وحجب الـ ISP، يمكن تشغيل خادم الإشارات وواجهة التطبيق بالكامل كخدمات مخفية داخل شبكة **Tor (.onion)**.

---

## 🔒 المزايا الأمنية عند التشغيل عبر Tor:
1. **إخفاء عنوان الـ IP الحقيقي:** لا يمكن للمزود أو خادم الإشارات أو المتلصصين معرفة الـ IP الجغرافي للمضيف أو الضيف.
2. **تجاوز جدران الحماية الصارمة (Firewall & CGNAT Bypass):** اتصالات الـ Onion تخترق بطبيعتها كافة أنواع الـ NAT ومزودي الاتصالات دون الحاجة لفتح منافذ Port Forwarding.
3. **تشفير إضافي من النهاية للنهاية (Onion Routing E2EE):** مرور الحزم عبر 3 طبقات حماية وتشفير متداخلة (Circuit Nodes).

---

## 🛠️ خطوات التشغيل السريع:

### 1. تثبيت حزمة Tor:
- **على Ubuntu / Debian:**
  ```bash
  sudo apt update && sudo apt install tor -y
  ```

### 2. نسخ ملف التكوين:
```bash
sudo cp d:/DEV/amr/tor/torrc /etc/tor/torrc
sudo systemctl restart tor
```

### 3. استخراج عناوين الـ Onion:
```bash
# عنوان خادم الإشارات
sudo cat /var/lib/tor/zero_trace_signaling/hostname

# عنوان واجهة الويب
sudo cat /var/lib/tor/zero_trace_web/hostname
```

سيكون العنوان بصيغة:
`http://v2x7q9y4a5b6c7d8...onion`

---

## 🌐 فتح الرابط في متصفح Tor Browser:
- يفتح المضيف متصفح **Tor Browser** ويتجه للعنوان `http://...onion`
- يولد الرابط المشفر ويشاركه مع الضيف الذي يفتحه في Tor Browser على هاتفه أو حاسوبه.
