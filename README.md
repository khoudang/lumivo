# Lumivo

Ứng dụng mô phỏng nhà thông minh bằng Flutter + Riverpod. Lumivo dùng thiết bị ảo, chưa điều khiển phần cứng BLE/MQTT thật.

## Chức năng

- Quản lý nhà, phòng và thiết bị mô phỏng.
- Điều khiển thiết bị, chạy scene và xây dựng automation.
- Theo dõi hoạt động, điện năng mô phỏng và tình trạng thiết bị.
- Backup/restore, cài đặt tiếng Việt/Anh và tùy chọn hiển thị.

Số liệu điện năng/cảm biến là dữ liệu mô phỏng, không phải số đo từ thiết bị thật.

## Chạy và kiểm tra

Yêu cầu Flutter SDK tương thích với Dart `>=3.5.0 <4.0.0`.

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d edge
```

Build web:

```sh
flutter build web --release
```

Phục vụ thư mục `build/web` qua HTTP; không mở `index.html` trực tiếp bằng `file://`.

## Cấu trúc

- `lib/app`: khởi động ứng dụng và providers.
- `lib/core`: models, theme, localization và repository contracts.
- `lib/features`: giao diện và trạng thái theo chức năng.
- `lib/services`: mô phỏng, lưu trữ, backup và các service hỗ trợ.
- `test`: unit, widget và bài kiểm tra hiệu năng mô phỏng.
- `docs`: đặc tả và các báo cáo theo giai đoạn.

## Phạm vi kiểm chứng

Các báo cáo phase cũ là ảnh chụp trạng thái tại thời điểm viết, không chứng minh bản hiện tại đã chạy tốt trên mọi nền tảng. Cần chạy lại test/build trước khi phát hành. Test tự động không thay thế việc xem giao diện, thử trên thiết bị thật hoặc nghiệm thu thẩm mỹ.

Android cần Android SDK đầy đủ; build iOS cần macOS/Xcode. Không coi một bản web build thành công là bằng chứng Android/iOS đã sẵn sàng phát hành.
