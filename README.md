# Pharmacy Mobile Survey App

Ứng dụng Flutter khảo sát thực địa nhà thuốc dành cho nhân viên doanh nghiệp trong hệ thống Pharmacy Map.

---

# Công nghệ sử dụng

- Flutter
- Dart
- flutter_map
- OpenStreetMap
- Dio
- Geolocator
- PostgreSQL
- Node.js + Express Backend
- JWT Authentication

---

# Chức năng chính

## Đăng nhập nhân viên khảo sát
- Đăng nhập bằng tài khoản được doanh nghiệp cấp
- Phân quyền role:
    - admin
    - company
    - company_staff
    - user

---

## Hiển thị vùng khảo sát được giao
- Sau khi đăng nhập:
    - Tự động lấy vùng khảo sát được giao từ backend
    - Tự động zoom tới polygon khu vực
    - Chỉ hiển thị nhà thuốc bên trong vùng được giao

---

## Hiển thị danh sách nhà thuốc cần khảo sát
- Hiển thị:
    - Nhà thuốc chưa khảo sát
    - Địa chỉ
    - Marker trên bản đồ
- Có thể bấm để:
    - Focus tới nhà thuốc
    - Xem chi tiết

---

## Định vị GPS thực địa
- Lấy vị trí GPS hiện tại
- Hiển thị vị trí nhân viên trên bản đồ
- Kiểm tra khoảng cách tới nhà thuốc

---

## Khảo sát thực địa
Chỉ cho phép khảo sát khi:
- Nhân viên đứng gần nhà thuốc thực tế

Sau khi khảo sát có thể:
- Cập nhật thông tin nhà thuốc
- Cập nhật số điện thoại
- Cập nhật trạng thái
- Cập nhật nhóm sản phẩm
- Upload ảnh thực tế
- Đánh dấu:
    - Đã khảo sát

---

## Chỉ đường Google Maps
- Mở Google Maps
- Điều hướng tới nhà thuốc

---

## Upload ảnh khảo sát
- Chụp ảnh từ camera
- Chọn ảnh từ thư viện
- Upload ảnh lên backend

---

# Cấu trúc thư mục

```bash
lib/
│
├── models/
│   ├── pharmacy_model.dart
│   └── user_model.dart
│
├── screens/
│   ├── auth/
│   ├── map/
│   ├── splash/
│   └── role/
│
├── services/
│   ├── api_service.dart
│   ├── auth_service.dart
│   ├── pharmacy_service.dart
│   └── survey_area_service.dart
│
├── widgets/
│
└── main.dart