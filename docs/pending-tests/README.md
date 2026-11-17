# Các ca mục tiêu giao diện chưa triển khai

`calm_secondary_screens_test.dart.pending` giữ nguyên 10 ca RED do worker tạo, cho Settings, Rooms, Device Detail, Automation và Profile ở light/dark, chiều rộng 320 và text scale 2.

Đây là **mục tiêu của đợt chuyển đổi màn phụ chưa hoàn tất**, không nằm trong bộ test release đang thực thi. Không tính các ca này là PASS và không dùng số test xanh của bộ hiện tại để tuyên bố các màn này đã đạt mục tiêu mới.

Worker đã chạy và thấy RED: nền cứng theo dark theme, gradient/glow chưa chuyển đổi và một số overflow khi chữ lớn. Chưa sửa presentation của các màn này: bước áp dụng script chỉnh sửa bị hệ thống chặn vì approval không hoàn tất, kèm yêu cầu không thử lại bằng công cụ khác. Phạm vi đó được dừng, không lách qua đường khác.

Để tránh giao diện chữ/nền lệch theme, bản tích hợp giữ các màn legacy ở dark theme; dashboard mới dùng palette riêng theo lựa chọn đã lưu. Vì vậy đây chưa phải một app đã được chuyển toàn bộ sang light/dark nhất quán.

Có thể dùng file pending làm đầu vào cho một lượt chuyển đổi riêng sau khi phạm vi được cho phép tiếp tục; trước khi kích hoạt lại cần xem lại fixture, tiêu chí và các thay đổi source hiện tại.
