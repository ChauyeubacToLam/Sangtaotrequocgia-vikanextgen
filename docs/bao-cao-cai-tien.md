# Báo cáo cải tiến Vika · Chặng 1 (bản nháp)

Bản nháp ngày 23/11/2026. Ô `[ĐIỀN]` là số liệu chưa thu, điền khi có. Không điền số ước đoán vào các ô này.

## 1. Tóm tắt

Vika là ứng dụng HLV AI cho người Việt tự tập tại nhà: camera điện thoại theo dõi người tập, 33 điểm khớp
MediaPipe được tính ngay trên máy, ứng dụng đếm rep, phát hiện lỗi tư thế và nhắc bằng giọng nói tiếng Việt.

Sau vòng góp ý, nhóm **giữ nguyên quy trình tập tại nhà** (giới thiệu bài → tập → nghỉ → chuyển bài → tổng kết)
và làm tốt hơn từng bước: sửa độ chính xác của từng bài dựa trên log đo trên máy thật, thêm cơ chế dừng chấm khi
camera không nhìn rõ, thêm công cụ thu số liệu để kiểm chứng độc lập, làm lại giao diện, và thêm hai tính năng
mới hỗ trợ việc tập đều đặn: **dinh dưỡng** và **lịch tập có nhắc nhở**.

## 2. Hiện trạng sản phẩm trước cải tiến

Các số dưới đây đo trên bản iOS đang phát hành (1.0.3). Toàn bộ cải tiến ở mục 4 chưa có trên bản này, nên đây
là **mốc so sánh**.

### 2.1. App Store Connect (90 ngày, 18/8 – 15/11/2026)

| Chỉ số | Vika | So với nhóm Health & Fitness (Apple benchmark) |
|---|---|---|
| Lượt tải lần đầu | 1.153 | — |
| Tỉ lệ chuyển đổi (xem trang → tải) | 12,50% | Giữa bách phân vị 50 (~4,87%) và 75 (~15,09%) |
| Giữ chân ngày 1 | 25,00% | Giữa bách phân vị 25 (~18,51%) và 50 (~27,14%) |
| Giữ chân ngày 7 | 25,00% | Trên bách phân vị 75 (~19,49%) |
| Tỉ lệ crash | Apple chưa đủ dữ liệu để xếp hạng | — |

Lượt tải theo ngày có ba đỉnh: cuối tháng 9, đầu tháng 10 (khoảng 110 lượt/ngày) và khoảng 8/11 (gần 190 lượt/ngày).
Nguồn của từng đỉnh: `[ĐIỀN: bài đăng / sự kiện / chiến dịch]`.

Lưu ý khi đọc: giữ chân ngày 1 và ngày 7 cùng bằng 25% cho thấy nhóm người dùng đo được còn nhỏ. Cần đọc cùng số
người của từng nhóm: `[ĐIỀN: số người trong cohort]`.

### 2.2. Phễu trong app

Kỳ đo: `[ĐIỀN]`.

| Bước | Số người | Tỉ lệ qua bước | Thay đổi so với kỳ trước |
|---|---|---|---|
| Mở app | 181 | — | — |
| Hoàn tất onboarding | 130 | 72% | giảm 7 |
| Bắt đầu tập | 83 | 64% | tăng 11 |
| Xong buổi tập | 12 | 14% | tăng 10 |

Chỉ 12/181 người (6,6%) đi hết một buổi tập. **Chỗ rơi lớn nhất là trong lúc tập**: 83 người bắt đầu, 12 người
xong. Phần lớn cải tiến ở mục 4.1 và 4.2 nhắm vào bước này.

## 3. Trả lời ba yêu cầu của giám khảo

| Yêu cầu | Đã làm | Số liệu |
|---|---|---|
| 1. Kiểm chứng trên mẫu độc lập | Bộ ghi log từng hiệp, tiếng bíp đồng bộ video, hướng dẫn gán nhãn cho HLV, script `evaluate.py` tính precision/recall kèm khoảng tin cậy Wilson 95%. Giới hạn kiểm chứng ở 4 bài: squat, chống đẩy, cầu mông, plank. 20 bài còn lại gắn nhãn "Chỉ đếm, chưa kiểm chứng" ngay trong app. | `[ĐIỀN: số người, số rep, bảng precision/recall, confusion matrix, kappa]` |
| 2. An toàn khi camera thiếu quan sát | Dừng chấm khi thiếu điểm khớp hoặc độ tin cậy thấp, kèm lời nhắc đúng lý do. Tự tạm dừng khi người rời khung. Hướng dẫn đặt máy ở trang giới thiệu bài. Dòng "AI nhìn rõ X% thời gian tập", dưới 80% thì nhắc kiểm tra vị trí máy. Nút "Báo sai" cạnh từng lỗi. Script `camera_safety.py`. | `[ĐIỀN: bảng 6 tình huống × số lần thử, độ trễ phát hiện, rep ghi nhầm, thời gian hồi phục]` |
| 3. Giá trị của phản hồi AI | Hai điều kiện trong app: `ai` (có nhắc) và `control` (vẫn có video hướng dẫn nhưng không nhắc lỗi). Hỏi mức hài lòng sau buổi. | `[ĐIỀN: tỉ lệ lỗi có AI so với không AI, tỉ lệ sửa sau nhắc, báo nhầm, mức hài lòng, 1 ca thành công, 1 ca thất bại]` |

## 4. Những gì đã thay đổi

### 4.1. Lõi AI: sửa độ chính xác bằng số đo trên máy thật

Mỗi lần sửa đều bắt đầu từ log trên máy thật, đo ra nguyên nhân rồi mới sửa. Chi tiết trong
`docs/field-test-log.md`. Các lần thử dưới đây do nhóm tự làm để **tìm và sửa lỗi**. Đây **không phải** kiểm chứng
độc lập; kiểm chứng độc lập là mục 3.

| Bài | Trước khi sửa | Sau khi sửa |
|---|---|---|
| Squat, lỗi "xuống quá nhanh" | 17/17 rep bị báo (đo được thời gian xuống chỉ ~0,2 s vì chỉ đo một đoạn của pha xuống) | 0/8 rep bị báo, thời gian xuống đo đúng 0,69–1,08 s |
| Squat, lỗi "gót chân nhấc" | Báo cả khi đang đứng yên (do góc máy) | Bỏ lỗi này; 0/8 rep báo sai |
| Chống đẩy tường, "tay rời tường" | 7/10 rep bị báo | 0/21 rep |
| Cầu mông, "nhấc đầu" | 7/7 rep bị báo (độ lệch cố định tai–vai bị hiểu là ngẩng đầu) | 0/22 rep |
| Plank, mạch giữ | Mạch giữ bị đứt liên tục, dài nhất ~6,3 s; nhắc "Chống bằng cẳng tay" 8 lần không đúng lý do | `[ĐIỀN: số đo sau sửa]` |
| Squat, lỗi hông lên trước vai | 3/8 và 6/9 rep bị báo, nghi báo sai | Đã đổi cách đo, `[ĐIỀN: số đo sau sửa]` |

Ngoài ra:
- Sửa lỗi đếm sai rep của nhiều bài: cầu mông đếm cả khi hông chưa về sàn; chống đẩy tường đếm một lần thành hai;
  tricep dip không đếm được rep nào.
- Plank và chống đẩy: dấu của độ võng lưng tính từ hình học điểm khớp, không còn đảo chiều theo hướng quay người.
- Thêm 3 bài, nâng tổng số bài lên 24: bước bục (step-up), giãn cổ nghiêng, chống đẩy xoay người. Ba bài này
  hiện chỉ đếm, chưa đo ngưỡng.
- Khung xương hiển thị được nội suy giữa các lần nhận diện nên chuyển động mượt hơn. Phần đếm rep vẫn dùng kết
  quả nhận diện gốc.
- Camera chuyển sang tỉ lệ 4:3 toàn cảm biến, máy để ngang, một vị trí đặt máy chung cho mọi bài
  (cao 60–70 cm, cách ~3 m).

### 4.2. Quy trình tập: giữ nguyên các bước, làm mỗi bước tốt hơn

- **Giới thiệu bài:** rút gọn, chỉ còn video mẫu tự phát, tên bài, nhãn kiểm chứng, số hiệp/rep/nghỉ, hướng dẫn
  đặt máy và nút bắt đầu. Bỏ dòng số liệu viết cứng không có thật.
- **Lần đầu tập một bài:** bắt buộc xem video hướng dẫn, nhưng có nút bỏ qua ngay từ đầu.
- **Đang tập:** màn hình không tự quay dọc khi đặt máy gần nằm phẳng. Mọi màn mở ra giữa buổi (hộp thoại, tổng
  kết) đều xoay theo chiều ngang của máy.
- **Nghỉ:** hiện mức "AI nhìn rõ X%" và nút "Báo sai" cho từng lỗi.
- **Tổng kết:** bố cục hai cột khi máy để ngang.
- **Onboarding:** rút từ 4 bước xuống 2 bước. Chọn mục tiêu xong là vào thẳng buổi tập đầu tiên.

### 4.3. Tính năng mới: dinh dưỡng

Phục vụ cùng mục tiêu tập luyện, không tách thành app riêng.

- Kho 566 thực phẩm và món ăn Việt, 18 công thức món, 21 thực đơn mẫu theo 3 miền. Tìm kiếm không cần gõ dấu,
  có nhập bằng giọng nói.
- Gợi ý bữa ăn sau buổi tập theo vùng miền.
- Thêm món bằng quét mã vạch, quét nhãn dinh dưỡng, chụp ảnh món ăn.
- Theo dõi bước chân, nhịn ăn gián đoạn, thống kê.
- Nhu cầu và khuyến nghị dựa trên nguồn khoa học công bố, liệt kê ngay trong app:
  - nhu cầu năng lượng: Mifflin-St Jeor kết hợp hệ số vận động FAO/WHO/UNU 2004;
  - đạm theo ISSN 2017;
  - chất béo và chất xơ theo WHO 2023;
  - thành phần món ăn từ USDA FoodData Central;
  - khẩu phần từ album ảnh khẩu phần IFPRI 2021.

### 4.4. Tính năng mới: lịch tập và nhắc nhở

- Người dùng chọn ngày và giờ tập. App nhắc lúc 07:00, 12:00, trước giờ tập 2 tiếng và đúng giờ tập. Ngày đã tập
  thì không nhắc.
- Widget lịch tập trên màn hình chính Android.
- Nhằm trực tiếp vào chỗ rơi ở mục 2.2 và giữ chân người dùng sau ngày 1.

### 4.5. Giao diện mới

- Làm lại toàn bộ giao diện theo hệ thiết kế mới, có linh vật tắc kè. Linh vật không xuất hiện trên màn camera và
  ở điều kiện đối chứng, để không ảnh hưởng đến thí nghiệm.
- Icon app mới, màn chờ có thanh tiến độ khởi động.
- Làm lại Trang chủ, Kế hoạch (dạng con đường các buổi), Thư viện (tìm kiếm, lọc nhóm cơ), Tiến độ (biểu đồ form),
  Hồ sơ.
- Bản đồ vùng đau dạng hình người 3D xoay được, chạm vào bộ phận để chọn.

### 4.6. Kỹ thuật, bảo mật, dữ liệu

- Xoá 71 file code không còn được dùng.
- Bỏ dịch vụ đọc giọng nói bên ngoài. Toàn bộ giọng nói giờ là file mp3 đóng gói sẵn, không gửi dữ liệu ra ngoài
  và không cần token.
- Dựng lại toàn bộ backend từ một file migration trong repo.
- Ảnh camera không rời máy: chỉ log số (góc, thời gian, lỗi) được ghi lại, và chỉ khi người dùng tham gia nghiên cứu.
- Kiểm thử tự động: `[ĐIỀN: số test qua / bỏ qua ở lần chạy cuối]`.

## 5. Phân tích SWOT

| | Tích cực | Tiêu cực |
|---|---|---|
| **Bên trong** | **Điểm mạnh (S)**<br>S1. Xử lý tư thế ngay trên máy: không gửi hình ảnh lên mạng, phản hồi tức thì.<br>S2. Giọng nói và nội dung tiếng Việt, món ăn Việt theo vùng miền.<br>S3. Giữ chân ngày 7 (25%) trên bách phân vị 75 của nhóm Health & Fitness.<br>S4. Tỉ lệ chuyển đổi trang App Store (12,5%) cao hơn trung vị nhóm.<br>S5. Mỗi lần sửa có log và số đo trên máy thật; có công cụ kiểm chứng sẵn sàng.<br>S6. Công khai giới hạn: chỉ 4 bài gắn nhãn đã kiểm chứng. | **Điểm yếu (W)**<br>W1. Chỉ 14% người bắt đầu tập đi hết buổi.<br>W2. Chưa có số kiểm chứng độc lập; ngưỡng mới chỉnh trên ít người.<br>W3. 20/24 bài mới ở mức chỉ đếm; 3 bài mới chưa đo ngưỡng.<br>W4. Phụ thuộc vào cách đặt máy và ánh sáng; một số bài bị chặn tới ~24–28% thời gian tập khi đặt máy chưa chuẩn.<br>W5. Nhóm nhỏ; bản Android đi trước, iOS chưa có widget. |
| **Bên ngoài** | **Cơ hội (O)**<br>O1. Nhu cầu tập tại nhà, ít thời gian, không có tiền thuê PT.<br>O2. Hợp tác với giáo viên thể dục, PT, phòng gym để vừa kiểm chứng vừa phân phối.<br>O3. Dinh dưỡng và lịch tập tạo thói quen dùng app hằng ngày, kể cả hôm không tập.<br>O4. Các đợt lượt tải tăng vọt cho thấy truyền thông có hiệu quả khi có sự kiện. | **Thách thức (T)**<br>T1. Ứng dụng lớn nước ngoài và video miễn phí trên YouTube/TikTok.<br>T2. Rủi ro chấn thương nếu AI chỉ dẫn sai, kèm trách nhiệm pháp lý.<br>T3. Quy định bảo vệ dữ liệu cá nhân (Nghị định 13/2023/NĐ-CP) với dữ liệu sức khoẻ và hình ảnh.<br>T4. Điện thoại tầm thấp chạy chậm, nhận diện kém hơn.<br>T5. Quyền sử dụng hình ảnh người nổi tiếng trong app. |

## 6. Ma trận TOWS: chiến lược rút ra

| | **Cơ hội (O)** | **Thách thức (T)** |
|---|---|---|
| **Điểm mạnh (S)** | **SO: dùng điểm mạnh để tận dụng cơ hội**<br>- Đưa kiểm chứng (S5) cho giáo viên thể dục và PT cùng chấm (O2): vừa ra số độc lập, vừa thành kênh phân phối.<br>- Gắn gợi ý bữa ăn Việt (S2) ngay sau buổi tập để tạo thói quen hằng ngày (O3), nâng tiếp mức giữ chân vốn đã tốt (S3). | **ST: dùng điểm mạnh để chống thách thức**<br>- Lấy "không gửi hình ảnh lên mạng" (S1) làm điểm khác biệt về quyền riêng tư (T3) so với đối thủ (T1).<br>- Chỉ nhận là "đã kiểm chứng" ở những bài có số (S6), giảm rủi ro chỉ dẫn sai (T2). |
| **Điểm yếu (W)** | **WO: dùng cơ hội để khắc phục điểm yếu**<br>- Nhắc lịch và widget (O3) nhắm vào tỉ lệ hoàn thành buổi thấp (W1). Đo lại phễu sau khi phát hành.<br>- Mời PT gán nhãn video (O2) để có số kiểm chứng (W2) và chỉnh ngưỡng các bài còn chỉ đếm (W3). | **WT: giảm điểm yếu, né thách thức**<br>- Khi camera không nhìn rõ (W4) thì dừng chấm và nói rõ "chưa đủ căn cứ", không đoán (T2).<br>- Bài chưa kiểm chứng chỉ đếm, không chấm form (W3, T2).<br>- Đo tốc độ khung hình trên máy yếu (T4) và công bố cấu hình tối thiểu.<br>- Thay ảnh người nổi tiếng bằng ảnh có quyền sử dụng (T5). |

## 7. Hạn chế và việc tiếp theo

- Số kiểm chứng ở mục 3 được thu sau ngày `[ĐIỀN]` với `[ĐIỀN]` người, là thử nghiệm sơ bộ.
- Đo lại phễu và giữ chân sau khi phát hành bản mới: `[ĐIỀN]`.
- Ba bài mới cần đo ngưỡng trên máy và thu âm 12 câu nhắc còn thiếu.
- Widget lịch tập cho iOS.

## Phụ lục

- Mã nguồn: https://github.com/ChauyeubacToLam/Sangtaotrequocgia-vikanextgen (commit `43aa6da`)
- Nhật ký thử trên máy và các lần sửa: `docs/field-test-log.md`
- Kế hoạch thu số liệu: `tools/eval/KE_HOACH_THU_SO_LIEU.md`
- Hướng dẫn gán nhãn: `tools/eval/HUONG_DAN_GAN_NHAN.md`
