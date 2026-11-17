# Calm Home — định hướng giao diện Lumivo

## Mục tiêu

Bề mặt chính là **điều khiển (Operate)**: người dùng chọn phòng, thấy thiết bị đang bật/tắt và thao tác ngay. Không thiết kế dashboard như landing page quảng cáo hoặc bảng điều hành kỹ thuật.

## Ngôn ngữ thiết kế

- Nền sáng ấm, chữ charcoal và điểm nhấn xanh rừng; chế độ tối dùng neutral tương ứng, không neon.
- Phân cấp bằng kích thước chữ, khoảng cách và nhóm nội dung trước khi thêm khung hoặc màu.
- Chỉ một thao tác chính trên một thẻ thiết bị. Bật/tắt thể hiện cả bằng chữ/biểu tượng lẫn màu.
- Thiết bị offline, đang gửi lệnh và lỗi phải khác trạng thái bình thường.
- Chuyển động ngắn để thể hiện thay đổi, không chạy nền liên tục; tôn trọng giảm chuyển động.
- Không dùng ảnh phòng có bản quyền chưa rõ, font tải từ mạng, số liệu trang trí hoặc hình minh họa giả làm dữ liệu thật.

## Thứ tự thông tin

1. Nhà đang chọn và thông báo cần xử lý.
2. Phòng và thiết bị có thể điều khiển.
3. Scene thường dùng.
4. Chỉ số điện năng, tình trạng hệ thống và công cụ mô phỏng qua màn phụ.

## Tham khảo

Chỉ áp dụng nguyên tắc chung, không lấy asset hoặc sao chép giao diện nguyên xi:

- https://github.com/mitchkoko/ModernSmartHomeUI — sự đơn giản của điều khiển và tương phản bật/tắt.
- https://github.com/vietmx/flutter-smart_home_ui — tổ chức theo không gian sống.
- https://github.com/abuanwar072/Smart-Home-Animated-App-using-Flutter — chuyển động liên tục giữa phòng và thiết bị; không sao chép code/asset chưa rõ license.

## Nghiệm thu

- Giao diện chạy thật ở 390×844; kiểm tra thêm chiều rộng 320 và chữ lớn.
- Thao tác thiết bị xuất hiện sớm, thay cho màn hình đầu toàn thẻ chỉ số.
- Màu chữ và nền phải theo theme trên các màn đã chuyển đổi.
- Kiểm tra cả tiếng Việt/Anh và dark/OLED, không coi screenshot tiếng Anh là bằng chứng localization hoàn chỉnh.
- Test tự động bảo vệ chức năng; ảnh chạy thật bảo vệ bố cục. Không đồng nhất hai loại bằng chứng này.

## Baseline đã chạy

Commit gốc `2cc3e70`, nhánh cải tiến `improve/lumivo-calm-home`.

- Flutter 3.47.7 / Dart 3.13.5.
- `flutter analyze`: không có issue.
- `flutter test --reporter expanded`: 660 tests passed.
- Build web release của commit gốc thành công; đã xem dashboard thực tế 390×844 qua browser.
- Android SDK hiện thiếu cmdline-tools; chưa có nghiệm thu Android/iOS. Không cài thêm toolchain hoặc phát hành trong phạm vi cải tiến này.

Kết quả candidate cuối cùng được ghi riêng sau khi tích hợp; baseline không chứng minh candidate mới đã pass.
